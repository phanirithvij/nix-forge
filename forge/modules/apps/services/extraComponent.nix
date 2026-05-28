{
  lib,
  ...
}:
{
  options = {
    nixosConfig = lib.mkOption {
      type = with lib.types; deferredModule;
      default = { };
      description = ''
        NixOS system configuration.
      '';
    };

    ports = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Ports to expose for the extra component (e.g., [ "5432:5432" ]).
      '';
    };
  };
}
