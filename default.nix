{
  flake-inputs ? import (fetchTarball {
    url = "https://github.com/fricklerhandwerk/flake-inputs/tarball/4.1.0";
    sha256 = "1j57avx2mqjnhrsgq3xl7ih8v7bdhz1kj3min6364f486ys048bm";
  }),
  flake ? flake-inputs.import-flake { src = ./.; },
  inputs ? flake.inputs,
  system ? builtins.currentSystem,
  pkgs ? import inputs.nixpkgs {
    config = { };
    overlays = [ ];
    inherit system;
  },
  lib ? import "${inputs.nixpkgs}/lib",
}:
let
  default = lib.makeScope pkgs.newScope (def: {
    inherit
      lib
      flake
      system
      inputs
      default # recurse scope
      ;

    nimi-def = import inputs.nimi-def { inherit pkgs; };
    nimi = def.nimi-def.nimi;
    nimiLib = def.nimi.passthru;

    # requires debug to be enabled in flake
    debug = flake.outputs.allSystems.${system};

    inherit (default.debug) forge;

    # derivations
    apps = builtins.removeAttrs (flake.outputs.packages.${system}.apps or { }) [
      "type"
      "name"
      "system"
    ];
    pkgs = builtins.removeAttrs (flake.outputs.packages.${system}.pkgs or { }) [
      "type"
      "name"
      "system"
    ];
    shells = flake.outputs.devShells.${system};
  });
in
default
