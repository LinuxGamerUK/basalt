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
    home.packages = [ cfg.package ];

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
      };
      Install = {
        WantedBy = [ cfg.systemdTarget ];
      };
    };
  };
}
