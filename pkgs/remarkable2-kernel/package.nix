{
  lib,
  fetchFromGitHub,
  linuxKernel,
  lzop,
}:

let
  kernel =
    (linuxKernel.manualConfig rec {
      version = "5.4.70-unstable-2025-10-05";
      modDirVersion = "5.4.70";

      src = fetchFromGitHub {
        owner = "reMarkable";
        repo = "linux";
        rev = "d54fe67bf86e918468b936f97a2ec39f4f87a3d9"; # rm1xx_5.4.70_v1.6.x
        hash = "sha256-MdhbuWK9FlH3CbzkNupcK3kMTO2K/hg9JME8hj4qt6k=";
      };

      configfile = src + "/arch/arm/configs/zero-sugar_defconfig";

      # Can't import-from-derivation and parse the config, so hacking this in.
      # This should trigger isModular, and generate "dev" and "modules" outputs.
      config."CONFIG_MODULES" = "y";

      kernelPatches = [
        {
          name = "fix-binutils-compatibility.patch";
          patch = ./fix-binutils-compatibility.patch;
        }
        {
          name = "fix-gpu-driver-type-mismatch.patch";
          patch = ./fix-gpu-driver-type-mismatch.patch;
        }
      ];
    }).overrideAttrs
      (prev: {
        # Surprise, reMarkable compresses their kernels with LZO.
        nativeBuildInputs = prev.nativeBuildInputs ++ [ lzop ];

        # Can't override the defconfig with structuredConfig or kernelPatches.
        # We are passing configfile which bypasses those wrappers.
        postConfigure = ''
          make "''${makeFlags[@]}" mrproper
          install ${prev.passthru.configfile} $buildRoot/.config
          scripts/config --file $buildRoot/.config \
            --enable CONFIG_NET_CORE \
            --enable CONFIG_CFG80211 \
            --enable CONFIG_MAC80211 \
            --enable CONFIG_BRCMFMAC \
            --enable CONFIG_TUN \
            --enable CONFIG_IKCONFIG \
            --enable CONFIG_IKCONFIG_PROC
          make "''${makeFlags[@]}" oldconfig
        '';
      });
in
lib.recurseIntoAttrs (linuxKernel.packagesFor kernel)

# To `make menuconfig` inside the build sandbox, perform these cursed steps:
# 1. Add `breakpointHook ncurses pkg-config` to nativeBuildInputs
# 2. Add `false` after postConfigure to trigger breakpointHook
# 3. Attach to the sandbox via the logs, that last number is the random sleep seconds, `ps aux` to find it.
# 4. Inside the sandbox, run:
#      export PATH=$(ls -d /nix/store/*pkg-config-0*/bin):$PATH
#      export PKG_CONFIG_PATH=$(ls -d /nix/store/*ncurses*dev*/lib/pkgconfig)
#      make O=build menuconfig
