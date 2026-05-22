{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "funkwhale-server";
  version = "2.0.2";
  description = "Federated platform for audio streaming, exploration, and publishing.";
  homePage = "https://www.funkwhale.audio/";
  mainProgram = "funkwhale-manage";
  license = lib.licenses.agpl3Only;

  source = {
    url = "https://dev.funkwhale.audio/funkwhale/funkwhale/-/archive/2.0.2/funkwhale-2.0.2.tar.gz";
    hash = "sha256-8Oii3JR/c5GvvYwgZZfc8DEPdlZH2cWV2NcHu0usy40=";
    patches = [
      ./replace-unicode-slugify.patch
      ./fix-root-filesystem-tests.patch
    ];
  };

  build.pythonAppBuilder = {
    enable = true;
    packages = {
      build-system = [
        pkgs.python3Packages.poetry-core
      ];
      dependencies = [
        pkgs.python3Packages.dj-rest-auth
        pkgs.python3Packages.django
        pkgs.python3Packages.django-allauth
        pkgs.python3Packages.django-cache-memoize
        pkgs.python3Packages.django-cacheops
        pkgs.python3Packages.django-cleanup
        pkgs.python3Packages.django-cors-headers
        pkgs.python3Packages.django-debug-toolbar
        pkgs.python3Packages.django-dynamic-preferences
        pkgs.python3Packages.django-environ
        pkgs.python3Packages.django-filter
        pkgs.python3Packages.django-oauth-toolkit
        pkgs.python3Packages.django-redis
        pkgs.python3Packages.django-storages
        pkgs.python3Packages.django-versatileimagefield
        pkgs.python3Packages.djangorestframework
        pkgs.python3Packages.drf-spectacular
        pkgs.python3Packages.markdown
        pkgs.python3Packages.persisting-theory
        pkgs.python3Packages.psycopg2-binary
        pkgs.python3Packages.redis
        pkgs.python3Packages.django-auth-ldap
        pkgs.python3Packages.python-ldap
        pkgs.python3Packages.channels
        pkgs.python3Packages.channels-redis
        pkgs.python3Packages.kombu
        pkgs.python3Packages.celery
        pkgs.python3Packages.uvicorn
        pkgs.python3Packages.aiohttp
        pkgs.python3Packages.arrow
        pkgs.python3Packages.bleach
        pkgs.python3Packages.boto3
        pkgs.python3Packages.click
        pkgs.python3Packages.cryptography
        pkgs.python3Packages.defusedxml
        pkgs.python3Packages.feedparser
        pkgs.python3Packages.httpx
        pkgs.python3Packages.python-ffmpeg
        pkgs.python3Packages.liblistenbrainz
        pkgs.python3Packages.musicbrainzngs
        pkgs.python3Packages.mutagen
        pkgs.python3Packages.pillow
        pkgs.python3Packages.pyld
        pkgs.python3Packages.python-magic
        pkgs.python3Packages.requests
        pkgs.python3Packages.requests-http-message-signatures
        pkgs.python3Packages.sentry-sdk
        pkgs.python3Packages.watchdog
        pkgs.python3Packages.troi
        pkgs.python3Packages.lb-matching-tools
        pkgs.python3Packages.unidecode
        pkgs.python3Packages.pycountry
        pkgs.mypkgs.typesense-python
        pkgs.python3Packages.ipython
        pkgs.python3Packages.pluralizer
        pkgs.python3Packages.service-identity
        pkgs.python3Packages.python-slugify
      ]
      ++ pkgs.python3Packages.channels.optional-dependencies.daphne
      ++ pkgs.python3Packages.uvicorn.optional-dependencies.standard;
    };
    relaxDeps = true;
  };

  build.extraAttrs = {
    postInstall = ''
      mkdir -p $out/bin

      cat > $out/bin/celery <<EOF
      #!/usr/bin/env python
      import sys
      from celery.__main__ import main
      sys.exit(main())
      EOF
      chmod +x $out/bin/celery

      cat > $out/bin/uvicorn <<EOF
      #!/usr/bin/env python
      import sys
      from uvicorn.main import main
      sys.exit(main())
      EOF
      chmod +x $out/bin/uvicorn
    '';

    sourceRoot = "funkwhale-2.0.2/api";

    pythonRemoveDeps = [
      "gunicorn"
    ];

    nativeCheckInputs = [
      pkgs.postgresql
      pkgs.postgresqlTestHook
      pkgs.redisTestHook
      pkgs.python3Packages.pyfakefs
      pkgs.python3Packages.aioresponses
      pkgs.python3Packages.factory-boy
      pkgs.python3Packages.faker
      pkgs.python3Packages.ipdb
      pkgs.python3Packages.pytest
      pkgs.python3Packages.pytest-asyncio
      pkgs.python3Packages.prompt-toolkit
      pkgs.python3Packages.pytest-django
      pkgs.python3Packages.pytest-env
      pkgs.python3Packages.pytest-mock
      pkgs.python3Packages.pytest-randomly
      pkgs.python3Packages.pytest-sugar
      pkgs.python3Packages.requests-mock
      pkgs.python3Packages.django-extensions
    ];

    postgresqlTestUserOptions = "LOGIN SUPERUSER";
    checkPhase = ''
      runHook preCheck

      DATABASE_URL="postgresql:///$PGDATABASE?host=$PGHOST&user=$PGUSER" \
      FUNKWHALE_URL="https://example.com" \
      DJANGO_SETTINGS_MODULE="config.settings.local" \
      CACHE_URL="redis://$REDIS_SOCKET:6379/0" \
      python -m django migrate --no-input

      runHook postCheck
    '';
  };
}
