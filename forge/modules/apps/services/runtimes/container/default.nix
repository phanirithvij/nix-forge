{
  inputs,
  config,
  lib,
  system,

  app,
  pkgs,
  specialArgs,
  ...
}@args:
{
  options = {
    enable = lib.mkEnableOption "Container runtime";

    composeFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to the custom container compose file.
        Set to null to automatically generate this file.
      '';
      example = lib.literalExpression "./compose.yaml";
    };

    components = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submoduleWith {
          inherit specialArgs;
          modules = [
            {
              options = {
                setup = lib.mkOption {
                  type = lib.types.lines;
                  default = "";
                  description = ''
                    Script to run once at the container startup.
                    Use this option for one-off system preparation steps.
                  '';
                  example = ''
                    # bash
                    echo "Creating directory structure ..."
                    mkdir --parents /var/lib/myservice/config /var/lib/myservice/db
                  '';
                };

                packages = lib.mkOption {
                  type = lib.types.listOf lib.types.package;
                  default = [ ];
                  description = ''
                    List of packages available in the container.

                    Use this option to add packages required by setup script.
                  '';
                  example = lib.literalExpression "[ pkgs.curl ]";
                };

                imageConfig = lib.mkOption {
                  type = with lib.types; lazyAttrsOf anything;
                  default = { };
                  description = ''
                    OCI image configuration.

                    See the list of available
                    [OCI image configuration options](https://specs.opencontainers.org/image-spec/config/#properties) .
                  '';
                  example = lib.literalExpression ''
                    {
                      WorkingDir = "/var/lib/myservice";
                    }
                  '';
                };
              };
            }
          ];
        }
      );
      default = { };
      description = "Per-component container runtime configuration.";
      apply =
        self:
        let
          knownComponents = lib.attrNames app.services.components;
          unknownComponents = lib.subtractLists knownComponents (lib.attrNames self);
        in
        lib.throwIf (unknownComponents != [ ])
          "services.runtimes.container.components: unknown component(s): ${lib.concatStringsSep ", " unknownComponents}. Must be one of: ${lib.concatStringsSep ", " knownComponents}"
          self;
    };

    result = {
      modules = lib.mkOption {
        internal = true;
        type = with lib.types; lazyAttrsOf (either attrs anything);
        description = "Nimi configuration.";
      };

      evals = lib.mkOption {
        internal = true;
        readOnly = true;
        type = with lib.types; lazyAttrsOf (either attrs anything);
        description = "Nimi module evaluation.";
      };

      recipes = lib.mkOption {
        internal = true;
        type = with lib.types; lazyAttrsOf (nullOr package);
        default = null;
        description = "Script that builds container image recipe.";
      };

      build = lib.mkOption {
        internal = true;
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Script that builds container image.";
      };

      shellRunner = lib.mkOption {
        internal = true;
        type = with lib.types; lazyAttrsOf (nullOr package);
        default = { };
        description = "Per-service bubblewrap-sandboxed runner.";
      };

      # HACK:
      # Prevent toJSON conversion from attempting to convert the `eval` option,
      # which won't work because it's a whole NixOS evaluation.
      __toString = lib.mkOption {
        internal = true;
        readOnly = true;
        type = with lib.types; functionTo str;
        default = self: "container";
      };
    };
  };

  config = {
    result.modules = lib.mapAttrs (serviceName: service: {
      settings = import ./modules/settings.nix (
        {
          inherit service serviceName;
        }
        // args
        // lib.optionalAttrs (config.components ? ${serviceName}) {
          runtimeConfig = config.components.${serviceName};
        }
      );
      services = import ../mkNimiImports.nix { inherit lib service serviceName; };
    }) app.services.components;

    result.evals = lib.mapAttrs (
      name: value:
      inputs.ngi-forge.inputs.nimi.packages.${system}.nimi.passthru.evalNimiModule {
        config = config.result.modules.${name};
      }
    ) app.services.components;

    result.recipes = lib.mapAttrs (
      name: value:
      inputs.ngi-forge.inputs.nimi.packages.${system}.nimi.mkContainerImage {
        config = config.result.modules.${name};
      }
    ) app.services.components;

    result.shellRunner = lib.mapAttrs (
      serviceName: service:
      let
        componentPackages = service.packages;
        runtimeComponentPackages = config.components.${serviceName}.packages or [ ];
        binPaths = lib.makeBinPath ([ pkgs.coreutils ] ++ componentPackages ++ runtimeComponentPackages);
      in
      inputs.ngi-forge.inputs.nimi.packages.${system}.nimi.mkBwrap {
        settings.bubblewrap.environment = service.environment // {
          PATH = binPaths;
        };
        settings.bubblewrap.chdir = "/var/lib/${serviceName}";
        settings.bubblewrap.unshare.user = false;
        settings.bubblewrap.appendFlags = [
          "--dir"
          "/var/lib/${serviceName}"
        ];
        imports = [ { inherit (config.result.modules.${serviceName}) services settings; } ];
      }
    ) app.services.components;

    result.build =
      let
        effectiveComposeFile =
          if config.composeFile != null then
            config.composeFile
          else
            pkgs.writeText "${app.name}-compose.yaml" (
              lib.generators.toYAML { } {
                services = lib.mapAttrs (name: service: {
                  image = "localhost/${name}:latest";
                  ports = service.ports;
                  depends_on = lib.genAttrs service.after (_name: { });
                  tmpfs = [ "/tmp:rw,size=64m" ];
                  volumes = [ "${name}-data:${service.stateDir}" ];
                }) app.services.components;
                volumes = lib.mapAttrs' (name: _: lib.nameValuePair "${name}-data" { }) app.services.components;
              }
            );

        build-oci-images =
          pkgs.writeShellScriptBin "build-oci-images" ''
            export CACHE_DIR="${cacheDir}"
          ''
          ++ (lib.concatMapAttrsStringSep "\n" (name: value: /* bash */ ''
            TAR_FILE="$CACHE_DIR/${name}-$(basename ${value.copyTo} | cut -d'-' -f1).tar"
            if [ ! -f "$TAR_FILE" ]; then
              echo "Building container image ${name} in $TAR_FILE"
              ${value.copyTo}/bin/copy-to oci-archive:"$TAR_FILE.tmp":${name}:latest
              mv "$TAR_FILE.tmp" "$TAR_FILE"
            else
              echo "Using cached container image ${name} from $TAR_FILE"
            fi

            podman load < "$TAR_FILE"

            touch -m "$TAR_FILE"
          '') config.result.recipes);

        compose-file = pkgs.runCommand "compose-file" { } ''
          install -D ${effectiveComposeFile} $out/${app.name}/compose.yaml
        '';

        cacheDir = "\${XDG_CACHE_HOME:-$HOME/.cache}/ngi-forge/${builtins.hashString "md5" specialArgs.forgeConfig.forge.repositoryUrl}";

        # The approach for garbage collection of the container tarballs:
        # 1. CACHE_DIR is shared per-repository, and it contain oci tarballs for all apps built via run-container or build-oci-images.
        # 2. `VALID_TARBALLS` is computed directly from Nix derivations. Any tarballs matching it are preserved.
        # 3. If a tarball is not needed by a current run-container invocation, we remove it if it hasn't been touched in 7 days.
        run-podman = pkgs.writeShellScriptBin "run-podman" /* bash */ ''
          export CACHE_DIR="${cacheDir}"
          mkdir -p "$CACHE_DIR"

          VALID_TARBALLS="${
            lib.concatStringsSep " " (
              lib.mapAttrsToList (
                name: value: "${name}-$(basename ${value.copyTo} | cut -d'-' -f1).tar"
              ) config.result.recipes
            )
          }"

          for cached_tar in "$CACHE_DIR"/*.tar; do
            if [ -f "$cached_tar" ]; then
              basename_tar=$(basename "$cached_tar")
              is_valid=false
              for valid_tar in $VALID_TARBALLS; do
                if [ "$basename_tar" = "$valid_tar" ]; then
                  is_valid=true
                  break
                fi
              done

              if [ "$is_valid" = false ]; then
                if [ -n "$(find "$cached_tar" -mtime +7 2>/dev/null)" ]; then
                  echo "Removing stale cached tarball: $cached_tar"
                  rm -f "$cached_tar"
                fi
              fi
            fi
          done

          ${lib.getExe build-oci-images}

          ${lib.getExe pkgs.podman-compose} \
            -f ${compose-file}/${app.name}/compose.yaml \
            up --force-recreate "$@"
        '';

        run-container = pkgs.writeShellScriptBin "run-container" ''
          ${lib.getExe run-podman} "$@"
        '';
      in
      pkgs.symlinkJoin {
        name = "run-container";
        paths = [
          build-oci-images
          compose-file
          run-podman
          run-container
        ];
        meta.mainProgram = "run-container";
      };
  };
}
