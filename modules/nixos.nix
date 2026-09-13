{ config, lib, pkgs, ... }:

with lib;

{
  options.programs.basalt = {
    enable = mkEnableOption "system-level support for the Basalt desktop shell";
  };

  # Deliberately restrained: the shell does not own your compositor, your
  # display manager, your terminal, or your file browser. These are the
  # bare system defaults a QuickShell-based shell expects — all mkDefault,
  # so your own config always wins.
  config = mkIf config.programs.basalt.enable {
    services.pipewire = {
      enable = mkDefault true;
      pulse.enable = mkDefault true;
    };
    security.rtkit.enable = mkDefault true;

    # The flea backend (Gabbro's engine) resolves MIME types against a
    # hardcoded /usr/share/mime — absent on NixOS (everything lives in
    # store paths). A /usr/share/mime symlink is the least invasive
    # step; only created when the file manager is enabled. Harmless on
    # distros where that path already exists.
    systemd.tmpfiles.rules = [
      "L+ /usr/share/mime - - - - ${pkgs.shared-mime-info}/share/mime"
    ];
  };
}
