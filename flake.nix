{
  description = "NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tangled-core.url = "git+https://tangled.org/tangled.org/core";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      tangled-core,
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

      # knot (Tangled git hosting)
      nixosConfigurations.knot-bootstrap = nixpkgs.lib.nixosSystem {
        modules = [ ./hosts/knot/bootstrap.nix ];
      };

      nixosConfigurations.knot = tangled-core.inputs.nixpkgs.lib.nixosSystem {
        modules = [
          ./hosts/knot/configuration.nix
          tangled-core.nixosModules.knot-rs
        ];
      };

      packages.x86_64-linux.linode-image-gz =
        (nixpkgs.lib.nixosSystem {
          modules = [
            ./images/linode/configuration.nix
            "${nixpkgs}/nixos/modules/image/images.nix"
          ];
        }).config.system.build.images.linode;

      devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
        packages = with nixpkgs.legacyPackages.x86_64-linux; [
          curl
          dnsutils
          github-cli
          jq
          linode-cli
          nixos-rebuild
          openssl
          openssh
        ];
      };
    };
}
