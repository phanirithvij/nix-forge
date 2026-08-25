{
  lib,
  config,
  pkgs,
  ...
}:

let
  settings = {
    # Plugins such as nftables and ipset require CAP_NET_ADMIN which is not available
    # by default in the container runtime. They are included here as an example of how
    # to expose them programmatically.
    # plugins = {
    #   ipset = {
    #     path = "${pkgs.reaction.plugins.reaction-plugin-ipset}/bin/reaction-plugin-ipset";
    #     systemd = false;
    #   };
    #   nftables = {
    #     path = "${pkgs.reaction.plugins.reaction-plugin-nftables}/bin/reaction-plugin-nftables";
    #     systemd = false;
    #   };
    #   virtual = {
    #     path = "${pkgs.reaction.plugins.reaction-plugin-virtual}/bin/reaction-plugin-virtual";
    #     systemd = false;
    #   };
    # };
    patterns = {
      ip = {
        type = "ip";
        ignore = [ "127.0.0.1" ];
      };
    };
    streams = {
      ssh = {
        cmd = [
          "tail"
          "-f"
          "/dev/null"
        ];
        filters = {
          failedlogin = {
            regex = [ "Failed password for .* from <ip>" ];
            retry = 3;
            retryperiod = "6h";
            actions = {
              ban = {
                cmd = [
                  "echo"
                  "ban"
                  "<ip>"
                ];
              };
            };
          };
        };
      };
    };
  };

  settingsFormat = pkgs.formats.yaml { };

  settingsDir = pkgs.runCommand "reaction-settings-dir" { } ''
    mkdir -p $out
    ln -s ${settingsFormat.generate "reaction.yml" settings} $out/reaction.yml
  '';
in
{
  apps.reaction = {
    displayName = "Reaction";
    description = "Scan logs and take action: an alternative to fail2ban";
    usage = ''
      reaction is an alternative to fail2ban that is easier to use, faster and more robust.
      It scans application logs and acts on predefined patterns.
    '';
    links = {
      website = "https://framagit.org/ppom/reaction";
      source = "https://framagit.org/ppom/reaction";
    };

    services = {
      components.reaction = {
        process.command = pkgs.reaction;
        process.argv = [
          "start"
          "-c"
          "${settingsDir}"
        ];
        process.user = "root";
        process.preStart = ''
          # Cleanup lockfile in case of previous ungraceful shutdown
          rm -f /var/lib/reaction/reaction.lock || true
        '';
      };

      runtimes = {
        container = {
          enable = true;
          components.reaction = {
            packages = [
              pkgs.coreutils
              pkgs.reaction
              pkgs.iptables
              pkgs.ipset
              pkgs.nftables
            ];
          };
        };

        nixos = {
          enable = true;
          packages = [
            pkgs.reaction
            pkgs.iptables
            pkgs.ipset
            pkgs.nftables
          ];
          # Do not enable services.reaction to avoid systemd name collision with the component
        };
      };
    };

    test.services.script = ''
      # Helper to run reaction client commands either in VM or inside container
      run_reaction() {
        if command -v podman >/dev/null && podman ps | grep -q reaction; then
          podman exec reaction_reaction_1 ${lib.getExe pkgs.reaction} "$@"
        else
          ${lib.getExe pkgs.reaction} "$@"
        fi
      }

      # Wait until the daemon responds
      timeout 120 bash -c 'until run_reaction show >/dev/null 2>&1; do sleep 1; done'

      # Syntax check
      run_reaction test-config -c ${settingsDir}

      # Verify reaction is active and working
      run_reaction show
    '';
  };
}
