{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkEnv = isLocal: {
    FUNKWHALE_URL = "http://localhost:5000";
    DJANGO_SETTINGS_MODULE = "config.settings.production";
    DJANGO_ALLOWED_HOSTS = "127.0.0.1:5000,localhost:5000,0.0.0.0:5000";

    DATABASE_URL = "postgresql://postgres@${if isLocal then "localhost" else "postgres"}:5432/postgres";
    CACHE_URL = "redis://${if isLocal then "localhost" else "redis"}:6379/0";
    TYPESENSE_URL = "http://${if isLocal then "localhost" else "funkwhale-typesense"}:8108";
    TYPESENSE_API_KEY = "publicly-secret-key";

    FUNKWHALE_SPA_HTML_ROOT = "/var/lib/funkwhale/frontend/index.html";
    MEDIA_ROOT = "/var/lib/funkwhale/media";
    MUSIC_DIRECTORY_PATH = "/var/lib/funkwhale/music";

    REVERSE_PROXY_TYPE = "nginx";
    C_FORCE_ROOT = "true";
  };

  containerEnv = mkEnv false;
  nixosEnv = mkEnv true;
in
{
  name = "funkwhale-app";
  displayName = "Funkwhale";
  description = "A federated platform for audio streaming, exploration, and publishing.";
  usage = ''
    #### Create a superuser

    To manage your instance, you first need to create a superuser account:

    **Containers:**

    ```bash
    podman-compose -f result/*/compose.yaml exec funkwhale-server \
      sh -c "set -a; . /var/lib/funkwhale/config/django_secret_key.env; funkwhale-manage fw users create --superuser"
    ```

    **NixOS VM (inside the VM):**

    ```bash
    sudo funkwhale-manage fw users create --superuser
    ```

    #### Open registrations

    By default, registrations are closed. You can open them via the web UI settings or by running:

    **Containers:**

    ```bash
    podman-compose -f result/*/compose.yaml exec funkwhale-server \
      sh -c "set -a; . /var/lib/funkwhale/config/django_secret_key.env; funkwhale-manage fw settings set users.registration_enabled true"
    ```

    **NixOS VM (inside the VM):**

    ```bash
    sudo funkwhale-manage fw settings set users.registration_enabled true
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
    packages = [
      pkgs.mypkgs.funkwhale-server
    ];
    runtimes.shell.enable = true;
  };

  services.components = {
    funkwhale-server = {
      command = "${pkgs.writeShellScript "funkwhale-server-init" ''
        set -e
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}"
        export PATH=$PATH:${pkgs.coreutils}/bin

        mkdir -p "$DATA_DIR/config" "$DATA_DIR/media" "$DATA_DIR/music" "$DATA_DIR/static" "$DATA_DIR/frontend"

        if [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; then
          echo "DJANGO_SECRET_KEY=\"$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 50)\"" > "$DATA_DIR/config/django_secret_key.env"
        fi
        set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a

        echo "Updating frontend assets..."
        rm -rf "$DATA_DIR/frontend/"*
        cp -rL ${pkgs.mypkgs.funkwhale-frontend}/* "$DATA_DIR/frontend/"

        mkdir -p "$DATA_DIR/nginx"
        cat > "$DATA_DIR/nginx/funkwhale.conf" <<'EOF'
        server {
          listen 5000;
          ${import ./nginx.conf.nix {
            frontendPath = "/var/lib/funkwhale/frontend/";
            backendUrl = "http://funkwhale-server:5001";
          }}
        }
        EOF

        ${pkgs.mypkgs.funkwhale-server}/bin/funkwhale-manage migrate --no-input
        export STATIC_ROOT="$DATA_DIR/static"
        ${pkgs.mypkgs.funkwhale-server}/bin/funkwhale-manage collectstatic --no-input

        exec ${pkgs.mypkgs.funkwhale-server}/bin/uvicorn config.asgi:application --host 0.0.0.0 --port 5001
      ''}";
      environment = containerEnv;
    };

    funkwhale-web = {
      command = "${pkgs.writeShellScript "web-init" ''
        exec ${pkgs.nginx}/bin/nginx -c /var/lib/funkwhale/nginx/funkwhale.conf -g "daemon off;"
      ''}";
      ports = [ "5000:5000" ];
    };

    funkwhale-typesense = {
      command = "${pkgs.writeShellScript "typesense-init" ''
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}/typesense"
        export PATH=$PATH:${pkgs.coreutils}/bin

        mkdir -p "$DATA_DIR"
        exec ${pkgs.typesense}/bin/typesense-server \
          --data-dir "$DATA_DIR" \
          --api-key "publicly-secret-key" \
          --api-address 0.0.0.0 \
          --api-port 8108
      ''}";
    };

    funkwhale-worker = {
      command = "${pkgs.writeShellScript "funkwhale-worker-init" ''
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}"
        while [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; do sleep 1; done
        set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
        exec ${pkgs.mypkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp worker --loglevel INFO
      ''}";
      environment = containerEnv;
    };

    funkwhale-beat = {
      command = "${pkgs.writeShellScript "funkwhale-beat-init" ''
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}"
        while [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; do sleep 1; done
        set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
        exec ${pkgs.mypkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp beat --loglevel INFO
      ''}";
      environment = containerEnv;
    };
  };

  services.runtimes.container = {
    enable = true;
    composeFile = ./compose.yaml;
    components.funkwhale-server = {
      packages = [
        pkgs.mypkgs.funkwhale-server
        pkgs.mypkgs.funkwhale-frontend
        pkgs.coreutils
        pkgs.rsync
        pkgs.bash
      ];
    };
    components.funkwhale-worker.packages = [ pkgs.mypkgs.funkwhale-server ];
    components.funkwhale-beat.packages = [ pkgs.mypkgs.funkwhale-server ];
    components.funkwhale-typesense.packages = [ pkgs.typesense ];
    components.funkwhale-web.packages = [ pkgs.nginx ];
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

  services.runtimes.nixos = {
    enable = true;
    packages = [
      (pkgs.writeShellScriptBin "funkwhale-manage" ''
        ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "export ${k}=\"${v}\"") nixosEnv)}

        if [ -f /var/lib/funkwhale/config/django_secret_key.env ]; then
          set -a; . /var/lib/funkwhale/config/django_secret_key.env; set +a
        fi

        exec ${pkgs.mypkgs.funkwhale-server}/bin/funkwhale-manage "$@"
      '')
    ];
    nixosConfig = {
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
        apiKeyFile = pkgs.writeText "surely-not-in-store" "publicly-secret-key";
      };

      systemd.services = lib.mapAttrs (name: _: {
        environment = lib.mkForce nixosEnv;
      }) config.services.components;

      services.nginx = {
        enable = true;
        virtualHosts."localhost" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 5000;
            }
          ];
          extraConfig = import ./nginx.conf.nix {
            frontendPath = "${pkgs.mypkgs.funkwhale-frontend}/";
            backendUrl = "http://127.0.0.1:5001";
          };
        };
      };
    };
  };
}
