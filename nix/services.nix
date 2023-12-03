{ postgresql,
  buildEnv, coreutils, gnused, writeShellScriptBin, writeText, writeTextFile, runtimeShell, lib }:

let
  pgHome = "$PWD/tmp/postgresql-${lib.versions.major postgresql.version}";

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
      ${postgresql}/bin/initdb -U moergo -D ${pgHome} -E utf-8 --no-locale
    fi

    ln -fs ${postgresqlConfig} ${pgHome}/postgresql.conf

    exec ${postgresql}/bin/postgres -D ${pgHome} -i -p $PORT
  '';

in

{
  procfile = writeText "services-procfile" ''
    postgresql: ${start-postgresql}/bin/start-postgresql
  '';

  environment = buildEnv {
    name = "eikaiwa-content-services";
    paths = [start-postgresql];
  };

  stateDirs = {
    inherit pgHome;
  };

  inherit start-postgresql;
}
