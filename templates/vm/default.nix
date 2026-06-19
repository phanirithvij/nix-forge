{
  flake-inputs ? import (fetchTarball {
    url = "https://github.com/fricklerhandwerk/flake-inputs/tarball/4.1.0";
    sha256 = "1j57avx2mqjnhrsgq3xl7ih8v7bdhz1kj3min6364f486ys048bm";
  }),
  flake ? flake-inputs.import-flake { src = ./.; },
  nixpkgs ? flake.inputs.nixpkgs,
  ngi-forge ? flake.inputs.ngi-forge,
  system ? builtins.currentSystem,
}:

let
  systemEval = (
    import "${nixpkgs}/nixos/lib/eval-config.nix" {
      inherit system;
      modules = [ ./configuration.nix ];
      specialArgs = {
        inherit nixpkgs ngi-forge;
      };
    }
  );
in
{
  vm = systemEval.config.system.build.vm;
  system = systemEval.config.virtualisation.vmVariant.system.build.toplevel;
}
