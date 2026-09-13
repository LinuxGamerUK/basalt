{ self }: { config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.basalt;
  system = pkgs.stdenv.hostPlatform.system;
  # The pairing agent needs D-Bus bindings the stock python3 lacks.
  agentPython = pkgs.python3.withPackages (ps: [
    ps.dbus-python
    ps.pygobject3
  ]);

  # flea's Rust backend (the Files window's engine) — pinned upstream.
  # Pure-std Rust, zero dependencies (upstream Cargo.lock committed at
  # modules/flea.cargo.lock); only the `--backend` NDJSON mode is used.
  fileManagerPackage = pkgs.rustPlatform.buildRustPackage {
    pname = "flea";
    version = "0.2.1";
    src = pkgs.fetchFromGitHub {
      owner = "thisisgm";
      repo = "flea";
      rev = "c6a014999696fe67a899013d97ebccf889e98f47";
      hash = "sha256-G9gr/6ArT86Gf+uofb/EG1Yc1oScrYJavPprEdPA480=";
    };
    cargoLock.lockFile = ./flea.cargo.lock;
    # Upstream's test harness insists its test sandbox root be at least
    # two path components deep (a /tmp directly at the root is refused
    # as "must resolve outside HOME"); the Nix sandbox's bare /tmp fails
    # that, so point TMPDIR at a nested dir for the check phase.
    preCheck = ''
      mkdir -p tmp/flea-sandbox
      export TMPDIR="$PWD/tmp/flea-sandbox"
    '';
    meta = { license = pkgs.lib.licenses.mit; };
  };
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

    fileManager = {
      enable = mkEnableOption ''
        the Basalt file manager (Files) — a Material 3 Quickshell frontend
        driving flea's MIT Rust backend (pinned upstream; pure std Rust,
        zero dependencies, see src/filemgr/)'';
    };
  };

  config = mkIf cfg.enable {
    # Wallpaper stack: the picker drives hyprpaper via `hyprctl hyprpaper`,
    # and matugen regenerates the palette locally. Both live on PATH, as
    # does quickshell itself (qs/quickshell commands for interactive use —
    # the bar's unit uses the absolute store path).
    # python3 + cava are module-owned script/widget dependencies: the shell
    # QML spawns `python3` (wallpaper/theme/ember scripts) and cava spawns
    # via the Cava.qml widget by bare name — on a bare NixOS user neither
    # would resolve in the unit's fixed PATH (found live on the P1 and the
    # Legion, 2026-09-12).
    home.packages = [
      cfg.package
      pkgs.hyprpaper
      pkgs.matugen
      pkgs.python3
      pkgs.cava
      cfg.package.passthru.quickshell
    ] ++ (optionals cfg.fileManager.enable [ fileManagerPackage ]);

    home.file.".config/hypr/hyprpaper.conf".text = "";

    # cava config: the Cava.qml widget spawns `cava -p ~/.config/cava/config`
    # and plain cava exits on a missing config file — seed the raw-ASCII
    # config the widget parses: 24 bars, `0;0;…` frames 0–1000.
    home.file.".config/cava/config".text = ''
      [general]
      bars = 24

      [output]
      method = raw
      data_format = ascii
      bit_format = 8bit
      ascii_max_range = 1000
      bar_delimiter = 59
      frame_delimiter = 10
    '';

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
        # NOTE: never reload Hyprland's config from here (or anywhere).
        # Hyprland 0.56.2's lua-config keybinds (__lua chunk refs) go INERT
        # after any config reload — the binds stay registered but stop
        # firing. The boot-time parse registers them working; they survive
        # until the first reload. Runtime changes (e.g. theming) must use
        # hyprctl dispatch hl.config(...) instead.
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
        # always, not on-failure: at boot hyprpaper starts before any
        # compositor exists and exits CLEANLY (no Wayland display), which
        # on-failure never restarts — the wallpaper daemon was then gone
        # for the entire session. Restart=always keeps retrying until the
        # session appears, then stays.
        Restart = "always";
        RestartSec = 3;
      };
      Install = {
        WantedBy = [ cfg.systemdTarget ];
      };
    };

    # Bluez pairing agent — without ANY registered agent bluez fails every
    # pairing with "Authentication Failed"; blueman's agent only ships
    # inside its GTK applet, so Basalt ships a minimal headless one. It
    # auto-accepts Just Works/numeric-compare SSP and service connect
    # prompts (documented headless behaviour). Requires a system bluez
    # daemon (hardware.bluetooth.enable = true on NixOS).
    systemd.user.services.basalt-bt-agent = {
      Unit = {
        Description = "Bluez bluetooth pairing agent for Basalt";
        After = [ cfg.systemdTarget ];
        PartOf = [ cfg.systemdTarget ];
        StartLimitIntervalSec = 0;
      };
      Service = {
        ExecStart = "${agentPython}/bin/python ${cfg.package}/share/basalt/scripts/bluetooth-agent.py";
        Restart = "always";
        RestartSec = 5;
      };
      Install = {
        WantedBy = [ cfg.systemdTarget ];
      };
    };
  };
}
