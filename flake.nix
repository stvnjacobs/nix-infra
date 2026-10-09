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
    # PVM kernels and modules. Its nixpkgs must not follow ours: the kernels
    # are built from its own pin.
    nixos-pvm.url = "git+https://tangled.org/jacobs.land/nixos-pvm";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      tangled-core,
      nixos-pvm,
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

      # The spindle's NixOS microVM guest: tangled-core's image config with a
      # PVM guest kernel (and `pti=off nokaslr`), which PVM guests must boot.
      # Uses tangled-core's nixpkgs, like its stock image; the guest kernel
      # comes from nixos-pvm's.
      spindleGuest = tangled-core.inputs.nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          tangled-core.nixosModules.spindle-nixos
          nixos-pvm.nixosModules.guest
          { pvm.guest.enable = true; }
        ];
      };
      spindleImage =
        tangled-core.inputs.nixpkgs.legacyPackages.x86_64-linux.callPackage
          "${tangled-core}/nix/pkgs/spindle-nixos-image.nix"
          { nixosSystem = spindleGuest; };
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

      # spindle (Tangled CI runner, microVM workflows on a PVM host). The PVM
      # host kernel comes from nixos-pvm's nixpkgs.
      nixosConfigurations.spindle = patchedNixosSystem nixpkgs {
        specialArgs = {
          inherit spindleImage;
        };
        modules = [
          ./hosts/spindle/configuration.nix
          tangled-core.nixosModules.spindle
          nixos-pvm.nixosModules.host
        ];
      };

      # Linode base image, built from the generic linode host.
      packages.x86_64-linux.linode-image-gz =
        self.nixosConfigurations.linode.config.system.build.images.linode;

      # The spindle's microVM image (spec.json, kernel, initrd, store disk).
      packages.x86_64-linux.spindle-image = spindleImage;

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
