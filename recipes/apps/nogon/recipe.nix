{
  config,
  forge-lib,
  pkgs,
  ...
}:

let
  app = config.apps.nogon;
  port = toString app.parameters.port;
in
{
  pkgs.nogon = {
    build.builders.identity = {
      enable = true;
      derivation = pkgs.pkgsOriginal.nogon;
    };
  };

  apps.nogon = {
    displayName = "Nogon";
    description = "Self-hosted search platform for web history and stored files.";
    categories = with forge-lib.categories; [
      Archiving
      Network
    ];
    longDescription = ''
      Nogon is a private, self-hosted search engine for visited websites and
      stored files, combining full-text search with automatic capture and imports.

      Nogon uses a client and server architecture. The server stores and searches documents.
      Clients collect content or run searches. The nogon program can act as both, while the browser extension is a client.
    '';
    usage = ''
      First, launch the app [in a container](app/${app.name}#run-container) or [in a NixOS VM](app/${app.name}#run-nixos).

      ##### Web Interface

      Open the [web interface](http://localhost:${toString app.services.components.nogon.endpoints.web.forwardedPort}) to search and browse indexed history.

      ##### Importing history

      Content can come from the browser extension, imported browser history or bookmarks, watched directories, crawlers, or API clients.

      See [Browser Ingestion](https://nogon.eu/docs/browser-ingestion) to choose how to collect content.

      Enter the [shell environment](app/${app.name}#run-shell) to add `nogon` to PATH.

      ##### Browser History Import

      Nogon detects a supported browser database, reads qualifying URLs, and asks its crawler to fetch the pages that exist now.
      The import does not inherit the browser session. Sites that need login cookies may return a login page or reject the request.

      ```console
      nogon import browser
      ```

      Read [docs](https://nogon.eu/docs/import#importing-browser-history) for more.

      ##### Browser Extension Capture

      See [https://nogon.eu/docs/browser-extension](https://nogon.eu/docs/browser-extension)

      ##### Browser Bookmark Import

      Import saved bookmarks from Firefox based browsers, Chromium based browsers, or Ladybird:

      ```console
      nogon import browser bookmarks
      nogon import browser bookmarks --browser firefox
      ```
    '';

    links = {
      website = "https://nogon.eu";
      docs = "https://nogon.eu/docs";
      source = "https://github.com/asciimoo/nogon";
    };

    ngi.grants = {
      Commons = [
        "Nogon"
      ];
    };

    icon = ./icon.svg;

    parameters = {
      port = {
        value = 4433;
        description = "Port of the Nogon web interface.";
      };
    };

    services = {
      components.nogon = {
        process = {
          command = pkgs.nogon;
          argv = [
            "listen"
            "-a"
            "0.0.0.0:${port}"
            "-u"
            "http://localhost:${port}"
          ];
          environment = {
            NOGON_DATA_DIR = "/var/lib/nogon";
          };
        };

        healthcheck = {
          enable = true;
          test = [
            "curl"
            "-fs"
            "http://localhost:${port}/healthz"
          ];
          packages = [ pkgs.curl ];
          interval = "60s";
          timeout = "3s";
          startPeriod = "10s";
          retries = 10;
        };

        endpoints = {
          web = {
            port = app.parameters.port;
          };
        };
      };

      runtimes = {
        container = {
          enable = true;
          components.nogon = {
            packages = [
              pkgs.bash
              pkgs.coreutils
              pkgs.nogon
            ];
          };
        };

        nixos = {
          enable = true;
          packages = [
            pkgs.nogon
          ];
        };
      };
    };

    programs = {
      packages = [ pkgs.nogon ];
      runtimes.shell.enable = true;
    };

    test.services = {
      packages = [
        pkgs.curl
        pkgs.nogon
      ];
      script = ''
        curl="curl --retry 10 --retry-max-time 120 --retry-all-errors -fs"

        $curl localhost:${port}/healthz
        $curl localhost:${port}/ | grep "<title>Nogon</title>"
        $curl localhost:${port}/api/config | grep '"title":"Nogon"'
      '';
    };
  };
}
