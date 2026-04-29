{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "ironcalc";
  version = "0.7.1-unstable-2026-04-29";
  description = "Open source selfhosted spreadsheet engine";
  license = with lib.licenses; [
    mit
    asl20
  ];
  mainProgram = "ironcalc";

  source = {
    git = "github:ironcalc/ironcalc/8461ff71347ab19145cd7ad50ef829181ba765c2";
    hash = "sha256-vjI3M+hS9bXK8QQlopAy6f4dCISfQHGMvN9sMNKp88Q=";
  };

  build.standardBuilder = {
    enable = true;
    packages.run = [
      pkgs.mypkgs.ironcalc-server
      pkgs.mypkgs.ironcalc-frontend
      pkgs.mypkgs.ironcalc-tools
      pkgs.sqlite
    ];
  };

  build.extraAttrs = {
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cat > $out/bin/ironcalc <<EOF
      #!/bin/bash
      set -euo pipefail

      IRONCALC_DB_PATH="\''${IRONCALC_DB_PATH:-ironcalc.sqlite}"
      if [ ! -f "\$IRONCALC_DB_PATH" ]; then
        echo "Initializing database..."
        ${pkgs.sqlite}/bin/sqlite3 "\$IRONCALC_DB_PATH" < "${pkgs.mypkgs.ironcalc-server}/share/ironcalc/init_db.sql"
      fi

      export ROCKET_DATABASES="{ironcalc={url=\"\$IRONCALC_DB_PATH\"}}"
      export IRONCALC_WEBAPP_DIR="\''${IRONCALC_WEBAPP_DIR:-${pkgs.mypkgs.ironcalc-frontend}}"
      exec ${pkgs.mypkgs.ironcalc-server}/bin/ironcalc_server "\$@"
      EOF
      chmod +x $out/bin/ironcalc

      ln -s ${pkgs.mypkgs.ironcalc-tools}/bin/xlsx_2_icalc $out/bin/xlsx_2_icalc
    '';
  };
}
