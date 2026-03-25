{ lib, stdenv }:

stdenv.mkDerivation rec {
  pname = "sandbox-dlopen-stub";
  version = "1.0.0";
  name = "${pname}-${version}";

  src = ./.;

  installPhase = ''
    mkdir -p $out/lib
    install -m 0755 dlopen_stub.so $out/lib
  '';
}
