{
  lib,
  self,
  inputs,
  ...
}:

{
  perSystem =
    {
      config,
      pkgs,
      self',
      system,
      ...
    }:

    let
      # Helper function to extract passthru attribute, ensuring it is a valid derivation
      passthruAttr =
        attr:
        lib.filterAttrs (_: v: v != null) (
          lib.mapAttrs' (
            name: package:
            if lib.hasAttr attr package && lib.isDerivation package.${attr} then
              let
                evalResult = builtins.tryEval (
                  package.${attr} ? drvPath && builtins.seq package.${attr}.drvPath true
                );
              in
              if evalResult.success && evalResult.value then
                lib.nameValuePair "${name}-${attr}" package.${attr}
              else
                lib.nameValuePair name null
            else
              lib.nameValuePair name null
          ) config.packages
        );
    in

    {
      checks =
        (lib.filterAttrs (_: v: v != null) (
          lib.mapAttrs (
            name: package:
            if lib.isDerivation package then
              let
                evalResult = builtins.tryEval (package ? drvPath && builtins.seq package.drvPath true);
              in
              if evalResult.success && evalResult.value then package else null
            else
              null # Ignore non-derivations in config.packages for checks
          ) config.packages
        ))

        # All packages passthru attributes
        // (passthruAttr "env")
        // (passthruAttr "test")

        # All apps passthru attributes
        // (passthruAttr "programs")
        // (passthruAttr "container")
        // (passthruAttr "vm")
        // (passthruAttr "test")
        // (passthruAttr "test-services-container")
        // (passthruAttr "test-services-nixos")
        // (passthruAttr "test-programs")
        // (passthruAttr "check-programs-main-package")
        // {
          end-user-eval-flake = pkgs.testers.runNixOSTest {
            name = "end-user-eval-flake";
            nodes.machine = { pkgs, ... }: {
              imports = [
                self'.packages."apps.tau".nixosModules.default
              ];
            };
            testScript = ''
              machine.start()
              machine.wait_for_unit("multi-user.target")
              machine.succeed("echo 'Evaluated and booted successfully!'")
            '';
          };

          end-user-eval-flake-neochat-fails =
            let
              downstream = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
                systems = [ "x86_64-linux" ];
                imports = [ self.flakeModules.default ];
                perSystem = { config, ... }: {
                  forge.repositoryUrl = "foo";
                  # Intentionally NOT allowlisting olm-3.2.16
                };
              };
              result = builtins.tryEval downstream.packages.x86_64-linux.apps.neochat.program.outPath;
            in
            if result.success then
              throw "Leaked! Downstream flake was NOT forced to allowlist neochat!"
            else
              pkgs.runCommand "downstream-neochat-eval-failed-as-expected" { } "touch $out";

          end-user-eval-flake-neochat-succeeds =
            let
              downstream = inputs.flake-parts.lib.mkFlake { inherit inputs; } {
                systems = [ "x86_64-linux" ];
                imports = [ self.flakeModules.default ];
                perSystem = { config, ... }: {
                  forge.repositoryUrl = "foo";
                  forge.allowInsecurePackages = [ "olm-3.2.16" ];
                };
              };
              result = builtins.tryEval (
                downstream.packages.x86_64-linux.apps.neochat.program ? drvPath
                && builtins.seq downstream.packages.x86_64-linux.apps.neochat.program.drvPath true
              );
            in
            if result.success && result.value then
              pkgs.runCommand "downstream-neochat-eval-succeeded-as-expected" { } "touch $out"
            else
              throw "Failed! Downstream flake WAS forced to allowlist neochat, but it still threw!";


          end-user-eval-legacy =
            let
              forgeLegacy = import ../default.nix { inherit system; };
            in
            pkgs.testers.runNixOSTest {
              name = "end-user-eval-legacy";
              nodes.machine = { pkgs, ... }: {
                imports = [
                  forgeLegacy.apps.tau.nixosModules.default
                ];
              };
              testScript = ''
                machine.start()
                machine.wait_for_unit("multi-user.target")
                machine.succeed("echo 'Evaluated and booted successfully!'")
              '';
            };

          end-user-eval-legacy-neochat-fails =
            let
              forgeLegacy = import ../default.nix { inherit system; };
              # The wrapper derivation (forgeLegacy.apps.neochat) evaluates fine, but evaluating its
              # program passthru attribute throws an error because the package is un-allowlisted.
              result = builtins.tryEval (
                forgeLegacy.apps.neochat.program ? drvPath
                && builtins.seq forgeLegacy.apps.neochat.program.drvPath true
              );
            in
            if result.success && result.value then
              throw "Legacy evaluate succeeded unexpectedly! Downstream default.nix users should be forced to allowlist!"
            else
              pkgs.runCommand "legacy-neochat-eval-failed-as-expected" { } "touch $out";
        };
    };
}
