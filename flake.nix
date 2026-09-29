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
    # PVM kernel source, pinned to a pvm-612 commit because pkgs/pvm-kernel.nix
    # hard-codes its version and configs. Update them together.
    pvm-linux = {
      url = "github:virt-pvm/linux/58902213f660d7f8d75eb9f08e6c3ff7e4a3721d";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      tangled-core,
      pvm-linux,
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

      # linode (generic base for Linode hosts; see linode-image-gz)
      nixosConfigurations.linode = patchedNixosSystem nixpkgs {
        modules = [ ./hosts/linode/configuration.nix ];
      };

      # linode-pvm (PVM nested virtualization test host)
      nixosConfigurations.linode-pvm = patchedNixosSystem nixpkgs {
        specialArgs = {
          inherit pvm-linux;
        };
        modules = [ ./hosts/linode-pvm/configuration.nix ];
      };

      # knot bootstrap (initial deployment before the full knot config)
      nixosConfigurations.knot-bootstrap = patchedNixosSystem nixpkgs {
        modules = [ ./hosts/knot/bootstrap.nix ];
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

      # The kernel linode-pvm boots.
      packages.x86_64-linux.pvm-host-kernel =
        self.nixosConfigurations.linode-pvm.config.boot.kernelPackages.kernel;

      # PVM-aware guest kernel for QEMU microvm guests on linode-pvm.
      packages.x86_64-linux.pvm-guest-kernel =
        (pkgs.callPackage ./pkgs/pvm-kernel.nix { pvm-src = pvm-linux; }).guest.kernel;

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
