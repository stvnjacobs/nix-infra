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
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      tangled-core,
      ...
    }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # Patches applied to nixpkgs for server hosts. Drop each once it lands in
      # the pinned nixpkgs.
      serverNixpkgsPatches = [
        # nixos/linode-config: refer to root and swap disks by label
        # https://github.com/NixOS/nixpkgs/pull/416192
        (pkgs.fetchpatch {
          url = "https://github.com/NixOS/nixpkgs/commit/26c89061defdf737f567f30e6f5799f25c6fbca4.patch";
          hash = "sha256-poesO6LBzRvRTY/tHjrXrtdVXfjdzUvr8eFqm/kc5/4=";
        })
      ];

      # Like `input.lib.nixosSystem`, but evaluated from a patched copy of the
      # given nixpkgs input.
      patchedNixosSystem =
        input: args:
        let
          src = pkgs.applyPatches {
            name = "nixpkgs-patched";
            src = input;
            patches = serverNixpkgsPatches;
          };
        in
        import "${src}/nixos/lib/eval-config.nix" (
          args
          // {
            # The input's lib carries its version and revision information.
            inherit (input) lib;
            system = null;
            modules = args.modules ++ [ { nixpkgs.flake.source = src.outPath; } ];
          }
        );
    in
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
      nixosConfigurations.linode = patchedNixosSystem nixpkgs {
        modules = [ ./hosts/linode/configuration.nix ];
      };

      # knot (Tangled git hosting)
      nixosConfigurations.knot = patchedNixosSystem tangled-core.inputs.nixpkgs {
        modules = [
          ./hosts/knot/configuration.nix
          tangled-core.nixosModules.knot-rs
        ];
      };

      # Linode base image, built from the generic linode host.
      packages.x86_64-linux.linode-image-gz =
        self.nixosConfigurations.linode.config.system.build.images.linode;
    };
}
