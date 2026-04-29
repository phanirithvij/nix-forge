{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "ironcalc-server";
  version = "0.7.1-unstable-2026-04-29";
  description = "IronCalc server package";
  license = [
    lib.licenses.asl20
    lib.licenses.mit
  ];

  source = {
    git = "github:ironcalc/ironcalc/8461ff71347ab19145cd7ad50ef829181ba765c2";
    hash = "sha256-vjI3M+hS9bXK8QQlopAy6f4dCISfQHGMvN9sMNKp88Q=";
  };

  build.rustPackageBuilder = {
    enable = true;
    cargoHash = "sha256-46IwZJI9AOs+IQFbfz89A2yIi5db7rVMVNsO9W+tn+c=";
    packages.build = [
      pkgs.pkg-config
    ];
    packages.run = [
      pkgs.bzip2
      pkgs.zstd
    ];
  };

  build.extraAttrs = {
    postUnpack = ''
      chmod -R u+w source
      pushd source

      # REMOVE root Cargo.toml so that cargo in server subdir 
      # doesn't see it as a workspace parent.
      # This ensures it uses its own Cargo.lock.
      rm Cargo.toml
      popd
    '';

    sourceRoot = "source/webapp/app.ironcalc.com/server";

    postInstall = ''
      install -Dm644 init_db.sql $out/share/ironcalc/init_db.sql
    '';
  };
}
