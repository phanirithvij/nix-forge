{
  config,
  forge-lib,
  lib,
  pkgs,
  ...
}:

let
  app = config.apps.galene;
  portStr = toString app.parameters.port;
  usageSnippets = forge-lib.snippets.usage app;

  publicRoomConfig = builtins.toJSON {
    public = true;
    displayName = "Public";
    description = "Public meeting room";
    allow-recording = true;
    users.speech-to-text = {
      password = "stt";
      permissions = [
        "caption"
        "message"
      ];
    };
  };

  adminDataConfig = builtins.toJSON {
    users.admin = {
      password = "admin";
      permissions = "admin";
    };
    writableGroups = true;
  };

  galenectlConfig = builtins.toJSON {
    server = "http://localhost:${portStr}";
    admin-username = "admin";
    admin-password = "admin";
  };
in
{
  pkgs.galene = {
    build.builders.identity = {
      enable = true;
      derivation = pkgs.pkgsOriginal.galene;
    };
  };

  pkgs.galene-stt = {
    build.builders.identity = {
      enable = true;
      derivation = pkgs.pkgsOriginal.galene-stt;
    };
  };

  apps.galene = {
    displayName = "Galène";
    description = "Videoconferencing server that is easy to deploy, written in Go.";
    categories = with forge-lib.categories; [ VideoConference ];
    longDescription = ''
      Galène is a self-hosted videoconferencing server designed to be easy
      to install, preserve user privacy, and operate with moderate server
      resources. It features an in-browser WebRTC client, screen sharing,
      live subtitles, recording, and chat.
    '';
    usage = ''
      First, ${usageSnippets.run-container} or ${usageSnippets.run-nixos}.

      #### Web Interface

      Open the [web interface](http://localhost:${toString app.services.components.galene.endpoints.web.forwardedPort})
      in your browser to join an existing room (such as the default `public` room) or create a new session.

      #### Creating Rooms and Users

      Galène includes a pre-configured administrator account (`admin` / `admin`).
      You can manage rooms and user accounts using the `galenectl` command-line tool.

      1. Open a terminal inside the running container:

      ```bash
      podman exec -it galene_galene_1 bash
      ```

      *(If running in a NixOS VM, log in at the console as `root`)*

      2. Create a room and invite participants:

      ```bash
      # Create a new room called 'room1' with recording allowed
      echo '{"allow-recording": true}' | galenectl -insecure -server http://localhost:${portStr} -admin-username admin -admin-password admin create-group -group room1 -json

      # Add a moderator ('alice') with operator permissions (mute, kick, lock, record)
      galenectl -insecure -server http://localhost:${portStr} -admin-username admin -admin-password admin create-user -group room1 -user alice -permissions op
      galenectl -insecure -server http://localhost:${portStr} -admin-username admin -admin-password admin set-password -group room1 -user alice

      # Add a regular participant ('bob')
      galenectl -insecure -server http://localhost:${portStr} -admin-username admin -admin-password admin create-user -group room1 -user bob
      galenectl -insecure -server http://localhost:${portStr} -admin-username admin -admin-password admin set-password -group room1 -user bob
      ```

      Once created, participants can navigate directly to `http://localhost:${portStr}/group/room1/` to join.

      Alternatively, pass the generated config file:

      ```bash
      echo '{"allow-recording": true}' | galenectl -insecure -config /var/lib/galene/data/galenectl.json create-group -group room1 -json
      ```

      For additional details, see the [Galène documentation](${app.links.docs}).

      #### Video Sharing and File Transfers

      - **Camera & Microphone**: Browsers require a secure context (`http://localhost` or `https://`) to grant camera, microphone, and screen capture permissions.
      - **Broadcasting Video & Audio**: Select "Camera and microphone" upon connecting or click **Enable** (play icon) in the top navigation bar. Click **Share Screen** to present a display or window.
      - **Transferring Files**: In the room participant list, click any participant's username and select **Send file**. File transfers happen peer-to-peer directly between browsers. The recipient will receive an on-screen prompt with an **Accept** button to download the file.
      - **Networking**: Galène uses UDP multiplexing on port ${portStr} and built-in TURN on port 1194 (UDP/TCP) so media streams and data channels traverse container NAT boundaries seamlessly.

      #### Recording Sessions

      Galène supports server-side session recording to disk in `.webm` format:
      - **Permission Requirements**: In Galène, operator (`op`) permissions automatically grant recording rights **if and only if** recording is allowed in that room (`"allow-recording": true`). This is enabled by default in the `public` room. In custom rooms, enable it by creating the room with `{"allow-recording": true}` (as shown above) or grant explicit recording permissions (`-permissions '["op", "record"]'`).
      - **How to Record**: Any user with recording rights can type `/record` in the in-meeting chat box to start recording, and `/unrecord` to stop. An on-screen status banner notifies all participants while recording is active.
      - **Where Recordings Are Stored**: Recording files are saved on the server under `/var/lib/galene/recordings/<room-name>/`.
      - **Viewing and Downloading**: Recordings can be downloaded or replayed directly from `http://localhost:${portStr}/recordings/<room-name>/` by users with `record` or `op` permissions.

      #### Live Subtitles and Speech-to-Text (Whisper AI)

      Galène supports automated real-time speech-to-text transcription powered by local Whisper AI (`galene-stt`).

      This feature is disabled by default to keep resource usage minimal. You can enable it using the Forge CLI:

      ```bash
      # Run in a container with speech-to-text enabled
      forge run galene.container --set stt=true

      # Or run directly via Nix
      nix run github:ngi-nix/forge#forge -- run galene.container --set stt=true
      ```

      In the [NGI Forge Web UI](https://ngi.nixos.org), you can also toggle `stt` directly in the application parameters form before launching.

      If deploying Galène in a Nix flake:

      ```nix
      forge.apps.galene.parameters.stt.value = true;
      ```

      When enabled, a transcription bot connects to the default `public` room, transcribes spoken conversation in real time using the Whisper model at `/var/lib/galene-stt/model.bin`, and broadcasts live subtitles to participants.
    '';

    links = {
      website = "https://galene.org";
      docs = "https://galene.org/INSTALL.html";
      source = "https://github.com/jech/galene";
    };

    ngi.grants = {
      Core = [
        "Galene"
      ];
      Commons = [
        "Galene-UX"
      ];
    };

    icon = ./icon.svg;

    parameters = {
      port = {
        value = 8443;
        description = "HTTP listen port for Galène.";
      };
      turn = {
        value = "127.0.0.1:1194";
        description = "Built-in TURN server listen address. Set to \"\" to disable, or \"127.0.0.1:1194\" to enable.";
      };
      stt = {
        value = false;
        description = "Enable real-time speech-to-text companion bot (galene-stt) using Whisper AI.";
      };
    };

    services = {
      components = {
        galene = {
          process = {
            command = pkgs.writeShellScriptBin "galene" ''
              ulimit -n 65536 2>/dev/null || true
              exec ${lib.getExe pkgs.galene} "$@"
            '';
            argv = [
              "-insecure"
              "-http"
              ":${portStr}"
              "-udp-range"
              portStr
              "-turn"
              app.parameters.turn
              "-data"
              "/var/lib/galene/data"
              "-groups"
              "/var/lib/galene/groups"
              "-recordings"
              "/var/lib/galene/recordings"
              "-static"
              "${pkgs.galene.static}/static"
            ];
            preStart = ''
              # Wait for container network interface to complete IPv6 Duplicate Address Detection
              sleep 1

              mkdir -p /var/lib/galene/data /var/lib/galene/groups /var/lib/galene/recordings /var/lib/galene/.config/galene
              if [ ! -f /var/lib/galene/groups/public.json ]; then
                echo '${publicRoomConfig}' > /var/lib/galene/groups/public.json
              fi
              if [ ! -f /var/lib/galene/data/config.json ]; then
                echo '${adminDataConfig}' > /var/lib/galene/data/config.json
              fi
              if [ ! -f /var/lib/galene/data/galenectl.json ]; then
                echo '${galenectlConfig}' > /var/lib/galene/data/galenectl.json
                cp /var/lib/galene/data/galenectl.json /var/lib/galene/.config/galene/galenectl.json
              fi
            '';
            packages = [
              pkgs.coreutils
            ];
          };

          healthcheck = {
            enable = true;
            test = [
              "${lib.getExe pkgs.curl}"
              "-fs"
              "http://localhost:${portStr}/"
            ];
            packages = [ pkgs.curl ];
            interval = "3s";
            timeout = "3s";
            startPeriod = "5s";
            retries = 10;
          };

          endpoints = {
            web = {
              port = app.parameters.port;
            };
            webrtc-udp = {
              port = app.parameters.port;
              protocol = "udp";
              appProtocol = "webrtc";
            };
          }
          // lib.optionalAttrs (app.parameters.turn != "") {
            turn-udp = {
              port = 1194;
              protocol = "udp";
              appProtocol = "turn";
            };
            turn-tcp = {
              port = 1194;
              protocol = "tcp";
              appProtocol = "turn";
            };
          };
        };
      }
      // lib.optionalAttrs app.parameters.stt {
        stt = {
          process = {
            command = pkgs.galene-stt;
            argv = [
              "-insecure"
              "-caption"
              "-chat"
              "-gpu=false"
              "-model"
              "/var/lib/galene-stt/model.bin"
              "-username"
              "speech-to-text"
              "-password"
              "stt"
              "http://galene:${portStr}/group/public/"
            ];
            packages = [
              pkgs.galene-stt
            ];
          };
          dependsOn = [ "galene" ];
        };
      };

      runtimes = {
        container = {
          enable = true;
          components = {
            galene = {
              packages = [
                pkgs.bash
                pkgs.coreutils
                pkgs.galene
              ];
            };
          }
          // lib.optionalAttrs app.parameters.stt {
            stt = {
              packages = [
                pkgs.bash
                pkgs.coreutils
                pkgs.galene-stt
              ];
            };
          };
        };

        nixos = {
          enable = true;
          packages = [
            pkgs.galene
          ]
          ++ lib.optional app.parameters.stt pkgs.galene-stt;
          nixosConfig = {
            systemd.services.galene.serviceConfig.LimitNOFILE = 65536;
          };
        };
      };
    };

    test.services = {
      nixosConfig =
        { config, ... }:
        {
          virtualisation.diskSize = lib.mkForce 8192;
          virtualisation.memorySize = lib.mkForce 4096;
          systemd.services.galene-stt = lib.mkIf (!config.virtualisation.podman.enable) {
            description = "Galène Speech-to-Text companion bot";
            after = [ "galene.service" ];
            serviceConfig = {
              ExecStart = "${lib.getExe pkgs.galene-stt} -insecure -caption -chat -gpu=false -model ${pkgs.galene-stt.testModel} -username speech-to-text -password stt http://127.0.0.1:${portStr}/group/public/";
              Restart = "always";
              RestartSec = "1";
              DynamicUser = true;
            };
          };
        };
      packages = [
        pkgs.curl
        pkgs.galene
        pkgs.galene-stt
      ];
      script = ''
        curl="curl --retry 10 --retry-max-time 120 --retry-all-errors"

        $curl -fs "http://localhost:${portStr}/" | grep "Galène"
        $curl -fs "http://localhost:${portStr}/group/public/" | grep "Galène"

        galenectl -insecure -server "http://localhost:${portStr}" \
          -admin-username admin -admin-password admin create-group -group room1
        galenectl -insecure -server "http://localhost:${portStr}" \
          -admin-username admin -admin-password admin list-groups | grep "room1"

        if systemctl cat galene-stt.service >/dev/null 2>&1; then
          systemctl start galene-stt.service
          for _ in $(seq 1 30); do
            if systemctl is-active galene-stt.service >/dev/null; then
              break
            fi
            sleep 1
          done
          systemctl is-active galene-stt.service

          # Verify that galene-stt loaded the model and initialized whisper compute buffers
          for _ in $(seq 1 30); do
            if journalctl -u galene-stt | grep -q "whisper_init_state"; then
              break
            fi
            sleep 1
          done
          journalctl -u galene-stt | grep "whisper_init_state"
        fi
      '';
    };
  };
}
