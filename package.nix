{ stdenv, quickshell, rev ? "dirty" }:

stdenv.mkDerivation {
  pname = "basalt";
  version = "0.1.0+${builtins.substring 0 7 rev}";

  src = ./src;

  installPhase = ''
    mkdir -p $out/share/basalt
    cp -r $src/. $out/share/basalt/
  '';

  passthru = { inherit quickshell; };
}
