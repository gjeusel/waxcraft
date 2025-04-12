# NOTE:
# trace: warning: Currently nix-darwin does not support postgresql initialScript, ensureDatabases, or ensureUsers
# https://github.com/nix-darwin/nix-darwin/issues/339#issuecomment-1765304524
{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    # ----- services -----
    postgresql_16
    postgresql16Packages.pgvector
    postgresql16Packages.timescaledb
    redis
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    extraPlugins = with pkgs.postgresql_16.pkgs; [timescaledb pgvector];
    ensureUsers = map (name: {name = name;}) ["postgres" "zefire" "venturi" "peregreen" "cloud_admin" "neon_superuser"];
    ensureDatabases = [
      "zefire"
      "zefire_unittest"
      "venturi"
      "venturi_unittest"
      "anthracit"
      "anthracit-test"
      "peregreen"
      "peregreen_test"
    ];
    settings = {
      max_connections = 1000;
      log_statement = "all";
      log_timezone = "Europe/Brussels";
      datestyle = "iso, mdy";
      timezone = "Europe/Brussels";
      shared_preload_libraries = "vector,timescaledb,pg_stat_statements,pg_trgm";
    };
  };
}
