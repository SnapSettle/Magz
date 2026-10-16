{ config, lib, pkgs, ... }:

let
  cfg = config.services.magz;
  magzPkg = pkgs.callPackage ./package.nix { };

  # Here we serialize the configuration directly into JSON syntax expected by main.go
  configFile = pkgs.writeText "magz.config.json" (builtins.toJSON {
    Port = cfg.port;
    AutoRefreshInterval = cfg.autoRefreshInterval;
    LibraryPaths = cfg.libraryPaths;
    CacheDB = "${cfg.dataDir}/${cfg.cacheDB}";
    MaxThumbnailSize = cfg.maxThumbnailSize;
    LogLevel = cfg.logLevel;
  });
in {

  options.services.magz = {
    enable = lib.mkEnableOption "Magz Digital Library Server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      description = "The port the Magz server will listen on.";
    };

    autoRefreshInterval = lib.mkOption {
      type = lib.types.int;
      default = 30;
      description = "Interval in minutes between automatic library cache updates.";
    };

    libraryPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [];
      example = [ "/var/lib/media/books" "/mnt/nas/magazines" ];
      description = "List of absolute directories to scan for comic/magazine assets.";
    };

    cacheDB = lib.mkOption {
      type = lib.types.str;
      default = "magz_cache.db";
      description = "Filename for the internal SQLite cache storage.";
    };

    maxThumbnailSize = lib.mkOption {
      type = lib.types.int;
      default = 400;
      description = "Maximum bounding resolution side length for cover thumb renders.";
    };

    logLevel = lib.mkOption {
      type = lib.types.enum [ "info" "debug" "error" ];
      default = "info";
      description = "Application output severity metrics verbosity level.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/Magz";
      description = "The database caching directory home folder on the state layer.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "magz";
      description = "The user account under which the Magz service runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "magz";
      description = "The primary group for the Magz service user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "media" "nas-share" ];
      description = "Additional system groups for the Magz user (useful for reading existing media paths).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Ensure our base operating system targets allow the application paths
    # inside system boundaries by verifying configurations securely.
    assertions = [
      {
        assertion = cfg.libraryPaths != [];
        message = "You must specify at least one path directory path in services.magz.libraryPaths";
      }
    ];

    users.users = lib.mkIf (cfg.user == "magz") {
      magz = {
        isSystemUser = true;
        group = cfg.group;
        extraGroups = cfg.extraGroups;
        home = cfg.dataDir;
        createHome = false; # Handled reliably by systemd StateDirectory instead
        description = "Magz service user daemon account";
      };
    };

    users.groups = lib.mkIf (cfg.group == "magz") {
      magz = {};
    };

    systemd.services.magz = {
      description = "Magz Media Server Daemon Engine";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${magzPkg}/bin/magz";
        
        # Explicit static user credentials mapping
        User = cfg.user;
        Group = cfg.group;

        # This cleanly ensures that /var/lib/magz exists and is chown'ed to your custom user automatically
        StateDirectory = "magz";
        StateDirectoryMode = "0750";
        WorkingDirectory = cfg.dataDir;
        
        # Sandboxing rules to limit system mutations
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        ReadOnlyPaths = cfg.libraryPaths;

        Restart = "always";
      };

      # Safely link our generated config file directly inside our storage home context right before launch
      preStart = ''
        ln -sf ${configFile} ${cfg.dataDir}/magz.config.json
      '';
    };
  };
}
