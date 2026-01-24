# PostgreSQL via nix-darwin
# NOTE: nix-darwin doesn't support ensureDatabases, ensureUsers, or initialScript
# https://github.com/nix-darwin/nix-darwin/issues/339#issuecomment-1765304524
#
# Solution: Use a separate launchd agent to initialize databases after postgres starts
{
  config,
  pkgs,
  ...
}: let
  user = "gjeusel";
  dataDir = "/var/lib/postgresql/16";
  socketDir = "/tmp";

  # Users and databases to create
  dbUsers = ["postgres" "zefire" "venturi" "peregreen" "cloud_admin" "neon_superuser"];
  databases = [
    "zefire"
    "zefire_unittest"
    "venturi"
    "venturi_unittest"
    "anthracit"
    "anthracit-test"
    "peregreen"
    "peregreen_test"
  ];

  # Init script that runs after postgres starts
  postgresInitScript = pkgs.writeShellScript "postgres-init.sh" ''
    set -e

    MARKER_FILE="${dataDir}/.databases_initialized"
    PSQL="${pkgs.postgresql_16}/bin/psql"
    PG_ISREADY="${pkgs.postgresql_16}/bin/pg_isready"

    # Exit if already initialized
    if [ -f "$MARKER_FILE" ]; then
      echo "Databases already initialized, skipping."
      exit 0
    fi

    echo "Waiting for PostgreSQL to be ready..."
    for i in $(seq 1 30); do
      if $PG_ISREADY -h ${socketDir} -U ${user} >/dev/null 2>&1; then
        echo "PostgreSQL is ready!"
        break
      fi
      if [ "$i" -eq 30 ]; then
        echo "Timed out waiting for PostgreSQL"
        exit 1
      fi
      sleep 1
    done

    echo "Creating users..."
    ${builtins.concatStringsSep "\n" (map (u: ''
      if ! $PSQL -h ${socketDir} -U ${user} -tAc "SELECT 1 FROM pg_roles WHERE rolname='${u}'" | grep -q 1; then
        echo "Creating user: ${u}"
        $PSQL -h ${socketDir} -U ${user} -c "CREATE USER \"${u}\" WITH SUPERUSER CREATEDB CREATEROLE;"
      else
        echo "User ${u} already exists"
      fi
    '') dbUsers)}

    echo "Creating databases..."
    ${builtins.concatStringsSep "\n" (map (db: ''
      if ! $PSQL -h ${socketDir} -U ${user} -tAc "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
        echo "Creating database: ${db}"
        $PSQL -h ${socketDir} -U ${user} -c "CREATE DATABASE \"${db}\";"
      else
        echo "Database ${db} already exists"
      fi
    '') databases)}

    echo "Enabling extensions..."
    ${builtins.concatStringsSep "\n" (map (db: ''
      $PSQL -h ${socketDir} -U ${user} -d "${db}" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
      $PSQL -h ${socketDir} -U ${user} -d "${db}" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" 2>/dev/null || true
    '') databases)}

    # Mark as initialized
    touch "$MARKER_FILE"
    echo "Database initialization complete!"
  '';
in {
  environment.systemPackages = with pkgs; [
    postgresql_16
    postgresql16Packages.pgvector
    postgresql16Packages.timescaledb
    redis
  ];

  # Create data directory before activation
  system.activationScripts.preActivation.text = ''
    echo "Setting up PostgreSQL data directory..."
    if [ ! -d "${dataDir}" ]; then
      sudo mkdir -p "${dataDir}"
      sudo chown -R ${user}:staff "${dataDir}"
      sudo chmod 750 "${dataDir}"
    fi
  '';

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    dataDir = dataDir;
    extraPlugins = with pkgs.postgresql_16.pkgs; [timescaledb pgvector];
    initdbArgs = [
      "-U"
      user
      "--auth=trust"
      "--no-locale"
      "--encoding=UTF8"
    ];
    settings = {
      max_connections = 1000;
      log_statement = "all";
      log_timezone = "Europe/Brussels";
      datestyle = "iso, mdy";
      timezone = "Europe/Brussels";
      shared_preload_libraries = "vector,timescaledb,pg_stat_statements,pg_trgm";
      unix_socket_directories = socketDir;
    };
  };

  # Add logging to postgresql service
  launchd.user.agents.postgresql.serviceConfig = {
    StandardErrorPath = "/tmp/postgres.error.log";
    StandardOutPath = "/tmp/postgres.log";
  };

  # One-shot agent to initialize databases after postgres starts
  launchd.user.agents.postgresql-init = {
    serviceConfig = {
      ProgramArguments = ["${postgresInitScript}"];
      RunAtLoad = true;
      KeepAlive = false;
      StandardErrorPath = "/tmp/postgres-init.error.log";
      StandardOutPath = "/tmp/postgres-init.log";
    };
  };
}
