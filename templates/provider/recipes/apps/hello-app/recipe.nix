{
  config,
  lib,
  pkgs,
  ...
}:

{
  name = "hello-app";
  description = "Say hello to Nix.";

  programs = {
    packages = [
      pkgs.mypkgs.hello-nix
    ];

    runtimes.shell = {
      enable = true;
    };
  };
}
