{ config, lib, ... }:

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
  };
}
