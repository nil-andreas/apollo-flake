{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  inherit
    (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    literalExpression
    mkIf
    mkDefault
    types
    optionals
    getExe
    ;
  inherit (utils) escapeSystemdExecArgs;

  cfg = config.services.apollo;

  generatePorts = port: offsets: map (offset: port + offset) offsets;
  defaultPort = 47989;

  appsFormat = pkgs.formats.json {};
  settingsFormat = pkgs.formats.keyValue {};

  appsFile = appsFormat.generate "apps.json" cfg.applications;
  configFile = settingsFormat.generate "sunshine.conf" cfg.settings;
in {
  options.services.apollo = with types; {
    enable = mkEnableOption "Apollo, a self-hosted game stream host for Moonlight";

    package =
      mkPackageOption pkgs "apollo" {
      };

    openFirewall = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to automatically open ports in the firewall for Apollo.
      '';
    };

    capSysAdmin = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to give the Apollo binary CAP_SYS_ADMIN, required for DRM/KMS screen capture.
      '';
    };

    autoStart = mkOption {
      type = bool;
      default = true;
      description = ''
        Whether Apollo should be started automatically as a user service.
      '';
    };

    settings = mkOption {
      default = {};
      description = ''
        Settings to be rendered into the Apollo configuration file (e.g., sunshine.conf).
        If this is set, configuration via the web UI might be overridden or disabled.
        Refer to Sunshine documentation for available settings.
      '';
      example = literalExpression ''
        {
          # Verify these keys with Apollo's documentation.
          # This example assumes keys similar to Sunshine.
          sunshine_name = "nixos-apollo"; # Example key
          # port = 47989; # This is handled by settings.port below by default
        }
      '';
      type = submodule (settingsSubmodule: {
        # This allows freeform key-value pairs for Apollo settings
        freeformType = settingsFormat.type;
        options.port = mkOption {
          type = port;
          default = defaultPort;
          description = ''
            Base port for Apollo. Other service ports are offset from this.
            Refer to Apollo/Sunshine documentation for port details.
          '';
        };
      });
    };

    applications = mkOption {
      default = {};
      description = ''
        Configuration for applications to be exposed to Moonlight via Apollo.
        If this is set, configuration via the web UI might be overridden or disabled.
      '';
      example = literalExpression ''
        {
          env = {
            PATH = "$(PATH):$(HOME)/.local/bin"; # Example global env var for apps
          };
          apps = [
            {
              name = "Desktop Stream via Apollo";
              # command = "..."; # Specify command if not fullscreen
          prep-cmd = [
            {
              do = ''''
              ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2,3840x2160@60,0x0,1
              '''';
              undo = ''''
                ${pkgs.hyprland}/bin/hyprctl keyword monitor DP-2,5120x1440@240,0x0,1
              '''';
            }
          ];
            }
          ];
        }
      '';
      type = submodule {
        options = {
          env = mkOption {
            default = {};
            description = ''
              Global environment variables to be set for the applications.
            '';
            type = attrsOf str;
          };
          apps = mkOption {
            default = [];
            description = ''
              List of applications to be exposed to Moonlight.
              Refer to Apollo/Sunshine documentation for app configuration structure.
            '';
            type = listOf attrs;
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.apollo.settings.file_apps = mkIf (cfg.applications.apps != []) "${appsFile}";

    environment.systemPackages = [
      cfg.package
    ];

    # Firewall configuration: Verify these ports with Apollo's documentation.
    # These are based on the Sunshine defaults.
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = generatePorts cfg.settings.port [
        (-5) # HTTPS
        0 # HTTP
        1 # Control
        21 # Sunshine Service Discovery
      ];
      allowedUDPPorts = generatePorts cfg.settings.port [
        9 # Audio
        10 # Video
        11 # Input
        13 # Discovery / Server-Sent Events
        21 # Sunshine Service Discovery
      ];
    };

    # Kernel module for virtual input devices
    boot.kernelModules = ["uinput"];

    # Udev rules (your Apollo flake already installs these via CMake)
    services.udev.packages = [cfg.package];

    # Avahi for service discovery (mDNS)
    services.avahi = {
      enable = mkDefault true; # Enable Avahi daemon
      publish = {
        enable = mkDefault true; # Enable publishing of services
        userServices = mkDefault true; # Allow user services to publish
      };
    };

    # Wrapper with CAP_SYS_ADMIN if configured
    security.wrappers.apollo = mkIf cfg.capSysAdmin {
      owner = "root";
      group = "root";
      capabilities = "cap_sys_admin+p";
      source = "${getExe cfg.package}";
    };

    systemd.user.services.apollo = {
      description = "Apollo - Self-hosted game stream host for Moonlight";

      wantedBy = mkIf cfg.autoStart ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      after = ["graphical-session.target"];

      startLimitIntervalSec = 500;
      startLimitBurst = 5;

      # Clear default PATH to ensure a controlled environment, especially for tray icon links
      environment.PATH = lib.mkForce null;

      serviceConfig = {
        ExecStart = escapeSystemdExecArgs (
          [
            (
              if cfg.capSysAdmin
              then "${config.security.wrapperDir}/apollo"
              else "${getExe cfg.package}"
            )
          ]
          ++ optionals (
            cfg.applications.apps
            != [] # If applications are defined
            || (builtins.length (builtins.attrNames cfg.settings) > 1 || cfg.settings.port != defaultPort) # Or if settings beyond just the default port are made
          ) ["${configFile}"]
        );
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
