{
  lib,
  pkgs,
  ...
}:

{
  packages.flopedt = {
    version = "0.1.0";
    description = "FlOpEDT Backend.";
    homePage = "https://framagit.org/flopedt/FlOpEDT";
    mainProgram = "flopedt";
    license = lib.licenses.agpl3Plus;

    source = {
      git = "git:https://framagit.org/flopedt/FlOpEDT.git?rev=1eaf2d6945a1b70ca98ad09dfff4593a4bbbfe27";
      hash = "sha256-E/91cZ0NY8fjqEV+TwgsusXHKFCJ+N2oJorJKFvHd9o=";
    };

    build.standardBuilder = {
      enable = true;
    };

    build.extraAttrs = {
      installPhase = ''
        runHook preInstall
        mkdir -p $out/share/flopedt
        cp -r back/* $out/share/flopedt/
        cp -r ${pkgs.flopedt-webapp} $out/share/flopedt/webapp-dist
        runHook postInstall
      '';
    };
  };
}
