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
    inherit postgresql;
    libxml2 = libxml2-nopython;
    libxslt = libxslt-nopython;
  };

  gemConfig = baseGemConfig // {
    activerecord = attrs: {
      dontBuild = false;
      patchFlags = "-p2";
      patches = [
        # fix rollbacks hanging on interrupt
        # https://github.com/rails/rails/pull/42767
        # ./activerecord-rollback.patch
        # cancel queries if migration is cancelled, this can't be upstreamed
        # since it uses PG specific code in the migration runner.
        ./activerecord-migration-cancel.patch
      ];
    };
    pg = attrs: (baseGemConfig.pg attrs) // {
      # We once carefully removed references to postgres, however that was fixed
      # upstream in nixpkgs. We add an extra safeguard here to make sure we
      # don't include the postgres server in our closure.
      # See https://github.com/NixOS/nixpkgs/pull/237858
      disallowedRequisites = (attrs.disallowedRequisites or []) ++ [ postgresql.out ];
    };
    reline = attrs: {
      dontBuild = false;
      patches = [
        (substituteAll {
          src = ./reline-explicit-curses-path.patch;
          curses_lib = "${lib.getLib ncurses}/lib/libncursesw${stdenv.hostPlatform.extensions.sharedLibrary}";
        })
      ];
    };
    ruby-debug-ide = attrs: {
      dependencies = attrs.dependencies ++ ["debase"];
    };
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
    ffi = attrs: {
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
