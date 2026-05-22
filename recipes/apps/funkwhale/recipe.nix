{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "funkwhale-app";
  displayName = "Funkwhale";
  description = "A federated platform for audio streaming, exploration, and publishing.";
  usage = ''
    #### Create a superuser

    To manage your instance, you first need to create a superuser account:

    ```bash
    podman-compose -f result/*/compose.yaml exec funkwhale-server \
      sh -c "set -a; . /var/lib/funkwhale/config/django_secret_key.env; funkwhale-manage fw users create --superuser"
    ```

    #### Open registrations

    By default, registrations are closed. You can open them via the web UI settings or by running:

    ```bash
    podman-compose -f result/*/compose.yaml exec funkwhale-server \
      sh -c "set -a; . /var/lib/funkwhale/config/django_secret_key.env; funkwhale-manage fw settings set users.registration_enabled true"
    ```

    #### Access management shell

    You also access the Funkwhale management tools

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
        cat > "$DATA_DIR/nginx/funkwhale.conf" <<EOF
        server {
          listen 5000;
          client_max_body_size 100M;
          root /var/lib/funkwhale/frontend/;
          sendfile off;
          charset utf-8;

          gzip on;
          gzip_types application/javascript application/vnd.geo+json application/vnd.ms-fontobject application/x-font-ttf application/x-web-app-manifest+json font/opentype image/bmp image/svg+xml image/x-icon text/cache-manifest text/css text/plain text/vcard text/vnd.rim.location.xloc text/vtt text/x-component text/x-cross-domain-policy;

          add_header Content-Security-Policy "default-src 'self'; connect-src https: wss: http: ws: 'self' 'unsafe-eval'; script-src 'self' 'wasm-unsafe-eval'; style-src https: http: 'self' 'unsafe-inline'; img-src https: http: 'self' data:; font-src https: http: 'self' data:; media-src https: http: 'self' data:; object-src 'none'";
          add_header Referrer-Policy "strict-origin-when-cross-origin";
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Service-Worker-Allowed "/";

          location / {
            try_files \$uri \$uri/ @backend;
          }

          location @backend {
            proxy_pass http://funkwhale-server:5001;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
          }

          location /rest/ {
            proxy_pass http://funkwhale-server:5001/api/subsonic/rest/;
          }

          location ~ ^/@(vite-plugin-pwa|vite|id)/ {
            alias /var/lib/funkwhale/frontend/;
            try_files \$uri \$uri/ /index.html;
          }

          location ~ ^/(api|federation|auth|.well-known)/ {
            proxy_pass http://funkwhale-server:5001;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
          }

          location /staticfiles/ {
            alias /var/lib/funkwhale/static/;
            expires 30d;
            add_header Cache-Control "public";
          }

          location /media/ {
            alias /var/lib/funkwhale/media/;
          }

          location /media/__sized__/ {
            alias /var/lib/funkwhale/media/__sized__/;
            add_header Access-Control-Allow-Origin '*';
          }

          location /media/attachments/ {
            alias /var/lib/funkwhale/media/attachments/;
            add_header Access-Control-Allow-Origin '*';
          }

          location /media/dynamic_preferences/ {
            alias /var/lib/funkwhale/media/dynamic_preferences/;
            add_header Access-Control-Allow-Origin '*';
          }

          location ~ /_protected/media/(.+) {
            internal;
            alias /var/lib/funkwhale/media/\$1;
            add_header Access-Control-Allow-Origin '*';
          }

          location /_protected/music/ {
            internal;
            alias /var/lib/funkwhale/music/;
            add_header Access-Control-Allow-Origin '*';
          }

          location /manifest.json {
            return 302 http://\$host:5000/api/v2/instance/spa-manifest.json;
          }
        }
        EOF

        ${pkgs.mypkgs.funkwhale-server}/bin/funkwhale-manage migrate --no-input
        export STATIC_ROOT="$DATA_DIR/static"
        ${pkgs.mypkgs.funkwhale-server}/bin/funkwhale-manage collectstatic --no-input

        exec ${pkgs.mypkgs.funkwhale-server}/bin/uvicorn config.asgi:application --host 0.0.0.0 --port 5001
      ''}";
      ports = [ "5001:5001" ];
      environment = {
        FUNKWHALE_URL = "http://localhost:5000";
        DJANGO_SETTINGS_MODULE = "config.settings.production";
        DJANGO_ALLOWED_HOSTS = "127.0.0.1,localhost,0.0.0.0,127.0.0.1:5000,localhost:5000";
        DATABASE_URL = "postgresql://postgres@postgres:5432/postgres";
        CACHE_URL = "redis://redis:6379/0";
        FUNKWHALE_SPA_HTML_ROOT = "/var/lib/funkwhale/frontend/index.html";
        MEDIA_ROOT = "/var/lib/funkwhale/media";
        MUSIC_DIRECTORY_PATH = "/var/lib/funkwhale/music";
        REVERSE_PROXY_TYPE = "nginx";
        C_FORCE_ROOT = "true";
      };
    };

    funkwhale-worker = {
      command = "${pkgs.writeShellScript "funkwhale-worker-init" ''
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}"
        while [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; do sleep 1; done
        set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
        exec ${pkgs.mypkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp worker --loglevel INFO
      ''}";
      environment = {
        FUNKWHALE_URL = "http://localhost:5000";
        DJANGO_SETTINGS_MODULE = "config.settings.production";
        DJANGO_ALLOWED_HOSTS = "127.0.0.1,localhost,0.0.0.0,127.0.0.1:5000,localhost:5000";
        DATABASE_URL = "postgresql://postgres@postgres:5432/postgres";
        CACHE_URL = "redis://redis:6379/0";
        FUNKWHALE_SPA_HTML_ROOT = "/var/lib/funkwhale/frontend/index.html";
        MEDIA_ROOT = "/var/lib/funkwhale/media";
        MUSIC_DIRECTORY_PATH = "/var/lib/funkwhale/music";
        REVERSE_PROXY_TYPE = "nginx";
        C_FORCE_ROOT = "true";
      };
    };

    funkwhale-beat = {
      command = "${pkgs.writeShellScript "funkwhale-beat-init" ''
        export DATA_DIR="''${DATA_DIR:-/var/lib/funkwhale}"
        while [ ! -f "$DATA_DIR/config/django_secret_key.env" ]; do sleep 1; done
        set -a; source "$DATA_DIR/config/django_secret_key.env"; set +a
        exec ${pkgs.mypkgs.funkwhale-server}/bin/celery --app funkwhale_api.taskapp beat --loglevel INFO
      ''}";
      environment = {
        FUNKWHALE_URL = "http://localhost:5000";
        DJANGO_SETTINGS_MODULE = "config.settings.production";
        DJANGO_ALLOWED_HOSTS = "127.0.0.1,localhost,0.0.0.0,127.0.0.1:5000,localhost:5000";
        DATABASE_URL = "postgresql://postgres@postgres:5432/postgres";
        CACHE_URL = "redis://redis:6379/0";
        FUNKWHALE_SPA_HTML_ROOT = "/var/lib/funkwhale/frontend/index.html";
        MEDIA_ROOT = "/var/lib/funkwhale/media";
        MUSIC_DIRECTORY_PATH = "/var/lib/funkwhale/music";
        REVERSE_PROXY_TYPE = "nginx";
        C_FORCE_ROOT = "true";
      };
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
  };

  services.runtimes.nixos = {
    enable = true;
    nixosConfig = {
      services.postgresql = {
        enable = true;
        enableTCPIP = true;
        authentication = "host all all 0.0.0.0/0 trust";
      };
      services.redis.servers."".enable = true;
      services.nginx = {
        enable = true;
        virtualHosts."localhost" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = 5000;
            }
          ];
          root = "${pkgs.mypkgs.funkwhale-frontend}/";
          locations."/" = {
            tryFiles = "\$uri \$uri/ @backend";
          };
          locations."@backend" = {
            proxyPass = "http://127.0.0.1:5001";
            extraConfig = "proxy_set_header Host \$host;";
          };
          locations."~ ^/(api|federation|auth|.well-known)/" = {
            proxyPass = "http://127.0.0.1:5001";
          };
          locations."/staticfiles/".alias = "/var/lib/funkwhale/static/";
          locations."/media/".alias = "/var/lib/funkwhale/media/";
        };
      };
    };
  };
}
