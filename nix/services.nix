{ postgresql, opensearch, memcached, redis,
  buildEnv, coreutils, jq, gnused, writeShellScriptBin, writeText, writeTextFile, runtimeShell, lib }:

let
  envOr = var: default:
    let
      value = builtins.getEnv var;
    in if value != "" then value else default;

  esHome = envOr "ES_HOME" "$PWD/tmp/opensearch-${opensearch.version}";
  pgHome = envOr "PG_HOME" "$PWD/tmp/postgresql-${lib.versions.major postgresql.version}";
  redisHome = "$PWD/tmp/redis";

  esJavaSecurityPolicy = writeTextFile {
    name="es-security-policy";
    text=''
      grant {
      permission java.io.FilePermission "${builtins.storeDir}/-", "read";
      };
    '';
  };

  setupConfig = serviceName: bindings:
    let
      envFile = "tmp/${serviceName}-config.json";
      envFileTmp = "${envFile}.tmp";
    in
    ''
      cleanup() {
        rm -f "${envFile}" "${envFileTmp}"
      }
      trap cleanup EXIT

      generateConfig() {
        ${jq}/bin/jq -n '$ARGS.named' \
        ${lib.concatStringsSep " \\\n" (lib.mapAttrsToList (exportName: expr:
          ''--arg '${exportName}' "${expr}"''
        ) bindings)}
      }

      mkdir -p "$(dirname "${envFile}")"
      generateConfig > "${envFileTmp}"
      mv -f "${envFileTmp}" "${envFile}"
    '';

  start-opensearch = writeShellScriptBin "start-opensearch" ''
    #!${runtimeShell} -e

    PORT="''${PORT:-9200}"

    network_host=''${OPENSEARCH_NETWORK_HOST:-_local_}
    export OPENSEARCH_HOME=${esHome}
    export OPENSEARCH_JAVA_OPTS="-Xms512m -Xmx512m -Djava.security.policy=${esJavaSecurityPolicy}"

    mkdir -p $OPENSEARCH_HOME

    ${coreutils}/bin/ln -sfT ${opensearch}/lib     $OPENSEARCH_HOME/lib
    ${coreutils}/bin/ln -sfT ${opensearch}/modules $OPENSEARCH_HOME/modules

    mkdir -p $OPENSEARCH_HOME/logs

    mkdir -p $OPENSEARCH_HOME/config
    mkdir -p $OPENSEARCH_HOME/config/scripts

    ${coreutils}/bin/ln -sfT ${opensearch}/config/jvm.options $OPENSEARCH_HOME/config/jvm.options

    cat <<OPENSEARCH_CONFIG > $OPENSEARCH_HOME/config/opensearch.yml
    network.host: $network_host
    discovery.type: single-node
    http.port: $PORT
    transport.tcp.port: $((PORT + 1))
    cluster.name: demoapp-nix
    cluster.routing.allocation.disk.threshold_enabled: false
    OPENSEARCH_CONFIG

    ${coreutils}/bin/install -m 0644 \
      ${opensearch}/config/log4j2.properties $OPENSEARCH_HOME/config

    # Configure Rails
    ${setupConfig "opensearch" {
      OPENSEARCH_HOST = "localhost:$PORT";
    }}

    # Start opensearch
    exec ${opensearch}/bin/opensearch
  '';

  postgresqlConfig = writeTextFile {
    name = "postgresql.conf";
    text = ''
      log_destination = 'stderr'
      autovacuum = off

      # Restore the default configuration for psql on nixpkgs on linux. Nixpkgs
      # defaults to /run/postgresql on linux, which is not writable by the
      # default user. In our use case, it makes more sense to use /tmp. Linux
      # users will have to configure psql to find this directory, but it's
      # better than not binding at all.
      unix_socket_directories = '/tmp'
      fsync = off
      synchronous_commit = off
      full_page_writes = off
    '';
  };

  start-postgresql = writeShellScriptBin "start-postgresql" ''
    #!${runtimeShell} -e

    PORT="''${PORT:-5432}"

    mkdir -p ${pgHome}

    # Initialise the database.
    if ! test -e ${pgHome}/PG_VERSION; then
      ${postgresql}/bin/initdb -U rails -D ${pgHome} -E utf-8 --no-locale
    fi

    ln -fs ${postgresqlConfig} ${pgHome}/postgresql.conf

    # Configure Rails
    ${setupConfig "database" {
      RAILS_DATABASE_HOST = "127.0.0.1"; # avoid socket
      RAILS_DATABASE_PORT = "$PORT";
    }}

    exec ${postgresql}/bin/postgres -D ${pgHome} -i -p $PORT
  '';

  start-memcached = writeShellScriptBin "start-memcached" ''
    #!${runtimeShell} -e
    PORT="''${PORT:-11211}"

    # Configure Rails
    ${setupConfig "memcached" {
      MEMCACHED_SERVERS = ''[\"localhost:$PORT\"]'';
    }}

    exec ${memcached}/bin/memcached -p $PORT
  '';

  start-redis = writeShellScriptBin "start-redis" ''
    #!${runtimeShell} -e
    PORT="''${PORT:-6379}"

    # Configure iknow
    ${setupConfig "redis" {
      REDIS_URL = "redis://127.0.0.1:$PORT";
    }}

    mkdir -p ${redisHome}
    exec ${redis}/bin/redis-server --dir ${redisHome} --port $PORT
  '';
in

{
  procfile = writeText "services-procfile" ''
    opensearch: ${start-opensearch}/bin/start-opensearch
    postgresql: ${start-postgresql}/bin/start-postgresql
    memcached: ${start-memcached}/bin/start-memcached
    redis: ${start-redis}/bin/start-redis
  '';

  environment = buildEnv {
    name = "demoapp-services";
    paths = [start-postgresql start-opensearch];
  };

  stateDirs = {
    inherit pgHome;
  };

  inherit start-opensearch start-postgresql;
}
