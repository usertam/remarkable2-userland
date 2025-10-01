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
          musl-getent = prev.stdenv.mkDerivation {
            pname = "musl-getent";
            version = "1.2.5";
            src = prev.fetchurl {
              url = "https://gitlab.alpinelinux.org/alpine/aports/-/raw/9fa8364d36c83df41af7de6f9d9eddc0b76e42dd/main/musl/getent.c";
              hash = "sha256-phccLbZBzdmcFkFp08XGyjI2F0g87exMu+PrOcWDTfA=";
            };
            buildCommand = ''
              cc $src -o $out/bin/getent
            '';
          };
        })
      );

      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        remarkable2-userland = nixpkgs.legacyPackages.${system}.runCommand "remarkable2-userland" rec {
          srcs = nixpkgs.lib.mapAttrsToList (
            name: value: let
              pkgs = self.remarkable2Packages.${system};
              path = nixpkgs.lib.splitString "." name;
            in
              nixpkgs.lib.getAttrFromPath path pkgs
          ) (import ./groups.nix);
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
            gnutar pixz
          ];
        }
        ''
          mkdir -p $out/bin
          cp -at $out/bin \
            ${builtins.concatStringsSep " \\\n  " (nixpkgs.lib.mapAttrsToList (
              name: value: let
                pkgs = self.remarkable2Packages.${system};
                path = nixpkgs.lib.splitString "." name;
                pkg = nixpkgs.lib.getAttrFromPath path pkgs;
                wrapIfMany = nixpkgs.lib.optionalString (builtins.length value > 1);
                bins = wrapIfMany "{" + builtins.concatStringsSep "," value + wrapIfMany "}";
              in
                pkg + "/bin/" + bins
            ) (import ./groups.nix))}

          # Replace the wrapped tailscaled with a non-wrapped one
          rm -f $out/bin/tailscaled
          mv $out/bin/.tailscaled-wrapped $out/bin/tailscaled

          mkdir -p $out/tarball
          cd $out/bin
          time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * .* | \
            pixz -t > $out/tarball/userland.tar.xz
        '';
      });
    };
}
