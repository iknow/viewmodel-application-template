{ system ? builtins.currentSystem
, pkgs ? import ./pinned-nixpkgs.nix { inherit system; }
, isRelease ? false }:

let
  inherit (pkgs) lib stdenv fetchpatch;

  nix-utils = pkgs.fetchFromGitHub {
    owner = "iknow";
    repo = "nix-utils";
    rev = "c0a85a6eac7cf88ca4c6f1ef5261a6f7f5a5f949";
    sha256 = "sha256-WE7sYYQwMq7qCDlcF0noHwHX+sH5TVCv2ORHRDIlFRY=";
  };

  darwinSandbox = import "${nix-utils}/sandbox/darwin" { inherit pkgs; };
in

rec {
  jemalloc450 = pkgs.callPackage ./jemalloc/jemalloc450.nix {};
  bundler = (pkgs.bundler.override { inherit ruby; }).overrideAttrs (attrs: {
    dontBuild = false;
    patchFlags = "-p2";
    patches = (attrs.patches or []) ++ [
      ./bundler-home.patch
    ];
  });
  bundlerEnv = pkgs.bundlerEnv.override { inherit ruby bundler; };
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

  ruby = (pkgs.ruby_4_0.override {
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

  postgresql = pkgs.postgresql_17;
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

    waitfor = pkgs.callPackage ./waitfor.nix {};

  cloudflare-sandbox = pkgs.callPackage ./cloudflare-sandbox.nix {};
  sandbox-dlopen-stub = pkgs.callPackage ./sandbox-dlopen-stub {};
  sandbox-gmtime-stub = pkgs.callPackage ./sandbox-gmtime-stub {};
  sandboxed-ffmpeg = pkgs.callPackage ./sandboxed-ffmpeg.nix { inherit cloudflare-sandbox sandbox-dlopen-stub sandbox-gmtime-stub; };

  sandbox = package: options:
    let
      options' = options // {
        profile = options.profile or ./sandbox-profiles/backend.sb;
        sourceRoot = ./..;
      };
    in
      if stdenv.isDarwin then
        darwinSandbox package options'
      else
        package;

}
