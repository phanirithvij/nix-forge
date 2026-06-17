{
  inputs,
  config,
  lib,
  ...
}:

{
  perSystem =
    {
      config,
      pkgs,
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
              lib.nameValuePair "${name}-${attr}" package.${attr}
            else
              lib.nameValuePair name null
          ) config.packages
        );

      # All output packages
      allPackages = lib.filterAttrs (n: v: !lib.hasPrefix "_forge" n) config.packages;
    in

    {
      checks = {
        inherit (config.legacyPackages)
          _forge-config
          _forge-options
          _forge-ui
          _forge-docs
          ;
      }
      // allPackages

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
      // (passthruAttr "check-programs-main-package");
    };
}
