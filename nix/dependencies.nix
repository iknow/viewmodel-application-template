{ system ? builtins.currentSystem
, pkgs ? import ./pinned-nixpkgs.nix { inherit system; }
, isRelease ? false }:

let
  inherit (pkgs) lib stdenv fetchpatch;
  nix-utils = pkgs.fetchFromGitHub {
    owner = "iknow";
    repo = "nix-utils";
    rev = "c13c7a23836c8705452f051d19fc4dff05533b53";
    sha256 = "0ax7hld5jf132ksdasp80z34dlv75ir0ringzjs15mimrkw8zcac";
  };
in

rec {
  jemalloc450 = pkgs.callPackage ./jemalloc/jemalloc450.nix {};
  bundler = pkgs.bundler.override { inherit ruby; };
  bundix = (pkgs.bundix.override {
    inherit bundler;
  }).overrideAttrs (attrs: {
    patches = (attrs.patches or []) ++ [
      # https://github.com/nix-community/bundix/pull/85
      (fetchpatch {
        url = "https://github.com/nix-community/bundix/commit/ae63f23d176122f239d0e27498e231ba2f48616f.patch";
        sha256 = "1kw66c5ncjvd8kyq2f1d5v54aq5h2hp0zr8kfbml3b92icsqyxvp";
      })
      (fetchpatch {
        url = "https://github.com/nix-community/bundix/commit/cf19a8a2d5f5049e0fb02578c5e00f0d84cd1803.patch";
        sha256 = "sha256-G4Fu1jPiCDPwi969PzHZcY+vjb50KG09DpBjsMjamS0=";
      })
    ];
  });

  ruby = (pkgs.ruby_3_2.override {
    inherit bundler bundix;
    jemalloc = jemalloc450;
    jemallocSupport = isRelease;
  }).overrideAttrs(attrs: lib.optionalAttrs isRelease {
    # Upstream ruby defaults to jit enabled, which implies both mjit and yjit.
    # We are only interested in using yjit, so remove the relatively heavy cc
    # dependency.
    postInstall = attrs.postInstall + ''
      # Get rid of the CC runtime dependency
      ${pkgs.removeReferencesTo}/bin/remove-references-to \
        -t ${pkgs.stdenv.cc} \
        $out/lib/libruby*
      ${pkgs.removeReferencesTo}/bin/remove-references-to \
        -t ${pkgs.stdenv.cc} \
        $rbConfig
      sed -i '/CC_VERSION_MESSAGE/d' $rbConfig
  '';

    disallowedRequisites = attrs.disallowedRequisites ++ [ stdenv.cc.cc ];
  });

  postgresql = pkgs.postgresql_14;
  opensearch = pkgs.opensearch;

  psql = stdenv.mkDerivation {
    pname = "psql";
    version = postgresql.version;

    nativeBuildInputs = [ pkgs.removeReferencesTo ];

    unpackPhase = ":";

    buildPhase = ''
      cp ${postgresql}/bin/psql psql
      remove-references-to -t ${postgresql} psql
    '';

    checkPhase = ''
      ./psql --version
    '';

    installPhase = ''
      mkdir -p $out/bin
      mv psql $out/bin/psql
    '';

    doCheck = true;

    disallowedRequisites = [ postgresql ];
  };

  ociTools = pkgs.callPackage "${nix-utils}/oci" {};
}
