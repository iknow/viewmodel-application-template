{ stdenv, lib, fetchFromGitHub, libseccomp }:

let
  libseccomp-static = libseccomp.overrideAttrs(attrs: {
    configureFlags = (attrs.configureFlags or []) ++ ["--enable-shared=no"];
  });
in
stdenv.mkDerivation {
  name = "cloudflare-sandbox";

  buildInputs = [libseccomp-static];

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "sandbox";
    rev = "777a6203b96453eea2d496ccdc9c2dfda7f411b1";
    sha256 = "sha256-H8F17XGpYO4wMBxbYpgAOWzHwLlbiNoiMr/68fs/55w=";
  };

  # Makefile expects to find a vendored static libseccomp
  preBuild = ''
    mkdir -p libseccomp/src
    ln -s ${libseccomp-static.dev}/include libseccomp
    ln -s ${libseccomp-static.lib}/lib libseccomp/src/.libs
  '';

  installPhase = ''
    mkdir -p $out/bin $out/lib
    install -m 755 sandboxify $out/bin
    install -m 755 libsandbox.so $out/lib
  '';

  meta = {
    platforms = lib.platforms.linux;
  };
}
