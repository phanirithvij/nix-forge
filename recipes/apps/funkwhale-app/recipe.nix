{
  config,
  lib,
  pkgs,
  ...
}:

let
  commonEnv = {
    FUNKWHALE_URL = "http://localhost:5000";
    DJANGO_SETTINGS_MODULE = "config.settings.production";
    DJANGO_ALLOWED_HOSTS = "127.0.0.1:5000,localhost:5000,0.0.0.0:5000";

    TYPESENSE_API_KEY = "publicly-secret-key";

    FUNKWHALE_SPA_HTML_ROOT = "/var/lib/funkwhale/frontend/index.html";
    MEDIA_ROOT = "/var/lib/funkwhale/media";
    MUSIC_DIRECTORY_PATH = "/var/lib/funkwhale/music";

    REVERSE_PROXY_TYPE = "nginx";
    C_FORCE_ROOT = "true";
  };

  mkEnv =
    isLocal:
    {
      DATABASE_URL = "postgresql://postgres@${if isLocal then "localhost" else "postgres"}:5432/postgres";
      CACHE_URL = "redis://${if isLocal then "localhost" else "redis"}:6379/0";
      TYPESENSE_URL = "http://${if isLocal then "localhost" else "funkwhale-typesense"}:8108";
    }
    // commonEnv;

  containerEnv = mkEnv false;
  nixosEnv = mkEnv true;

  mkHelpers =
    env:
    let
      manage-helper = pkgs.writeShellScriptBin "funkwhale-manage-helper" ''
        set -a
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") env)}
        [ -f /var/lib/funkwhale/config/django_secret_key.env ] && . /var/lib/funkwhale/config/django_secret_key.env
        set +a
        exec ${pkgs.funkwhale-server}/bin/funkwhale-manage "$@"
      '';
    in
    [
      manage-helper
      (pkgs.writeShellScriptBin "funkwhale-enable-registrations" ''
        echo '
        from dynamic_preferences.registries import global_preferences_registry
        manager = global_preferences_registry.manager()
        manager["users__registration_enabled"] = True
        ' | ${manage-helper}/bin/funkwhale-manage-helper shell \
          && echo "New user registrations enabled." || echo "Failed to enable new user registrations."
      '')
    ];

  baseCSP = ''
    add_header Content-Security-Policy "default-src 'self'; connect-src https: wss: http: ws: 'self' 'unsafe-eval'; script-src 'self' 'wasm-unsafe-eval'; style-src https: http: 'self' 'unsafe-inline'; img-src https: http: 'self' data:; font-src https: http: 'self' data:; media-src https: http: 'self' data:; object-src 'none'";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Service-Worker-Allowed "/";
  '';

  nginxLocations =
    {
      frontendPath,
      backendUrl,
      mediaRoot,
      musicDir,
      staticRoot,
    }:
    {
      "/api/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
        extraConfig = "client_max_body_size 100M;";
      };
      "~ ^/library/(albums|tracks|artists|playlists)/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
      };
      "/channels/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
      };
      "~ ^/@(vite-plugin-pwa|vite|id)/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
      };
      "/front/" = {
        alias = "''${frontendPath}/";
        extraConfig = "expires 1d;";
      };
      "~ \"/(front/)?embed.html\"" = {
        alias = "''${frontendPath}/embed.html";
        extraConfig = ''
          add_header Content-Security-Policy "connect-src https: http: 'self'; default-src 'self'; script-src 'self' unpkg.com 'unsafe-inline' 'unsafe-eval'; style-src https: http: 'self' 'unsafe-inline'; img-src https: http: 'self' data:; font-src https: http: 'self' data:; object-src 'none'; media-src https: http: 'self' data:";
          add_header Referrer-Policy "strict-origin-when-cross-origin";
          expires 1d;
        '';
      };
      "/federation/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
      };
      "/rest/" = {
        proxyPass = "''${backendUrl}/api/subsonic/rest/";
        proxyWebsockets = true;
      };
      "/.well-known/" = {
        proxyPass = backendUrl;
        proxyWebsockets = true;
      };
      "/media/__sized__/" = {
        alias = "''${mediaRoot}/__sized__/";
        extraConfig = "add_header Access-Control-Allow-Origin '*';";
      };
      "/media/attachments/" = {
        alias = "''${mediaRoot}/attachments/";
        extraConfig = "add_header Access-Control-Allow-Origin '*';";
      };
      "/media/dynamic_preferences/" = {
        alias = "''${mediaRoot}/dynamic_preferences/";
        extraConfig = "add_header Access-Control-Allow-Origin '*';";
      };
      "~ /_protected/media/(.+)" = {
        alias = "''${mediaRoot}/$1";
        extraConfig = "internal;\nadd_header Access-Control-Allow-Origin '*';";
      };
      "/_protected/music/" = {
        alias = "''${musicDir}/";
        extraConfig = "internal;\nadd_header Access-Control-Allow-Origin '*';";
      };
      "/manifest.json" = {
        return = "302 http://$host/api/v2/instance/spa-manifest.json";
      };
      "/staticfiles/" = {
        alias = "''${staticRoot}/";
      };
      "/" = {
        alias = "''${frontendPath}/";
        extraConfig = "try_files $uri $uri/ /index.html;";
      };
    };

  mkNginxConf =
    locations:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (path: loc: ''
        location ${path} {
          ${lib.optionalString (loc.proxyPass or null != null) ''
            proxy_pass ${loc.proxyPass};
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port $server_port;
          ''}
          ${lib.optionalString (loc.alias or null != null) "alias ${loc.alias};"}
          ${lib.optionalString (loc.return or null != null) "return ${loc.return};"}
          ${loc.extraConfig or ""}
        }
      '') locations
    );
in
{
  apps.funkwhale = {
    displayName = "Funkwhale";
    description = "A federated platform for audio streaming, exploration, and publishing.";
    usage = ''
      #### Create a superuser

      To manage your instance, you first need to create a superuser account:

      **Containers:**

      ```bash
      podman-compose -f result/*/compose.yaml exec funkwhale-server funkwhale-manage-helper fw users create --superuser
      ```

      **NixOS VM (inside the VM):**

      ```bash
      sudo funkwhale-manage-helper fw users create --superuser
      ```

      #### Open registrations

      By default, registrations are closed. You can open them via the web UI settings or by running:

      **Containers:**

      ```bash
      podman-compose -f result/*/compose.yaml exec funkwhale-server funkwhale-enable-registrations
      ```

      **NixOS VM (inside the VM):**

      ```bash
      sudo funkwhale-enable-registrations
      ```

      #### Access management shell

      You access the Funkwhale management tools via the shell

      ```bash
      funkwhale-manage --help
      ```
    '';

    ngi.grants = {
      Commons = [ "Funkwhale-AP" ];
      Entrust = [
        "Funkwhale"
        "FunkWhale-Federation"
      ];
    };

    links = {
      website = "https://www.funkwhale.audio/";
      source = "https://dev.funkwhale.audio/funkwhale/funkwhale";
      docs = "https://docs.funkwhale.audio/";
    };

    icon = ./icon.svg;

    programs = {
      packages = [ pkgs.funkwhale-server ];
      runtimes.shell.enable = true;
    };

    services.components = {
      funkwhale-server = {
        stateDir = "/var/lib/funkwhale";
        command = "${pkgs.writeShellScript "funkwhale-server-init" ''
          set -e
          export DATA_DIR="/var/lib/funkwhale"
          export PATH=$PATH:${pkgs.coreutils}/bin

          mkdir -p "$DATA_DIR/config" "$DATA_DIR/media" "$DATA_DIR/music" "$DATA_DIR/static" "$DATA_DIR/frontend" "$DATA_DIR/nginx"

          if [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; then
            echo "DJANGO_SECRET_KEY=\"$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 50)\"" > "$DATA_DIR/config/django_secret_key.env"
          fi
          set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a

          echo "Updating frontend assets..."
          chmod -R u+w "$DATA_DIR/frontend/" || true
          rm -rf "$DATA_DIR/frontend/"*
          cp -rL --no-preserve=mode ${pkgs.funkwhale-frontend}/* "$DATA_DIR/frontend/"

          cat > "$DATA_DIR/nginx/funkwhale.conf" <<'EOF'
          server {
            listen 5000;
            ${baseCSP}
            ${mkNginxConf (nginxLocations {
              frontendPath = "/var/lib/funkwhale/frontend";
              backendUrl = "http://127.0.0.1:5001";
              mediaRoot = "/var/lib/funkwhale/media";
              musicDir = "/var/lib/funkwhale/music";
              staticRoot = "/var/lib/funkwhale/static";
            })}
          }
          EOF

          ${pkgs.funkwhale-server}/bin/funkwhale-manage migrate --no-input
          export STATIC_ROOT="$DATA_DIR/static"
          ${pkgs.funkwhale-server}/bin/funkwhale-manage collectstatic --no-input

          exec ${pkgs.funkwhale-server}/bin/uvicorn config.asgi:application --host 0.0.0.0 --port 5001
        ''}";
        environment = containerEnv;
        ports = [ "5000:5000" ];
      };

      funkwhale-typesense = {
        stateDir = "/var/lib/typesense";
        command = "${pkgs.writeShellScript "typesense-init" ''
          export DATA_DIR="/var/lib/typesense"
          export PATH=$PATH:${pkgs.coreutils}/bin

          mkdir -p "$DATA_DIR"
          exec ${pkgs.typesense}/bin/typesense-server \
            --data-dir "$DATA_DIR" \
            --api-key ${commonEnv.TYPESENSE_API_KEY} \
            --api-address 0.0.0.0 \
            --api-port 8108
        ''}";
      };
    };

    services.runtimes.container = {
      enable = true;
      composeFile = ./compose.yaml;
      components.funkwhale-server.packages = [
        pkgs.funkwhale-server
        pkgs.funkwhale-frontend
        pkgs.coreutils
        pkgs.rsync
        pkgs.bash
      ]
      ++ (mkHelpers containerEnv);
      components.funkwhale-typesense.packages = [ pkgs.typesense ];
    };

    services.runtimes.nixos = {
      enable = true;
      packages = mkHelpers nixosEnv;
      nixosConfig = {
        users.users.funkwhale = {
          isSystemUser = true;
          group = "funkwhale";
        };
        users.groups.funkwhale = { };

        services.postgresql = {
          enable = true;
          enableTCPIP = true;
          authentication = lib.mkForce ''
            local all all trust
            host all all 0.0.0.0/0 trust
            host all all ::0/0 trust
          '';
        };
        services.redis.servers."".enable = true;
        services.typesense = {
          enable = true;
          settings.server.api-address = "127.0.0.1";
          apiKeyFile = pkgs.writeText "typesense-api-key-secret" commonEnv.TYPESENSE_API_KEY;
        };

        systemd.services.funkwhale-server = {
          environment = lib.mkForce nixosEnv;
          serviceConfig = {
            User = lib.mkForce "funkwhale";
            Group = lib.mkForce "funkwhale";
            StateDirectory = lib.mkForce "funkwhale";
          };
        };

        systemd.services.funkwhale-typesense.enable = lib.mkForce false;

        systemd.services.funkwhale-worker = {
          description = "Funkwhale Celery Worker";
          wantedBy = [ "multi-user.target" ];
          after = [ "funkwhale-server.service" ];
          requires = [ "funkwhale-server.service" ];
          environment = nixosEnv;
          serviceConfig = {
            User = "funkwhale";
            Group = "funkwhale";
            StateDirectory = "funkwhale";
            WorkingDirectory = "/var/lib/funkwhale";
            ExecStart = "${pkgs.writeShellScript "funkwhale-worker-init" ''
              export DATA_DIR="/var/lib/funkwhale"
              export PATH=$PATH:${pkgs.coreutils}/bin
              set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
              exec ${pkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp worker --loglevel INFO
            ''}";
          };
        };

        systemd.services.funkwhale-beat = {
          description = "Funkwhale Celery Beat";
          wantedBy = [ "multi-user.target" ];
          after = [ "funkwhale-server.service" ];
          requires = [ "funkwhale-server.service" ];
          environment = nixosEnv;
          serviceConfig = {
            User = "funkwhale";
            Group = "funkwhale";
            StateDirectory = "funkwhale";
            WorkingDirectory = "/var/lib/funkwhale";
            ExecStart = "${pkgs.writeShellScript "funkwhale-beat-init" ''
              export DATA_DIR="/var/lib/funkwhale"
              export PATH=$PATH:${pkgs.coreutils}/bin
              set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
              exec ${pkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp beat --loglevel INFO
            ''}";
          };
        };

        services.nginx = {
          enable = true;
          virtualHosts.localhost = {
            listen = [
              {
                addr = "0.0.0.0";
                port = 5000;
              }
            ];
            extraConfig = baseCSP;
            locations = nginxLocations {
              frontendPath = "${pkgs.funkwhale-frontend}";
              backendUrl = "http://127.0.0.1:5001";
              mediaRoot = commonEnv.MEDIA_ROOT;
              musicDir = commonEnv.MUSIC_DIRECTORY_PATH;
              staticRoot = "${pkgs.funkwhale-server}/lib/funkwhale_api/static";
            };
          };
        };
      };
    };

    test = {
      packages = [
        pkgs.curl
        pkgs.gnugrep
      ];
      script = ''
        echo "Waiting for Funkwhale API..."
        curl="curl --retry 30 --retry-delay 2 --retry-all-errors -s -f"

        if $curl http://localhost:5000/api/v1/instance/nodeinfo/2.0/; then
          echo "Funkwhale API is up!"
        else
          echo "Timed out waiting for API"
          exit 1
        fi

        echo "Checking Frontend UI..."
        if $curl http://localhost:5000 | grep -q "funkwhale"; then
          echo "Frontend is serving correctly!"
        else
          echo "Frontend check failed"
          exit 1
        fi

        echo "Checking static assets..."
        if $curl -I http://localhost:5000/manifest.json | grep -qi "application/json"; then
          echo "Static assets have correct MIME types!"
        else
          echo "MIME type check failed"
          exit 1
        fi
      '';
      sandbox = false;
    };
  };
}
