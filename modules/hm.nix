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
    # The thumbnail jail binds /usr and /etc but not /nix/store, so a
    # store-path thumbnailer (gdk-pixbuf, ffmpegthumbnailer) cannot
    # exec inside it — every job fails and thumbnails stay blank on
    # NixOS. Bind the store into the jail (harmless where absent).
    postPatch = ''
      sed -i '0,/^    "\/usr",$/s//    "\/usr",\n    "--ro-bind",\n    "\/nix\/store",\n    "\/nix\/store",\n    "--ro-bind",\n    "\/home",\n    "\/home",/' src/backend/sandbox.rs
    '';
    # Upstream's 604-test suite assumes a desktop root: /usr/bin/false,
    # system shared-mime-info under /usr/share, GIO — none of which
    # exist inside the Nix sandbox by design (586 pass; the 18 that
    # fail there pass upstream on desktop boxes). Skip checks in the
    # packaging build; the real verification surface is Files' protocol
    # behaviour live.
    doCheck = false;
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
    ] ++ (optionals cfg.fileManager.enable [
      fileManagerPackage
      # The backend's runtime env: MIME database (globs2/icons resolution)
      # and the GIO application query/launcher, both by XDG spec.
      pkgs.shared-mime-info
      pkgs.glib
      # flea's thumbnail workers sandbox themselves with bwrap/prlimit;
      # without either on PATH thumbnails are disabled (warned once).
      pkgs.bubblewrap
      pkgs.util-linux
      # Image thumbnails: flea asks for a validated thumbnailer spec per
      # MIME type (freedesktop thumbnailer spec); gdk-pixbuf's shipping
      # spec covers the common image formats. Also ffmpeg for video and
      # ffmpegthumbnailer for media frames.
      pkgs.gdk-pixbuf
      (pkgs.ffmpegthumbnailer.overrideAttrs (_: { }))
    ]);

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
        Environment = [
          "PATH=%h/.local/bin:/etc/profiles/per-user/%u/bin:%h/.nix-profile/bin:/run/current-system/sw/bin:/usr/bin:/bin"
          # The flea backend resolves MIME/glob databases and the GIO
          # application launcher by XDG_DATA_DIRS — %h/.nix-profile/share
          # carries this module's shared-mime-info; current-system and
          # the default profile close the rest.
          "XDG_DATA_DIRS=%h/.nix-profile/share:/etc/profiles/per-user/%u/share:/run/current-system/sw/share:/nix/var/nix/profiles/default/share:/usr/local/share:/usr/share"
        ];
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
