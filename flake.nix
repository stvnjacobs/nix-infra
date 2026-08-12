{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }:
    {
      # laptop
      nixosConfigurations.laptop = nixpkgs.lib.nixosSystem {
        specialArgs = {
          unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
        };
        modules = [
          ./hosts/laptop/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = {
              unstable = nixpkgs-unstable.legacyPackages.x86_64-linux;
            };
          }
        ];
      };

      # linode
      nixosConfigurations.linode = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/linode/configuration.nix ];
      };

      packages.x86_64-linux.linode-image-gz =
        (nixpkgs.lib.nixosSystem {
          modules = [
            ./images/linode/configuration.nix
            "${nixpkgs}/nixos/modules/image/images.nix"
          ];
        }).config.system.build.images.linode;
    };
}
