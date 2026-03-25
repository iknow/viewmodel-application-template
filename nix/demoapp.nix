{ stdenv
, lib
, callPackage
, substituteAll
, file
, makeWrapper
, runCommand
, removeReferencesTo
, writeScript
, writeShellScriptBin
, symlinkJoin
, bundlerEnv
, ruby
, bundler
, defaultGemConfig
, cacert
, postgresql
, libidn
, zlib
, libiconv
, libxml2
, libxslt
, pcre
, pkg-config
, fetchpatch
, shared-mime-info
, targetPackages
, ncurses
, rustPlatform
, rustc
, cargo
, fetchurl
}:

let
  libxml2-nopython = libxml2.override {
    pythonSupport = false;
  };

  libxslt-nopython = libxslt.override {
    libxml2 = libxml2-nopython;
    pythonSupport = false;
  };

  baseGemConfig = defaultGemConfig.override {
    libxml2 = libxml2-nopython;
    libxslt = libxslt-nopython;
  };

  gemConfig = baseGemConfig // {
    idn-ruby = attrs: {
      dontBuild = false;
      buildFlags = [
        "--with-idn-lib=${lib.getLib libidn}/lib"
        "--with-idn-include=${lib.getDev libidn}/include"
      ];
    };
    activerecord = attrs: {
      dontBuild = false;
      patchFlags = "-p2";
      patches = [
        # cancel queries if migration is cancelled, this can't be upstreamed
        # since it uses PG specific code in the migration runner.
        ./activerecord-migration-cancel.patch
      ];
    };

    irb = attrs: {
      dontBuild = false;
      patches = [
        # Fix sandboxed history persistence
        ./irb-history.patch
      ];
    };

    pg = attrs: (baseGemConfig.pg attrs) // {
      # We once carefully removed references to postgres, however that was fixed
      # upstream in nixpkgs. We add an extra safeguard here to make sure we
      # don't include the postgres server in our closure.
      # See https://github.com/NixOS/nixpkgs/pull/237858
      disallowedRequisites = (attrs.disallowedRequisites or []) ++ [ postgresql.out ];
    };

    ruby-debug-ide = attrs: {
      dependencies = attrs.dependencies ++ ["debase"];
    };

    ruby-filemagic = attrs: {
      buildFlags = [
        "--with-magic-lib=${lib.getLib file}/lib"
        "--with-magic-include=${lib.getDev file}/include"
        "--with-gnurx-lib=${lib.getLib file}/lib"
        "--with-gnurx-include=${lib.getDev file}/include"
      ];
    };

    ruby_speech = attrs: {
      nativeBuildInputs = [ pkg-config ];
      buildInputs = [ pcre ];
    };

    mimemagic = attrs: {
      FREEDESKTOP_MIME_TYPES_PATH = "${shared-mime-info}/share/mime/packages/freedesktop.org.xml";
    };

    # TODO upstream
    nokogiri = attrs: {
      nativeBuildInputs = [ pkg-config ];
      buildInputs = [
        zlib
        libxml2-nopython
        libxslt-nopython
      ] ++ lib.optionals stdenv.isDarwin [ libiconv ];
      buildFlags = [
        "--use-system-libraries"
      ];
    };

    suo = attrs: {
      dontBuild = false;
      patches = (attrs.patches or []) ++ [
        (fetchpatch {
          # https://github.com/nickelser/suo/pull/21
          url = "https://github.com/nickelser/suo/commit/6fa25dd573ed0cc49acb81b4d25fff6bd4fd0c2f.patch";
          sha256 = "sha256-54ftGXNd7OCs6vleoXWbTwZwH6sAWvVhHJt0eL/jMvM=";
        })
      ];
    };

    tiktoken_ruby = attrs: rec {
      dontBuild = false;

      nativeBuildInputs = [
        ruby
        rustc
        cargo
        rustPlatform.cargoSetupHook
        rustPlatform.bindgenHook
        removeReferencesTo
      ];

      buildInputs = lib.optionals stdenv.isDarwin [ libiconv ];

      # src is extracted from buildRubyGem so that they can be
      # referenced from the fetchCargoTarball, since otherwise they'd be
      # unavailable to it.
      src = fetchurl {
        urls = ["https://rubygems.org/gems/${attrs.gemName}-${attrs.version}.gem"];
        inherit (attrs.source) sha256;
      };

      # Needed so bindgen can find libclang.so
      LIBCLANG_PATH = "${lib.getLib rustc.llvmPackages.libclang}/lib";

      # gem install presumably builds the native component outside of $NIX_BUILD_TOP
      # Make sure the cargo config for the vendor directory propagates.
      preInstall = ''
        export CARGO_HOME=$NIX_BUILD_TOP/.cargo
      '';

      cargoDeps = let
          cargo_lockFile = runCommand "${attrs.gemName}-Cargo.lock" {
            nativeBuildInputs = [ ruby ];
          } ''
            gem unpack "${src}" --target container
            mv container/*/Cargo.lock $out
          '';
      in rustPlatform.importCargoLock {
        lockFile = cargo_lockFile;
        allowBuiltinFetchGit = true;
      };

      postInstall = ''
        grep -lR ${rustc.unwrapped} $out | xargs remove-references-to -t ${rustc.unwrapped}
      '';

      disallowedRequisites = [ rustc rustc.unwrapped ];
    };

    ffi = attrs: (baseGemConfig.ffi attrs) // {
      postInstall = ''
        find $out -iname libtool -delete
        find $out -iname config.log -delete
        find $out -iname config.status -delete
      '';

      disallowedReferences = with targetPackages.stdenv; [
        cc
        cc.cc
        cc.bintools
        cc.bintools.bintools
      ];
    };

    net-http2 = attrs: {
      dontBuild = false;
      patches = (attrs.patches or []) ++ [
        ./net-http2-safety-and-errors.patch
      ];
    };

    devise = attrs: {
      dontBuild = false;
      patches = (attrs.patches or []) ++ [
        # Tests fail due to routes being lazy loaded
        # See https://github.com/heartcombo/devise/issues/5794
        (fetchpatch {
          url = "https://github.com/heartcombo/devise/commit/24c47140e5d2e484b49796c934a8c1efb2a434b5.patch";
          excludes = [ "CHANGELOG.md" ];
          sha256 = "sha256-6460aBkYlgkD9l3M6n8nf80uzM3j1jLK0Xv2ficPvCk=";
        })
      ];
    };

    annotate = attrs: {
      dontBuild = false;
      patches = (attrs.patches or []) ++ [
        ./annotate-comments.patch
      ];
    };
  };

  bundleEnv = bundlerEnv {
    name = "demoapp-bundler-env";
    inherit ruby bundler gemConfig;
    groups = [ "default" "development" "test" ];
    gemfile  = ../Gemfile;
    lockfile = ../Gemfile.lock;
    gemset   = ../gemset.nix;
  };

  bundleProdEnv = bundlerEnv {
    name = "demoapp-bundler-prod-env";
    inherit ruby bundler;
    gemConfig = gemConfig // {
      # This is a dependency of ddtrace but it only uses it for building the
      # extension on ruby < 2.6. This is 20+MB of ruby headers so it's nice to
      # keep out of the image.
      debase-ruby_core_source = attrs: {
        postInstall = ''
          find $out -name ruby_core_source -type d | xargs rm -r
        '';
      };
    };
    groups = [ "default" ];
    gemfile  = ../Gemfile;
    lockfile = ../Gemfile.lock;
    gemset   = ../gemset.nix;
  };

  runtimeDependencies = [];

  fileRegex = path: "^${path}$";
  folderRegex = path: [ "^${path}$" "^${path}/.*$" ];

  scripts = {
    start-server = ''
      if [ "''${RAILS_ENV:-}" = "development" ]; then
        exec bundle exec rails server -b '[::]' "$@"
      else
        exec bundle exec puma "$@"
      fi
    '';

    db-migrate = ''
      bundle exec rails db:migrate
      bundle exec rails custom:data:migrate
    '';
  };

  installScript = name: text:
    let
      script = writeScript name ''
        #!${stdenv.shell}
        set -euo pipefail

        ${text}
      '';
    in ''
      cp ${script} $out/entrypoints/${name}
    '';

  installScripts = lib.concatStringsSep "\n" (lib.mapAttrsToList installScript scripts);

  demoapp = stdenv.mkDerivation {
    name    = "demoapp";
    version = "0.0.1";

    nativeBuildInputs = [makeWrapper];

    src = lib.sourceByRegex ../. (
      (builtins.concatMap folderRegex [
        "app"
        "bin"
        "config"
        "data"
        "db"
        "lib"
        "public"
        "scripts"
        "spec"
        "tools"
        "vendor"
      ])
      ++
      (map fileRegex [
        "config.ru"
        "Gemfile"
        "Gemfile.lock"
        "Rakefile"
        ".rspec"
        ".rubocop.yml"
        "turbo_test.rb"
      ])
    );

    installPhase = ''
      cp -r ./ $out

      for i in $(find $out/config -name '*.stub'); do
        mv $i ''${i%.stub}
      done

      mkdir -p $out/entrypoints

      ${installScripts}
    '';

    disallowedRequisites = [ postgresql ];
  };
in
{
  inherit bundleEnv bundleProdEnv demoapp runtimeDependencies;
}
