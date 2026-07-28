{
  lib,
  pkgs,
  ...
}:

{
  pkgs.wormhole-wasm = {
    version = "0.5.4-beta";
    description = "Wormhole WASM module for Winden.";
    homePage = "https://github.com/LeastAuthority/wormhole-william";
    license = lib.licenses.mit;

    source = {
      git = "github:LeastAuthority/wormhole-william/10940cd31c7445ede9561db3ef08f566d95b5f3e";
      hash = "sha256-yvdUk30va1fn3dZPgQ7Wa4+6vWiZiAngDffxgtscjeY=";
    };

    build.goPackageBuilder = {
      enable = true;
      vendorHash = "sha256-G0ARZwnRt2DFJSa2qdw3mEunIEpsu9kPxDwqUq+NIIM=";
    };

    build.extraAttrs = {
      buildPhase = ''
        GOOS=js GOARCH=wasm go build -buildvcs=false -o wormhole.wasm ./wasm/module
      '';

      installPhase = ''
        mkdir -p $out
        cp wormhole.wasm $out/
      '';
    };
  };

  pkgs.winden = {
    version = "unstable-2025-06-05";
    description = "Securely transfer files between computers via the browser.";
    homePage = "https://winden.app";
    mainProgram = "winden";
    license = lib.licenses.mit;

    source = {
      git = "github:LeastAuthority/winden/0082e5aeef7eef5d4ae163f2ce61906bd2ee4e0a";
      hash = "sha256-AVinNoLcSmPBMHowwSLdenHdN8kxmyEhUP07JEDtUXs=";
      patches = [ ./0001-use-git-for-magic-wormhole.patch ];
    };

    build.npmPackageBuilder = {
      enable = true;
      npmDepsHash = "sha256-zxxMxtA9KkNt0LMPJPw+v1kerLC+I8wgUfO6QYjGY48=";
      npmInstallFlags = [
        "--legacy-peer-deps"
        "--omit=optional"
      ];
    };

    build.extraAttrs = {
      sourceRoot = "source/client";
      nativeBuildInputs = with pkgs; [
        cargo
        rustc
        wasm-pack
        wasm-bindgen-cli_0_2_99
        lld
        binaryen
        rustPlatform.cargoSetupHook
      ];
      cargoDeps = pkgs.rustPlatform.fetchCargoVendor {
        name = "winden-cargo-deps-0.2.99";
        src = pkgs.applyPatches {
          name = "source";
          src = pkgs.winden.src;
          sourceRoot = "source/client";
          patches = [ ./0001-use-git-for-magic-wormhole.patch ];
        };
        sourceRoot = "source/wasm";
        hash = "sha256-ZCJWAqx/64PhJMVOKxZsf29NgBW9nKlYlbsWLAJLTSM=";
      };
      cargoRoot = "wasm";

      makeCacheWritable = true;
      npmDepsFetcherVersion = 2;
      env.SENTRYCLI_SKIP_DOWNLOAD = "1";
      env.RUSTFLAGS = "-C target-feature=-reference-types,-multivalue";
      env.CFLAGS_wasm32_unknown_unknown = "-mno-reference-types -mno-multivalue";

      postPatch = ''
        # Prevent npmConfigHook from running automatically
        npmConfigHook() {
          echo "Bypassing npmConfigHook..."
        }

        # Fix ESM import of pkg in Webpack 5 (where pkg.default is undefined)
        substituteInPlace src/app/sagas.ts \
          --replace-fail 'import("../../pkg").then((pkg) => pkg.default);' 'import("../../pkg").then((pkg) => pkg.default || pkg);'
      '';

      configurePhase = ''
        runHook preConfigure
        echo "Configuring npm manually to bypass fsevents lockfile bug"
        export npm_config_cache="$(mktemp -d)"
        cp -r "$npmDeps"/* "$npm_config_cache"
        chmod -R +w "$npm_config_cache"

        # Instruct WasmPackPlugin not to attempt online cargo install of wasm-bindgen-cli
        substituteInPlace webpack.config.js \
          --replace-fail 'outDir: path.resolve(__dirname, "./pkg"),' 'outDir: path.resolve(__dirname, "./pkg"), extraArgs: "--mode no-install",'

        npm install --cache "$npm_config_cache" --offline --ignore-scripts --no-audit --legacy-peer-deps --omit=optional

        patchShebangs node_modules

        runHook postConfigure
      '';

      buildPhase = ''
        export HOME=$(mktemp -d)
        npm run build
      '';

      installPhase = ''
        mkdir -p $out/share/winden
        cp -r dist/* $out/share/winden/
      '';
    };
  };
}
