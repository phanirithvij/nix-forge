{
  pkgs,
  config,
  ...
}:

{
  apps.winden = {
    displayName = "Winden";
    description = "Securely transfer files between computers via the browser.";
    usage = ''
      Winden is a web interface for Magic Wormhole.

      > [!TIP]
      > If you do not have two separate machines to test file transfers, you can simply open Winden in two separate browser tabs or windows on the same machine to act as the sender and receiver.
    '';

    links = {
      website = "https://winden.app";
      source = "https://github.com/LeastAuthority/winden";
    };

    ngi.grants = {
      Core = [
        "Winden-MWH-Dilation"
      ];
    };

    icon = ./icon.svg;

    programs = {
      packages = [ pkgs.winden ];
    };

    services = {
      components.web = {
        process.command = "${pkgs.caddy}/bin/caddy";
        process.argv = [
          "run"
          "--adapter"
          "caddyfile"
          "--config"
          "${pkgs.writeText "Caddyfile" ''
            :8080 {
              root * ${pkgs.winden}/share/winden

              handle_path /mailbox/* {
                reverse_proxy 127.0.0.1:4000
              }

              handle_path /relay* {
                reverse_proxy 127.0.0.1:4002
              }

              file_server
              try_files {path} /index.html
            }
          ''}"
        ];
        process.ports = [ "8080:8080" ];
      };

      # Reuse components from the magic-wormhole app recipe
      components.mailbox = {
        process = config.apps.magic-wormhole.services.components.mailbox.process;
      };

      # Winden requires websocket support in the transit relay
      components.transit = {
        process = config.apps.magic-wormhole.services.components.transit.process // {
          argv = [
            "-n"
            "transitrelay"
            "--port=tcp:4001"
            "--websocket=tcp:4002"
          ];
          ports = [
            "4001:4001"
            "4002:4002"
          ];
        };
      };

      runtimes.container.enable = true;
      runtimes.nixos.enable = true;
    };

    test.services.script = ''
      curl --retry 5 --retry-max-time 120 --retry-all-errors http://localhost:8080 | grep -q "Winden"
    '';
  };
}
