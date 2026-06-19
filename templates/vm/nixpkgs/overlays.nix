[
  (final: prev: {
    # A script to switch to a new system within the VM
    vm-switch = final.writeShellScriptBin "vm-switch" ''
      set -xe
      nix-build -A system -o system /etc/nixos "$@"
      exec sudo system/bin/switch-to-configuration test
    '';
  })
]
