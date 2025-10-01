{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      remarkable2Packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
        system: nixpkgs.legacyPackages.${system}.pkgsCross.remarkable2.pkgsStatic.extend (final: prev: {
          iproute2 = prev.iproute2.override { python3 = null; };
        })
      );

      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        remarkable2-userland = nixpkgs.legacyPackages.${system}.runCommand "remarkable2-userland" rec {
          srcs = nixpkgs.lib.mapAttrsToList (
            name: value:
            self.remarkable2Packages.${system}.${name}
          ) (import ./groups.nix);
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
            gnutar pixz
          ];
        }
        (''
          mkdir -p $out/bin
          install -Dm555 -t $out/bin \
            ${builtins.concatStringsSep " \\\n  " (nixpkgs.lib.mapAttrsToList (
              name: value: let
                wrapIfMany = nixpkgs.lib.optionalString (builtins.length value > 1);
                bins = wrapIfMany "{" + builtins.concatStringsSep "," value + wrapIfMany "}";
              in
                self.remarkable2Packages.${system}.${name} + "/bin/" + bins
            ) (import ./groups.nix))}

          mkdir -p $out/tarball
          cd $out/bin
          time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * .* | \
            pixz -t > $out/tarball/userland.tar.xz
        '');
      });
    };
}
