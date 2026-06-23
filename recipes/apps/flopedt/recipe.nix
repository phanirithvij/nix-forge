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
            cd ${pkgs.flopedt}/share/flopedt
            export UV_CACHE_DIR=/tmp/uv-cache
            ${pkgs.uv}/bin/uv run --no-sync python manage.py runserver 0.0.0.0:8000
          '';
          ports = [ "8000:8000" ];
          environment = {
            POSTGRES_HOST = "database";
            POSTGRES_DB = "postgres";
            POSTGRES_USER = "postgres";
            POSTGRES_PASSWORD = "password";
            REDIS_URL = "redis://valkey:6379/0";
          };
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
          components.backend.packages = [
            pkgs.flopedt
            pkgs.uv
          ];
          extraComponents.data.nixosConfig = {
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
            networking.extraHosts = "127.0.0.1 database 127.0.0.1 valkey";
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
      '';
    };
  };
}
