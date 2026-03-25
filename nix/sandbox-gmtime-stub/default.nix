{ lib, stdenv }:

stdenv.mkDerivation rec {
  pname = "sandbox-gmtime-stub";
  version = "1.0.0";
  name = "${pname}-${version}";

  src = ./.;

  installPhase = ''
    mkdir -p $out/lib
    install -m 0755 gmtime_stub.so $out/lib
  '';
}
