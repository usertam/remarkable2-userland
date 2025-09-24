{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      remarkable2Packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system: nixpkgs.legacyPackages.${system}.pkgsCross.remarkable2.pkgsStatic
      );

      # The package set I actually want to build in CI.
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        inherit (self.remarkable2Packages.${system}) curl file strace;
      });
    };
}
