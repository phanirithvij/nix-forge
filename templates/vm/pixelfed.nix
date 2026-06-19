{
  ...
}:
{
  services.pixelfed = {
    enable = true;
    domain = "localhost";
    secretFile = "/etc/nixos/pixelfed-secret";
    nginx = { };
    settings = {
      APP_URL = "http://localhost:8080";
      FORCE_HTTPS_URLS = false;
      SESSION_SECURE_COOKIE = false;
    };
  };
  environment.etc."nixos/pixelfed-secret".text =
    "APP_KEY=base64:XG8o0u+z5rAqyH4Wv2r8P4Q5A/bN7zR1E1G2L3H4J5M=";

  users.users.nginx.group = "nginx";
  users.users.nginx.isSystemUser = true;
  users.groups.nginx = { };

  networking.firewall.allowedTCPPorts = [ 80 ];
  virtualisation.vmVariant.virtualisation = {
    graphics = false;
    diskImage = null;

    forwardPorts = [
      {
        from = "host";
        host.port = 8080;
        guest.port = 80;
      }
    ];
  };
}
