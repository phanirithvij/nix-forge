{ inputs, flake-parts-lib, ... }:

{
  perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      forgeModules = [
        ./modules/apps
        ./modules/packages.nix
      ];

      evalForgeModules =
        modules:
        lib.evalModules {
          modules = modules;
          specialArgs = { inherit flake-parts-lib inputs; };
        };

      forgeOptionsDoc =
        modules:
        pkgs.nixosOptionsDoc {
          warningsAreErrors = false;
          options = lib.removeAttrs (evalForgeModules modules).options [ "_module" ];
          transformOptions =
            opt:
            let
              # Avoid building packages when generating options.json
              # by ensuring defaults and examples don't contain derivations.
              pruneValue = v: if lib.isDerivation v then null else v;
            in
            opt
            // {
              name = lib.removePrefix "perSystem.forge." opt.name;
              declarations = [ ];
              visible = lib.match ("^perSystem\\.forge\\.(apps|packages)(\\..+)?") opt.name != null;
              default = if opt ? default then pruneValue opt.default else null;
              example = if opt ? example then pruneValue opt.example else null;
            };
        };

      forgeOptions = forgeOptionsDoc forgeModules;

      # Collect app icons into a derivation
      appIcons = pkgs.runCommand "app-icons" { } ''
        mkdir -p $out
        ${lib.concatStringsSep "\n" (
          map (app: ''
            mkdir -p $out/${app.name}
            ${if app.icon or null != null then "cp ${app.icon} $out/${app.name}/icon.svg" else ""}
          '') config.forge.apps
        )}
      '';
    in
    {
      packages = {
        _forge-config = pkgs.writeText "forge-config.json" (
          let
            # Prune fields with functions (toJSON fails) or large internal state.
            # unsafeDiscardStringContext prevents the referenced derivations from being built.
            prunedForge = config.forge // {
              packages = map (p: removeAttrs p [ "build" "test" "development" ]) config.forge.packages;
              apps = map (a: removeAttrs a [ "result" "test" ]) config.forge.apps;
            };
          in
          builtins.unsafeDiscardStringContext (builtins.toJSON prunedForge)
        );

        _forge-options = pkgs.runCommand "options.json" { } ''
          cp ${forgeOptions.optionsJSON}/share/doc/nixos/options.json $out
        '';

        _forge-ui = pkgs.callPackage ../ui/package.nix {
          inherit (config.packages) _forge-config _forge-docs _forge-options;
          inherit appIcons;
          buildElmApplication = (inputs.elm2nix.lib.elm2nix pkgs).buildElmApplication;
        };

        _forge-docs = pkgs.callPackage ../flake/packages/forge-docs.nix { };
      };
    };
}
