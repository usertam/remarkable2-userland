{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
        remarkable2.hostPkgs = nixpkgs.legacyPackages.${system}.pkgsCross.remarkable2.pkgsStatic.extend (
          final: prev: {
            iproute2 = prev.iproute2.override { python3 = null; };
            alpine-musl-getent = prev.callPackage ./pkgs/alpine-musl-getent/package.nix { };
          }
        );

        remarkable2.drvMap = nixpkgs.lib.mapAttrs' (
          drvName: binList:
          let
            # Process names with dots in them, e.g. "util-linux.mount" -> pkgs.util-linux.mount
            inherit (self.packages.${system}.remarkable2) hostPkgs;
            path = nixpkgs.lib.splitString "." drvName;
            drv = nixpkgs.lib.getAttrFromPath path hostPkgs;
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
              nativeBuildInputs = with nixpkgs.legacyPackages.${system}; [
                gnutar
                pixz
              ];
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

              mkdir -p $out/tarball
              cd $out
              time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c bin | \
                pixz -t > $out/tarball/bin.tar.xz
            '';

        remarkable2.userland-build-binary-cache =
          (nixpkgs.legacyPackages.${system}.mkBinaryCache {
            name = "remarkable2-userland-build-binary-cache";
            rootPaths = [ self.packages.${system}.remarkable2.userland.drvPath ];
          }).overrideAttrs
            (prev: {
              nativeBuildInputs =
                with nixpkgs.legacyPackages.${system};
                prev.nativeBuildInputs
                ++ [
                  gnutar
                  pixz
                ];
              buildCommand = prev.buildCommand + ''
                mkdir -p $out/tarball
                cd $out
                time tar --sort=name --mtime='@1' --owner=0 --group=0 --numeric-owner -c $(ls --ignore=tarball) | \
                  pixz -t > $out/tarball/archive.tar.xz
              '';
            });
      });
    };
}
