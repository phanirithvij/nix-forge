{
  lib,
  ...
}:

{
  packages.flopedt-webapp = {
    version = "0.1.0";
    description = "FlOpEDT Web App.";
    homePage = "https://framagit.org/flopedt/FlOpEDT";
    mainProgram = "flopedt-webapp";
    license = lib.licenses.agpl3Plus;

    source = {
      git = "git:https://framagit.org/flopedt/FlOpEDT.git?rev=1eaf2d6945a1b70ca98ad09dfff4593a4bbbfe27";
      hash = "sha256-E/91cZ0NY8fjqEV+TwgsusXHKFCJ+N2oJorJKFvHd9o=";
    };

    build.pnpmPackageBuilder = {
      enable = true;
      pnpmDepsHash = "sha256-zzm7huas7q04+kCape/mYcZ2hOzKOBReRFE2nAHHOFA=";
      buildScript = "build";
      installDir = "webapp/dist";
    };

    build.extraAttrs = {
      buildPhase = ''
        runHook preBuild
        pnpm --filter webapp run build
        runHook postBuild
      '';
    };
  };
}
