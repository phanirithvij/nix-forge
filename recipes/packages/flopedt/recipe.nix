{
  lib,
  pkgs,
  ...
}:
let
  django-colorfield = pkgs.python3Packages.buildPythonPackage rec {
    pname = "django-colorfield";
    version = "0.11.0";
    format = "setuptools";
    src = pkgs.fetchFromGitHub {
      owner = "fabiocaccamo";
      repo = "django-colorfield";
      rev = "0.11.0";
      sha256 = "14gkpriijiqjm0cmm31sc18a4l46mgg5pbwwp9ixsids931g4apy";
    };
  };
  openpyxl-stubs = pkgs.python3Packages.buildPythonPackage rec {
    pname = "openpyxl-stubs";
    version = "0.1.25";
    format = "setuptools";
    src = pkgs.fetchFromGitHub {
      owner = "MartinThoma";
      repo = "openpyxl-stubs";
      rev = "ae41e6fd74d7ca5ea9f263473a26941efb6e87f0";
      sha256 = "0ky71jq033brrlizz9v9czkiyyhdcy21hb757h0xcay41rikaib2";
    };
  };
in
{
  packages.flopedt = {
    version = "0.1.0";
    description = "Collaborative tool for timetable generation and management.";
    homePage = "https://framagit.org/flopedt/FlOpEDT";
    mainProgram = "flopedt";
    license = lib.licenses.agpl3Only;

    source = {
      git = "git:https://framagit.org/flopedt/FlOpEDT.git?rev=1eaf2d6945a1b70ca98ad09dfff4593a4bbbfe27";
      hash = "sha256-E/91cZ0NY8fjqEV+TwgsusXHKFCJ+N2oJorJKFvHd9o=";
    };

    build.pythonAppBuilder = {
      enable = true;
      relaxDeps = true;
      packages = {
        build-system = with pkgs.python3Packages; [ hatchling ];
        dependencies = with pkgs.python3Packages; [
          django
          argon2-cffi
          django-redis
          django-extensions
          django-colorfield
          django-filter
          django-cors-headers
          django-celery-beat
          django-celery-results
          django-recurrence
          django-stubs-ext
          dj-rest-auth
          djangorestframework
          drf-spectacular
          pulp
          psycopg
          asgiref
          channels-redis
          daphne
          channels
          openpyxl
          markdown
          zeep
          tqdm
          pyprof2calltree
          python-dateutil
          celery
          redis
          openpyxl-stubs
        ];
      };
    };
    build.extraAttrs = {
      postUnpack = "sourceRoot=$sourceRoot/back";
      postPatch = ''
        substituteInPlace flop/settings.py \
          --replace-fail 'else Path("/var/flop")' 'else Path(os.environ.get("FLOP_DATA_DIR", "/var/flop"))'
      '';
      postInstall = ''
        # Install manage.py as an executable
        mkdir -p $out/bin
        cp $out/${pkgs.python3.sitePackages}/manage.py $out/bin/flopedt
        chmod +x $out/bin/flopedt

        cat > $out/bin/flopedt-celery <<EOF
        #!/usr/bin/env python3
        import sys
        from celery.__main__ import main

        if __name__ == "__main__":
            sys.exit(main())
        EOF
        chmod +x $out/bin/flopedt-celery

        mkdir -p $out/share/flopedt
        cp -r ${pkgs.flopedt-webapp} $out/share/flopedt/webapp-dist
      '';
    };
  };
}
