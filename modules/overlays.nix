{ inputs, ... }:
{
  nixpkgs.overlays = [
    (
      final: _:
      let
        importNixpkgs =
          input:
          import input {
            inherit (final.stdenv.hostPlatform) system;
            inherit (final) config;
          };
      in
      {
        flakes = {
          inherit (inputs.tg.packages.${final.stdenv.hostPlatform.system}) tg tgmcp;
        };

        unstable = importNixpkgs inputs.nixpkgs-unstable;

        # Packages held at an older rev because their current channel build is
        # broken. Each entry has a TODO and upstream issue in flake.nix.
        pinned = {
          inherit (importNixpkgs inputs.nixpkgs-unstable-prev-xan) xan;
        };
      }
    )
  ];
}
