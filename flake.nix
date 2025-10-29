{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        remarkable2.pkgs = nixpkgs.legacyPackages.${system}.pkgsCross.remarkable2.pkgsStatic.extend (
          final: prev: {
            iproute2 = prev.iproute2.override { python3 = null; };
            socat = prev.socat.overrideAttrs (prev: { hardeningEnable = [ ]; });
            linuxPackages = prev.callPackage ./pkgs/remarkable2-kernel/package.nix { };
            alpine-musl-getent = prev.callPackage ./pkgs/alpine-musl-getent/package.nix { };
          }
        );

        remarkable2.drvMap = nixpkgs.lib.mapAttrs' (
          drvName: binList:
          let
            # Process names with dots in them, e.g. "util-linux.mount" -> pkgs.util-linux.mount
            inherit (self.packages.${system}.remarkable2) pkgs;
            path = nixpkgs.lib.splitString "." drvName;
            drv = nixpkgs.lib.getAttrFromPath path pkgs;
            # Format the binary list in bash brace expansion format.
            wrapIfMulti = nixpkgs.lib.optionalString (builtins.length binList > 1);
            drvBins = (wrapIfMulti "{") + (builtins.concatStringsSep "," binList) + (wrapIfMulti "}");
          in
          nixpkgs.lib.nameValuePair drvName {
            inherit drv drvBins;
          }
        ) (import ./groups.nix);

        remarkable2.userland =
          nixpkgs.legacyPackages.${system}.runCommand "remarkable2-userland"
            {
              srcs = nixpkgs.lib.mapAttrsToList (_: v: v.drv) self.packages.${system}.remarkable2.drvMap;
            }
            ''
              mkdir -p $out/bin
              cp -at $out/bin \
                ${nixpkgs.lib.concatMapAttrsStringSep " \\\n  " (
                  _: v: "${v.drv}/bin/${v.drvBins}"
                ) self.packages.${system}.remarkable2.drvMap}

              # Replace the wrapped tailscaled with a non-wrapped one
              rm -f $out/bin/tailscaled
              mv $out/bin/.tailscaled-wrapped $out/bin/tailscaled
            '';

        remarkable2.userland-archive =
          nixpkgs.legacyPackages.${system}.runCommand "remarkable2-userland-archive"
            {
              src = self.packages.${system}.remarkable2.userland;
              nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
                gnutar
                pixz
              ];
            }
            ''
              mkdir -p $out/tarball
              time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c $src | \
                pixz -9 > $out/tarball/userland-archive.tar.xz
            '';

        remarkable2.kernel-archive =
          nixpkgs.legacyPackages.${system}.runCommand "remarkable2-kernel-archive"
            {
              srcs = with self.packages.${system}.remarkable2.pkgs; [
                linuxPackages.kernel
                linuxPackages.kernel.dev
                linuxPackages.kernel.modules
              ];
              nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
                gnutar
                pixz
              ];
            }
            ''
              mkdir -p $out/tarball
              time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c $srcs | \
                pixz -9 > $out/tarball/kernel-archive.tar.xz
            '';
      });
    };
}
