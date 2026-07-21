{
  description = "NGI Forge";

  nixConfig = {
    extra-substituters = [ "https://ngi-forge.cachix.org" ];
    extra-trusted-public-keys = [
      "ngi-forge.cachix.org-1:PK0qK+LhWt4GQVpUtPapyXWxJSM1GhtmPW6CRCoygz0="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:vic/import-tree";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    elm2nix = {
      url = "github:dwayne/elm2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-utils = {
      url = "github:imincik/nix-utils";
      flake = false;
    };

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nimi = {
      url = "github:ngi-nix/nimi/ngi-patches";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:

    let
      flake =
        flake-parts.lib.mkFlake
          {
            inherit inputs;
          }
          (flakeArgs: {
            # Uncomment this to enable flake-parts debug.
            # https://flake.parts/options/flake-parts.html?highlight=debug#opt-debug
            # debug = true;

            systems = [
              "x86_64-linux"
              # "aarch64-linux"
              # "aarch64-darwin"
              # "x86_64-darwin"
            ];

            imports = [
              ./forge/modules.nix
              ./flake/develop
              ./flake/packages.nix
              ./flake/checks.nix
              ./flake/templates.nix
            ];

            # Export the flake configuration to ease exploration in `nix repl .`.
            #
            # Remark(clarity): like all `unknown` flake outputs,
            # this currently raise a warning in `nix flake check`:
            # > warning: unknown flake output 'flakeConfig'
            # Issue: https://github.com/NixOS/nix/issues/6381
            flake.flakeConfig = flakeArgs.config;
            flake.maintainerList = ./maintainers/maintainer-list.nix;

            perSystem =
              { system, ... }:
              {
                forge = {
                  repositoryUrl = self.sourceInfo.url or "github:ngi-nix/forge";
                  maintainerLists = [ self.maintainerList ];
                };
              };
          });

      # The `apps` output is disallowed because we are exposing `apps` through `packages.${system}`.
      # `flake-parts` creates empty `apps.${system}` by default, so we filter out empty sets.
      apps = inputs.nixpkgs.lib.filterAttrs (_: v: v != { }) (flake.apps or { });
    in
    if apps != { } then
      throw ''
        The top-level `apps` flake output is disallowed in this project.
        We instead treat `apps` as packages and expose them via `packages.''${system}`
        Please remove any direct `apps` definitions which were mistakenly added.
      ''
    else
      let
        flake' = builtins.removeAttrs flake [ "apps" ];

        # Recursively tryEval derivations to omit any that throw (like insecure packages)
        filterThrowing =
          attrs:
          inputs.nixpkgs.lib.filterAttrs
            (
              name: value:
              if inputs.nixpkgs.lib.isDerivation value then
                (builtins.tryEval (value ? drvPath && builtins.seq value.drvPath true)).success
              else if builtins.isAttrs value then
                true # We don't filter the attrset itself, we filter its children later if needed
              else
                true
            )
            (
              inputs.nixpkgs.lib.mapAttrs (
                name: value:
                if builtins.isAttrs value && !inputs.nixpkgs.lib.isDerivation value then
                  filterThrowing value
                else
                  value
              ) attrs
            );
      in
      flake'
      // {
        packages = inputs.nixpkgs.lib.mapAttrs (system: pkgs: filterThrowing pkgs) flake'.packages;
      };
}
