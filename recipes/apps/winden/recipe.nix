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

      # Reuse mailbox component from the magic-wormhole app recipe
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

    test.services = {
      packages = [
        (pkgs.python3.withPackages (ps: [ ps.selenium ]))
        pkgs.chromium
        pkgs.chromedriver
      ];
      script = ''
        # First ensure Caddy is responding
        curl --retry 10 --retry-max-time 120 --retry-all-errors http://localhost:8080 | grep -q "Winden"

        # Now run a headless browser test to verify that the JS and WASM bundle loads
        # without any errors in the browser console
        python3 - << 'EOF'
        import time
        import sys
        from selenium import webdriver
        from selenium.webdriver.chrome.options import Options
        from selenium.webdriver.chrome.service import Service

        options = Options()
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-gpu")
        options.set_capability("goog:loggingPrefs", {"browser": "ALL"})

        service = Service()
        driver = webdriver.Chrome(service=service, options=options)

        try:
            print("Loading http://localhost:8080 in Headless Chromium...")
            driver.get("http://localhost:8080")
            time.sleep(5)

            logs = driver.get_log("browser")
            errors = []
            for log in logs:
                print("BROWSER LOG:", log)
                if log["level"] == "SEVERE":
                    # Ignore favicon 404 and React 18 render deprecation warning
                    msg = log.get("message", "")
                    if "favicon" not in msg and "ReactDOM.render is no longer supported" not in msg:
                        errors.append(msg)

            if errors:
                print("SEVERE browser console errors detected:", errors)
                sys.exit(1)

            body = driver.find_element("tag name", "body").text
            print("Page body excerpt:", body[:200])
            if not body.strip():
                print("ERROR: Winden UI rendered empty body!")
                sys.exit(1)

            print("Winden UI loaded successfully with NO browser console errors!")
        finally:
            driver.quit()
        EOF
      '';
    };
  };
}
