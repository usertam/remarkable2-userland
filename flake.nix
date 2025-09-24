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

      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: rec {
        remarkable2-userland = nixpkgs.legacyPackages.${system}.runCommand "remarkable2-userland" {
          srcs = with self.remarkable2Packages.${system}; [
            coreutils file findutils util-linux which
            diffutils gnugrep gnused gnupatch jq less
            curl inetutils rsync dig # nmap (liblinear), ndisc6 (perl)
            btop procps lsof strace
            gnutar pigz pixz
            nano tailscale
            (iproute2.override { python3 = null; })
          ];
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
            gnutar pixz
          ];
        } ''
          find $srcs -type f -executable -exec install -Dm555 -t $out/bin {} ';'

          mkdir -p $out/tarball
          time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner \
            --create --directory=$out/bin * | \
            pixz -t > $out/tarball/userland.tar.xz
        '';
      });
    };
}
