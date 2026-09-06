{
  description = "Basalt — a Material 3 desktop shell for NixOS (Hyprland + QuickShell). Zero telemetry, zero network, fully declarative.";

  # Pinned to the nixos-unstable-small rev carrying quickshell 0.3.1 —
  # the first release with the Hyprland IPC API (workspaces/monitors/
  # toplevels). nixos-unstable still serves 0.3.0, where
  # Hyprland.workspaces does not exist. Bump when unstable catches up.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/8f3889588add43913e8bfbbd42a75345c857cf59";

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          default = pkgs.callPackage ./package.nix { rev = self.rev or self.dirtyRev or "dirty"; };
          basalt = self.packages.${system}.default;
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in
        {
          # Dev loop: nix develop -c qs -p src
          default = pkgs.mkShell {
            packages = [ pkgs.quickshell pkgs.matugen ];
          };
        });

      homeManagerModules.default = import ./modules/hm.nix { inherit self; };
      homeManagerModules.basalt = self.homeManagerModules.default;

      nixosModules.default = import ./modules/nixos.nix;
      nixosModules.basalt = self.nixosModules.default;
    };
}
