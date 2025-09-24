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
            curl inetutils iproute2 rsync nmap dig ndisc6
            btop procps lsof strace
            gnutar pigz pixz
            nano tailscale
          ];
        } ''
          find $srcs -type f -executable -exec \
            install -Dm555 -t $out/bin {} ';'
        '';
      });
    };
}
