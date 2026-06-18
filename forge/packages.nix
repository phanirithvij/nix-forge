{
  config,
  lib,
  pkgs,
  forge-inputs,
  flake-parts-lib,
  ...
}:

let
  evalForgeModules =
    modules:
    flake-parts-lib.evalFlakeModule {
      inputs = forge-inputs;
    } { imports = modules; };

  forgeOptionsDoc =
    modules:
    pkgs.nixosOptionsDoc {
      warningsAreErrors = false;
      options = lib.removeAttrs (evalForgeModules modules).options [ "_module" ];
      transformOptions =
        opt:
        opt
        // {
          name = lib.removePrefix "perSystem.forge." opt.name;
          declarations = [ ];
          visible = lib.match ("^perSystem\\.forge\\.(apps|packages)(\\..+)?") opt.name != null;
        };
    };

  forgeApps = config.forge.apps;
  forgeOptions = forgeOptionsDoc [
    forge-inputs.self.flakeModules.base
  ];

  # Collect app icons into a derivation
  appIcons = pkgs.runCommand "app-icons" { } ''
    mkdir -p $out
    ${lib.concatStringsSep "\n" (
      map (app: ''
        mkdir -p $out/${app.name}
        ${if app.icon or null != null then "cp ${app.icon} $out/${app.name}/icon.svg" else ""}
      '') (lib.attrValues forgeApps)
    )}
  '';
in
{
  packages = {
    pkgs =
      let
        mkDummyGroup =
          name: attrs:
          attrs
          // {
            inherit name;
            type = "derivation";
            system = pkgs.stdenv.hostPlatform.system;
            inherit (pkgsBundle) drvPath outPath outputName;
            # In case flake schemas ever gets merged this will be useful
            # if using `lix` you can see this description in the output of `nix flake show`
            meta.description = "Build all pkgs at once";
          };
        pkgsBundle = pkgs.linkFarm "pkgs" (
          lib.mapAttrsToList (name: drv: {
            inherit name;
            path = drv;
          }) config.forge.builtPackages
        );
      in
      mkDummyGroup "pkgs" config.forge.builtPackages;
  }
  // lib.mapAttrs' (name: value: lib.nameValuePair "pkgs.${name}" value) config.forge.builtPackages;

  legacyPackages = {
    _forge-config = pkgs.writeTextFile {
      name = "forge-config.json";
      text =
        let
          scrubConfig =
            x:
            if lib.isString x || lib.isDerivation x then
              lib.unsafeDiscardStringContext x
            else if lib.isList x then
              map scrubConfig x
            else if lib.isAttrs x then
              lib.mapAttrs (n: v: scrubConfig v) x
            else
              x;
        in
        builtins.toJSON (scrubConfig config.forge);
    };

    _forge-options = pkgs.runCommand "options.json" { } ''
      cp ${forgeOptions.optionsJSON}/share/doc/nixos/options.json $out
    '';

    _forge-ui = pkgs.callPackage ../ui/package.nix {
      inherit (config.legacyPackages)
        _forge-config
        _forge-docs
        _forge-options
        ;
      inherit appIcons;
      buildElmApplication = (forge-inputs.elm2nix.lib.elm2nix pkgs).buildElmApplication;
      highlight-js = pkgs.callPackage ../flake/packages/highlight-js.nix { };
    };

    _forge-ui-dev = pkgs.callPackage ../flake/packages/forge-ui-dev.nix {
      inherit (config.legacyPackages)
        _forge-ui
        _forge-docs
        _forge-options
        ;
      highlight-js = pkgs.callPackage ../flake/packages/highlight-js.nix { };
    };

    _forge-docs = pkgs.callPackage ../flake/packages/forge-docs.nix { };

    _forge-report =
      let
        reports = import ../maintainers/mk-report.nix { inherit forgeApps pkgs lib; };
      in
      pkgs.writeShellApplication {
        name = "report-packaging";
        passthru = reports;
        text = ''
          cat <<EOF
          To generate a packaging report, use:

          \`\`\`
          nix run .#_forge-report.all      # all grants
          nix run .#_forge-report.<GRANT>  # single grant
          \`\`\`

          Available grants:
          ${lib.concatMapStringsSep "\n" (g: "- " + g) [
            "Commons"
            "Core"
            "Entrust"
            "Review"
          ]}
          EOF
        '';
      };

    _forge-announcement = pkgs.writeShellApplication {
      name = "announce-projects";
      passthru = import ../maintainers/mk-announcement.nix { inherit forgeApps pkgs lib; };
      text = ''
        cat <<EOF
        To generate project announcement, use:

        \`\`\`
        nix run .#_forge-announcement.<APP_NAME>
        \`\`\`

        Available apps:
        ${lib.concatMapStringsSep "\n" (app: "- " + app.name) (lib.attrValues forgeApps)}
        EOF
      '';
    };
  };
}
