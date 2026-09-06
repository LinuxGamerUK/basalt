{ self }: { config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.basalt;
  system = pkgs.stdenv.hostPlatform.system;
in
{
  options.programs.basalt = {
    enable = mkEnableOption "Basalt — Material 3 desktop shell";

    package = mkOption {
      type = types.package;
      default = self.packages.${system}.default;
      defaultText = literalExpression "basalt.packages.<system>.default";
      description = "The Basalt package to use.";
    };

    systemdTarget = mkOption {
      type = types.str;
      default = "graphical-session.target";
      description = "Systemd user target the shell is tied to (start/stop with the session).";
    };
  };

  config = mkIf cfg.enable {
    # Wallpaper stack: the picker drives hyprpaper via `hyprctl hyprpaper`,
    # and matugen regenerates the palette locally. Both live on PATH, as
    # does quickshell itself (qs/quickshell commands for interactive use —
    # the bar's unit uses the absolute store path).
    home.packages = [ cfg.package pkgs.hyprpaper pkgs.matugen cfg.package.passthru.quickshell ];
    home.file.".config/hypr/hyprpaper.conf".text = "";

    systemd.user.services.basalt = {
      Unit = {
        Description = "Basalt desktop shell";
        After = [ cfg.systemdTarget ];
        PartOf = [ cfg.systemdTarget ];
        # The shell may start before the compositor (e.g. default.target) —
        # retry until the Wayland env is imported instead of tripping
        # systemd's default 5-starts/10s limit.
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStart = "${cfg.package.passthru.quickshell}/bin/qs -p ${cfg.package}/share/basalt";
        Restart = "on-failure";
        RestartSec = 3;
        # The scripts (basalt scripts/*, python3) resolve tools from PATH —
        # per-user profile carries this module's packages.
        Environment = "PATH=%h/.local/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        # Startup ordering: at boot Hyprland loads its config before this
        # service has connected, so the binds' __lua chunks aren't
        # registered yet and the keybinds are dead. Once QuickShell is up
        # and the Hyprland env exists, reload — the config re-parses and
        # every bind re-registers against the live Lua bridge.
        ExecStartPost = pkgs.writeShellScript "basalt-reload-hyprland" ''
          export PATH=/run/current-system/sw/bin:$PATH
          for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
            [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && break
            sleep 1
          done
          sleep 3
          ${pkgs.hyprland}/bin/hyprctl reload || true
        '';
      };
      Install = {
        WantedBy = [ cfg.systemdTarget ];
      };
    };

    systemd.user.services.basalt-hyprpaper = {
      Unit = {
        Description = "hyprpaper wallpaper daemon for Basalt";
        After = [ cfg.systemdTarget ];
        PartOf = [ cfg.systemdTarget ];
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
        Restart = "on-failure";
        RestartSec = 2;
      };
      Install = {
        WantedBy = [ cfg.systemdTarget ];
      };
    };
  };
}
