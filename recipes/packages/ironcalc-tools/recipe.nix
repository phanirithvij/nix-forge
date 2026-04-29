{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "ironcalc-tools";
  version = "0.7.1-unstable-2026-04-29";
  description = "IronCalc helper tools";
  license = with lib.licenses; [
    mit
    asl20
  ];
  mainProgram = "xlsx_2_icalc";

  source = {
    git = "github:ironcalc/ironcalc/8461ff71347ab19145cd7ad50ef829181ba765c2";
    hash = "sha256-vjI3M+hS9bXK8QQlopAy6f4dCISfQHGMvN9sMNKp88Q=";
  };

  build.rustPackageBuilder = {
    enable = true;
    cargoHash = "sha256-q5DnqhIYKUUqfJ4/TNHYF1QgTbH198QtgirQ+lP30wk=";
    packages.build = [
      pkgs.pkg-config
      pkgs.python3
    ];
    packages.run = [
      pkgs.bzip2
      pkgs.zstd
    ];
  };

  build.extraAttrs = {
    buildAndTestSubdir = "xlsx";
  };
}
