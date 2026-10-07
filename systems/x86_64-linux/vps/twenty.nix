# Twenty, the Tessoku CRM, at https://crm.tessoku.com. nixpkgs has no Twenty
# package, so the server and worker run from the upstream image while Postgres
# and Redis are NixOS services on localhost.
{ config
, lib
, pkgs
, ...
}:
let
  # Bump one minor version at a time; the server migrates the database on start
  image = "docker.io/twentycrm/twenty:v2.45.6";
  # PG_DATABASE_URL, REDIS_URL, APP_SECRET and ENCRYPTION_KEY
  secrets = "/var/lib/secrets/twenty.env";

  container = {
    inherit image;
    environment = {
      SERVER_URL = "https://crm.tessoku.com";
      STORAGE_TYPE = "local";
      TELEMETRY_ENABLED = "false";
    };
    environmentFiles = [ secrets ];
    volumes = [ "twenty-storage:/app/packages/twenty-server/.local-storage" ];
    # Reaches Postgres and Redis on localhost; the firewall keeps 3000 private
    extraOptions = [ "--network=host" ];
  };
in
{
  services = {
    postgresql = {
      enable = true;
      # Upstream's compose file runs 16; major upgrades are a manual migration
      package = pkgs.postgresql_16;
      ensureDatabases = [ "twenty" ];
      ensureUsers = [{ name = "twenty"; ensureDBOwnership = true; }];
    };
    postgresqlBackup = {
      enable = true;
      databases = [ "twenty" ];
    };

    redis.servers.twenty = {
      enable = true;
      port = 6379;
      requirePassFile = "/var/lib/secrets/twenty-redis-password";
      # Twenty's job queues break if Redis evicts keys
      settings.maxmemory-policy = "noeviction";
    };

    caddy = {
      enable = true;
      virtualHosts."crm.tessoku.com".extraConfig = ''
        reverse_proxy 127.0.0.1:3000
      '';
    };
  };

  systemd.services = {
    # ensureUsers can't set a password, and the containers log in over TCP with
    # the one inside PG_DATABASE_URL
    twenty-db-password = {
      requires = [ "postgresql.target" ];
      after = [ "postgresql.target" ];
      path = [ config.services.postgresql.package ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        EnvironmentFile = secrets;
      };
      script = ''
        password=''${PG_DATABASE_URL#postgres://twenty:}
        password=''${password%%@*}
        echo "ALTER ROLE twenty PASSWORD '$password'" | psql -v ON_ERROR_STOP=1
      '';
    };

    podman-twenty-server = {
      requires = [ "twenty-db-password.service" "redis-twenty.service" ];
      after = [ "twenty-db-password.service" "redis-twenty.service" ];
      # The module waits forever for the healthcheck, which would hang a switch
      serviceConfig.TimeoutStartSec = lib.mkForce "15min";
    };
  };

  virtualisation.oci-containers.containers = {
    twenty-server = container // {
      extraOptions = container.extraOptions ++ [
        "--health-cmd=curl --fail http://localhost:3000/healthz"
        "--health-interval=10s"
      ];
      # Ready only once migrations finish, so the worker starts after them
      podman.sdnotify = "healthy";
    };
    twenty-worker = container // {
      environment = container.environment // {
        DISABLE_DB_MIGRATIONS = "true";
        DISABLE_CRON_JOBS_REGISTRATION = "true";
      };
      cmd = [ "yarn" "worker:prod" ];
      dependsOn = [ "twenty-server" ];
    };
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    allowedUDPPorts = [ 443 ]; # HTTP/3
  };
}
