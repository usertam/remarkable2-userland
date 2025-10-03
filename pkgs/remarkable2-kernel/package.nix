{
  lib,
  fetchFromGitHub,
  linuxKernel,
  lzop,
}:

let
  kernel =
    (linuxKernel.manualConfig rec {
      version = "5.4.70-unstable-2025-01-27";
      modDirVersion = "5.4.70";

      src = fetchFromGitHub {
        owner = "reMarkable";
        repo = "linux";
        rev = "d54fe67bf86e918468b936f97a2ec39f4f87a3d9"; # rm1xx_5.4.70_v1.6.x
        hash = "sha256-MdhbuWK9FlH3CbzkNupcK3kMTO2K/hg9JME8hj4qt6k=";
      };

      configfile = src + "/arch/arm/configs/zero-sugar_defconfig";

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
        nativeBuildInputs = prev.nativeBuildInputs ++ [ lzop ];
      });
in
lib.recurseIntoAttrs (linuxKernel.packagesFor kernel)
