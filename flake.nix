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
            curl inetutils rsync # nmap (liblinear), ndisc6 (perl), dig (bind)
            btop procps lsof strace
            gnutar pigz # (pixz.override { asciidoc = null; }) (https://github.com/vasi/pixz/issues/67)
            nano (tailscale.override { iproute2 = iproute2.override { python3 = null; }; })
            (iproute2.override { python3 = null; })
          ];
          nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
            gnutar pixz
          ];
        } ''
          mkdir -p $out/bin
          find $srcs -type f -executable -exec cp -n {} $out/bin \;

          mkdir -p $out/tarball
          cd $out/bin
          time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c * | \
            pixz -t > $out/tarball/userland.tar.xz
        '';
      });
    };
}
