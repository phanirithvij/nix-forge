{
  lib,
  config,
  pkgs,
  sharedBuildAttrs,
  ...
}:
{
  forge.builtPackages = lib.mapAttrs (
    packageName: package:
    lib.mkIf package.build.pnpmPackageBuilder.enable (
      let
        builderCfg = package.build.pnpmPackageBuilder;

      in
      pkgs.stdenvNoCC.mkDerivation (
        finalAttrs:
        let
          pnpmDeps = pkgs.fetchPnpmDeps ({
            inherit (finalAttrs)
              pname
              src
              version
              sourceRoot
              ;
            inherit (builderCfg) pnpm fetcherVersion;
            hash = builderCfg.pnpmDepsHash;
          });
        in
        {
          inherit (package) pname version;
          inherit pnpmDeps;
          src = sharedBuildAttrs.pkgSource package;
          patches = package.source.patches or [ ];

          nativeBuildInputs = [
            builderCfg.pnpm
            pkgs.pnpmConfigHook
            pkgs.nodejs
          ]
          ++ builderCfg.packages.build;
          buildInputs = builderCfg.packages.run;
          nativeCheckInputs = builderCfg.packages.check;

          buildPhase = ''
            runHook preBuild
            pnpm run ${builderCfg.buildScript}
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            cp -r ${builderCfg.installDir} $out
            runHook postInstall
          '';

          passthru = sharedBuildAttrs.pkgPassthru package finalAttrs.finalPackage;
          meta = sharedBuildAttrs.pkgMeta package;
        }
        // lib.optionalAttrs (builderCfg.sourceRoot != null) {
          inherit (builderCfg) sourceRoot;
        }
        // package.build.extraAttrs
        // lib.optionalAttrs package.build.debug sharedBuildAttrs.debugShellHookAttr
      )
    )
  ) config.forge.packages;
}
