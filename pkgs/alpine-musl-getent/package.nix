{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "alpine-musl-getent";
  version = "1.2.5";

  src = fetchurl {
    url = "https://gitlab.alpinelinux.org/alpine/aports/-/raw/9fa8364d36c83df41af7de6f9d9eddc0b76e42dd/main/musl/getent.c";
    hash = "sha256-phccLbZBzdmcFkFp08XGyjI2F0g87exMu+PrOcWDTfA=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    $CC $src -o $out/bin/getent

    runHook postInstall
  '';
}
