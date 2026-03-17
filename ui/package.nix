{
  buildElmApplication,
  fetchzip,
  jq,
  symlinkJoin,

  _forge-config,
  _forge-options,
}:

let
  main = buildElmApplication {
    pname = "forge-ui-elm";
    version = "0.1.0";
    src = ./.;
    elmLock = ./elm.lock;
    entry = [ "src/Main.elm" ];
    output = "js/Elm.js";
    doMinification = true;
    enableOptimizations = true;
  };

  options = buildElmApplication {
    pname = "forge-ui-options";
    version = "0.1.0";
    src = ./.;
    elmLock = ./elm.lock;
    entry = [ "src/OptionsMain.elm" ];
    output = "options.js";
    doMinification = true;
    enableOptimizations = true;
  };

  agentsFile = ../AGENTS.md;

  bootstrapCss = fetchzip rec {
    pname = "bootstrap";
    version = "5.3.8";
    url = "https://github.com/twbs/bootstrap/releases/download/v${version}/bootstrap-${version}-dist.zip";
    hash = "sha256-StRhHJIRGzguLlo0BGOAMy0PCCmMovzgU/5xZJgVrqQ=";
  };
in
symlinkJoin {
  name = "forge-ui";
  paths = [
    main
    options
  ];
  postBuild = ''
    pushd $out

    # Copy static files
    cp ${./src/index.html} index.html
    cp ${./src/options.html} options.html
    cp -aR ${./src/css}/. css
    cp -aR ${./src/js}/. js
    chmod -R u+w css js
    cp ${bootstrapCss}/css/bootstrap.min.css css/bootstrap.min.css

    # Symlink config files
    ln -s ${_forge-config} forge-config.json
    ln -s ${_forge-options} options.json

    # Rename minimized Elm output
    mv js/Elm.min.js js/Elm.js
    mv options.min.js js/options.js

    # github pages SPA workaround for routing
    for app in $(${jq}/bin/jq '.apps.[].name' -r forge-config.json); do
      mkdir -p "app/$app"
      ln -s $out/index.html "app/$app/index.html"
    done

    ln -s $out/options.html options/index.html

    popd
  '';
  passthru = { inherit bootstrapCss; };
}
