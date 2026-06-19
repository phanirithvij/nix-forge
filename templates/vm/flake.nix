{
  description = "Stateless NixOS VM for testing modules and forge services";

  inputs = {
    # Tip: point these to local paths to test local checkouts:
    # nixpkgs.url = "path:/path/to/local/nixpkgs";
    # ngi-forge.url = "path:/path/to/local/ngi-nix-forge";

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    ngi-forge.url = "github:ngi-nix/forge";
  };

  outputs =
    {
      self,
      nixpkgs,
      ngi-forge,
    }:
    {
      nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./configuration.nix
          # Example of adding a forge service (uncomment to use):
          # ngi-forge.packages.x86_64-linux.my-app.nixosModules.default
        ];
        specialArgs = {
          inherit nixpkgs ngi-forge;
        };
      };

      packages.x86_64-linux.default = self.nixosConfigurations.vm.config.system.build.vm;
      packages.x86_64-linux.system =
        self.nixosConfigurations.vm.config.virtualisation.vmVariant.system.build.toplevel;
    };
}
