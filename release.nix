{ system ? builtins.currentSystem
, pkgs ? import ./nix/pinned-nixpkgs.nix { inherit system; } }:

# The names of the attributes in this file are part of this project's
# external interface and should remain stable. CI services like
# Jenkins will have these embedded.

# Let's keep this minimal for now. We only CI the docker image.

let
  inherit (pkgs)
    stdenv lib writeScript writeShellScript writeShellScriptBin;

  eikaiwaPkgs = (import ./default.nix { inherit pkgs; isRelease = true; });

  inherit (eikaiwaPkgs) ociTools;

  accounts = {
    users.deploy = {
      uid = 999;
      group = "deploy";
      home = "/home/deploy";
      shell = "/bin/sh";
    };
    groups.deploy.gid = 999;
  };

  baseLayer = {
    name = "base-layer";
    path = [ pkgs.busybox ];
    entries = ociTools.makeFilesystem {
      inherit accounts;
      hosts = true;
      tmp = true;
      usrBinEnv = "${pkgs.busybox}/bin/env";
      binSh = "${pkgs.busybox}/bin/sh";
    } // {
      "/home/deploy/.irbrc" = {
        type = "file";
        inherit (accounts.users.deploy) uid;
        inherit (accounts.groups.deploy) gid;
        mode = "0755";
        text = ''
          IRB.conf[:USE_AUTOCOMPLETE] = false
        '';
      };
    };
  };

  gemsLayer = {
    name = "gems-layer";
    path = [
      eikaiwaPkgs.bundleProdEnv
      eikaiwaPkgs.ruby
      eikaiwaPkgs.psql
    ] ++ eikaiwaPkgs.runtimeDependencies;
    includes = [
      eikaiwaPkgs.postgresql.lib
      pkgs.cacert
    ];
  };

  appLayer = {
    name = "app-layer";
    entries = {
      "/data/app" = {
        type = "directory";
        sources = [{
          path = eikaiwaPkgs.eikaiwa_content;
        }];
      };
    } // ociTools.makeUserDirectoryEntries accounts "deploy" [
      "/data/app/tmp"
    ];
  };

  testImage = ociTools.makeSimpleImage {
    name = "eikaiwa-content-test";
    layers = [ baseLayer ];
    config = {
      User = "deploy";
      WorkingDir = "/home/deploy";
    };
  };

  waitFor = writeShellScriptBin "waitfor" ''
    set -euo pipefail

    service=$1
    cmd=$2
    retry_times=$3
    retry_wait=$4

    echo "[$service] Waiting for $cmd to succeed"

    count=0
    while [ $count -lt "$retry_times" ]; do
      count=$((count + 1))
      if $cmd; then
        echo "[$service] ready!"
        exit 0
      else
        echo "[$service] not yet ready, will retry in $retry_wait secs"
        sleep "$retry_wait"
      fi
    done

    echo "[$service] Giving up waiting for $cmd"
    exit 1
  '';

  testEntrypoint = writeScript "test.sh" ''
    #!${stdenv.shell}
    set -euo pipefail
    export PATH=${lib.makeBinPath ([
      eikaiwaPkgs.postgresql # for psql for db:setup and pg_isready
      eikaiwaPkgs.bundleEnv.wrappedRuby
      waitFor
      pkgs.curl # checking elasticsearch
      pkgs.coreutils # cp
      pkgs.jq # reload-db
    ] ++ eikaiwaPkgs.runtimeDependencies)}

    export TEST_EAGER_LOAD=true
    export TEST_DISABLE_LOG=true
    export RAILS_ENV=test
    export BOOTSNAP_CACHE_DIR=/tmp/bootsnap

    cd ${eikaiwaPkgs.eikaiwa_content}

    time waitfor "postgres" "pg_isready -h $RAILS_DATABASE_HOST" 60 1
    time bundle exec tools/reload-db -o testdb

    time waitfor "opensearch" "curl -s http://$OPENSEARCH_HOST" 60 1

    # avoid fsync
    curl -XPOST "http://$OPENSEARCH_HOST/_template/all" -H "Content-Type: application/json" -d '{
      "index_patterns": ["*"],
      "settings": {
        "index": {
          "number_of_replicas": 0,
          "translog": {
            "durability": "async",
            "sync_interval": "600s"
          }
        }
      }
    }'

    echo "Running tests"
    time \
      TURBO_TEST_SOCKET_DIR=/tmp \
      RSPEC_JSON_REPORT=true \
      RSPEC_JSON_REPORT_DIR=/tmp/rspec \
      RSPEC_NO_STATUS_PERSISTENCE=true \
      ASYNC_CONTAINER_PROCESSOR_COUNT=4 \
      bundle exec ./scripts/run_turbo_test.rb

    echo "Running pre-deploy checks"
    time bundle exec rspec \
      --format progress \
      --format JsonReportFormatter \
      --no-color \
      --tag deploy \
      --out /tmp/rspec/deploy.json
  '';

  testSanitizeEntrypoint = writeScript "test.sh" ''
    #!${stdenv.shell}
    set -euo pipefail
    export PATH=${lib.makeBinPath [
      eikaiwaPkgs.bundleEnv.wrappedRuby
      eikaiwaPkgs.postgresql # for psql for db:setup and pg_isready
      waitFor
      pkgs.coreutils # sleep
      pkgs.diffutils
    ]}

    export BOOTSNAP_CACHE_DIR=/tmp/bootsnap
    export TEST_DISABLE_LOG=true

    cd ${eikaiwaPkgs.eikaiwa_content}

    time waitfor "postgres" "pg_isready -h $RAILS_DATABASE_HOST" 60 1

    tools/test-sanitize
  '';

  testServiceDeps = {
    postgres = {
      image = "postgres:14.5";
      environment = [
        "POSTGRES_PASSWORD=eikaiwa"
        "POSTGRES_USER=eikaiwa"
        "POSTGRES_DB=eikaiwa_content"
      ];
    };

    opensearch = {
      useHostStore = true;
      image = testImage;
      user = "deploy";
      command = [(writeShellScript "opensearch-command.sh" ''
        export PATH=${lib.makeBinPath (with pkgs; [ bash coreutils nettools ])}:$PATH
        exec ${eikaiwaPkgs.services.start-opensearch}/bin/start-opensearch
      '')];
      environment = [
        "PORT=9200"
        "OPENSEARCH_NETWORK_HOST=_local_,_site_"
      ];
      expose = [
        "9200"
      ];
    };
  };
in
{
  dockerImages.default = {
    production = ociTools.makeSimpleImage {
      name = "eikaiwa-content-production";
      layers = [
        baseLayer
        gemsLayer
        appLayer
      ];

      config = {
        User = "deploy";
        WorkingDir = "/data/app";
        Env = [
          "RAILS_ENV=production"
          "RAILS_LOG_TO_STDOUT=1"
          # Disabled while debugging stability issues.
          # "RUBYOPT=--yjit"
          "BUNDLE_WITHOUT=development:test"
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ];
        Entrypoint = [ "/data/app/entrypoints/start-server" ];
        Cmd = [ "-C" "config/puma.rb" ];
        ExposedPorts = {
          "3000/tcp" = {};
        };
      };
    };
  };

  testConfigurations.default = {
    useHostStore = true;
    image = testImage;
    command = [ testEntrypoint ];
    environment = {
      RAILS_DATABASE_HOST = "postgres";
      OPENSEARCH_HOST = "opensearch:9200";
      OPENSEARCH_TIMEOUT = "60"; # parallel tests can stress opensearch
    };
    outputs = [ "/tmp/rspec" ];
    testResults = [
      {
        type = "json-report";
        name = "Tests - ${builtins.currentSystem}";
        pattern = "rspec/rspec-*.json";
      }
      {
        type = "json-report";
        name = "Pre-Deploy Checks";
        pattern = "rspec/deploy.json";
      }
    ];
    dependencies = {
      inherit (testServiceDeps) opensearch;

      postgres = testServiceDeps.postgres // {
        command = [
          "-c" "fsync=off"
          "-c" "synchronous_commit=off"
          "-c" "full_page_writes=off"
        ];
      };
    };
  };

  testConfigurations.sanitize = {
    runsOn = [ "x86_64-linux" ];
    useHostStore = true;
    image = testImage;
    command = [ testSanitizeEntrypoint ];
    environment = {
      RAILS_DATABASE_HOST = "postgres";
    };
    dependencies = {
      inherit (testServiceDeps) postgres;
    };
  };

  testConfigurations.lint = {
    runsOn = [ "x86_64-linux" ];
    useHostStore = true;
    image = testImage;
    command = [(writeScript "lint.sh" ''
      #!${pkgs.runtimeShell}
      export PATH=${lib.makeBinPath [
        eikaiwaPkgs.bundleEnv
      ]}

      cd ${eikaiwaPkgs.eikaiwa_content}
      rubocop --display-only-fail-level-offenses --fail-level error \
        --format progress --out /tmp/rubocop/rubocop.txt \
        --format progress
    '')];
    outputs = [ "/tmp/rubocop" ];
    testResults = [
      {
        type = "rubocop";
        name = "Rubocop";
        pattern = "rubocop/rubocop.txt";
      }
    ];
  };

  testConfigurations.migrate-all = {
    useHostStore = true;
    image = testImage;
    environment = {
      RAILS_DATABASE_HOST = "postgres";
    };
    command = [(writeScript "migrate-all.sh" ''
      #!${pkgs.runtimeShell}
      set -euo pipefail
      export PATH=${lib.makeBinPath [
        eikaiwaPkgs.bundleEnv
        eikaiwaPkgs.postgresql # for psql for db:setup and pg_isready
        pkgs.coreutils # sleep
        waitFor
      ]}

      cd ${eikaiwaPkgs.eikaiwa_content}

      time waitfor "postgres" "pg_isready -h $RAILS_DATABASE_HOST" 60 1

      # Avoiding attempts to write to the nix store
      # Comparison to the committed schema isn't helpful.
      SCHEMA=/tmp/migrated-schema.sql rails db:create db:migrate
    '')];
    dependencies = {
      inherit (testServiceDeps) postgres;
    };
  };

  testConfigurations.scripts = {
    useHostStore = true;
    image = testImage;
    environment = {
      RAILS_DATABASE_HOST = "postgres";
    };
    command = [(writeScript "migrate-all.sh" ''
      #!${pkgs.runtimeShell}
      set -euo pipefail
      export PATH=${lib.makeBinPath [
        eikaiwaPkgs.bundleEnv
        eikaiwaPkgs.postgresql # for psql for db:setup and pg_isready
        pkgs.coreutils # sleep
        waitFor
      ]}

      cd ${eikaiwaPkgs.eikaiwa_content}

      time waitfor "postgres" "pg_isready -h $RAILS_DATABASE_HOST" 60 1

      rails db:prepare
      rails runner scripts/create_booking.rb
    '')];
    dependencies = {
      inherit (testServiceDeps) postgres;
    };
  };

  packages = eikaiwaPkgs;
}
