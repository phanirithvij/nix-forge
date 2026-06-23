{
  pkgs,
  ...
}:

{
  apps.flopedt = {
    displayName = "FlOpEDT";
    description = "Collaborative tool for timetable generation and management.";
    usage = ''
      TBA
    '';

    links = {
      website = "https://flopedt.org";
      docs = "https://flopedt.frama.io/FlOpEDT";
      source = "https://framagit.org/flopedt/FlOpEDT";
    };

    ngi.grants = {
      Commons = [ "FlopEDT" ];
    };

    services = {
      components = {
        backend = {
          command = pkgs.writeShellScriptBin "flopedt-backend" ''
            exec ${pkgs.flopedt}/bin/flopedt runserver 0.0.0.0:8000 --noreload
          '';
          ports = [ "8000:8000" ];
          environment = {
            CELERY_BROKER_URL = "redis://data:6379/0";
            CELERY_RESULT_BACKEND = "redis://data:6379/1";
            POSTGRES_HOST = "data";
            POSTGRES_DB = "postgres";
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "password";
            VALKEY_HOST = "data";
            VALKEY_PORT = "6379";
            FLOP_ENVIRONMENT = "production";
            FLOP_DATA_DIR = "/tmp/flop";
          };
        };

        celery-worker = {
          command = pkgs.writeShellScriptBin "flopedt-celery-worker" ''
            exec ${pkgs.flopedt}/bin/flopedt-celery -A flop worker -l info
          '';
          environment = {
            CELERY_BROKER_URL = "redis://data:6379/0";
            CELERY_RESULT_BACKEND = "redis://data:6379/1";
            POSTGRES_HOST = "data";
            POSTGRES_DB = "postgres";
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "password";
            VALKEY_HOST = "data";
            VALKEY_PORT = "6379";
            FLOP_ENVIRONMENT = "production";
            FLOP_DATA_DIR = "/tmp/flop";
          };
        };

        celery-beat = {
          command = pkgs.writeShellScriptBin "flopedt-celery-beat" ''
            exec ${pkgs.flopedt}/bin/flopedt-celery -A flop beat -l info --scheduler flop.core.celery:CeleryBeatScheduler
          '';
          environment = {
            CELERY_BROKER_URL = "redis://data:6379/0";
            CELERY_RESULT_BACKEND = "redis://data:6379/1";
            POSTGRES_HOST = "data";
            POSTGRES_DB = "postgres";
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "password";
            VALKEY_HOST = "data";
            VALKEY_PORT = "6379";
            FLOP_ENVIRONMENT = "production";
            FLOP_DATA_DIR = "/tmp/flop";
          };
        };

        frontend = {
          command = pkgs.writeShellScriptBin "flopedt-frontend" ''
            cat > /tmp/Caddyfile <<EOF
            :8080 {
              root * ${pkgs.flopedt}/share/flopedt/webapp-dist
              route /api/* {
                reverse_proxy backend:8000
              }
              route /static/* {
                reverse_proxy backend:8000
              }
              route /fr/* {
                reverse_proxy backend:8000
              }
              route /en/* {
                reverse_proxy backend:8000
              }
              route /es/* {
                reverse_proxy backend:8000
              }
              file_server
              try_files {path} /index.html
            }
            EOF
            exec ${pkgs.caddy}/bin/caddy run --config /tmp/Caddyfile
          '';
          ports = [ "8080:8080" ];
          packages = [ pkgs.coreutils ];
        };
      };

      extraComponents = {
        data = {
          nixosConfig = {
            services.postgresql.enable = true;
            services.redis.servers."".enable = true;
            services.redis.servers."".port = 6379;
          };
          ports = [
            "5432:5432"
            "6379:6379"
          ];
        };
      };

      runtimes = {
        container = {
          enable = true;
          components.backend.packages = [ pkgs.flopedt ];
          components.celery-worker.packages = [ pkgs.flopedt ];
          components.celery-beat.packages = [ pkgs.flopedt ];
          components.frontend.packages = [
            pkgs.caddy
            pkgs.flopedt
          ];
          extraComponents.data.nixosConfig = {
            networking.extraHosts = ''
              127.0.0.1 database
              127.0.0.1 valkey
              127.0.0.1 data
            '';
            services.postgresql.enableTCPIP = true;
            services.postgresql.authentication = ''
              local all all trust
              host all all 0.0.0.0/0 trust
              host all all ::0/0 trust
            '';
            services.redis.servers."".bind = "0.0.0.0";
          };
        };

        nixos = {
          enable = true;
          extraComponents.data.nixosConfig = {
            networking.extraHosts = ''
              127.0.0.1 database
              127.0.0.1 valkey
              127.0.0.1 data
            '';
            services.postgresql.authentication = ''
              local all all trust
              host all all 127.0.0.1/32 trust
              host all all ::1/128 trust
            '';
          };
        };
      };
    };

    test.services = {
      script = ''
        curl="curl --retry 5 --retry-max-time 120 --retry-all-errors"
        $curl localhost:8000
        $curl localhost:8080
      '';
    };
  };
}
