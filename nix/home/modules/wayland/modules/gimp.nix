{ pkgs, ... }:
let
  # NOTE: gimp ships its own colors. Its "System" theme follows the GTK theme
  # (wallust) instead. Set as the default through the system gimprc,
  gimprc = pkgs.writeText "gimprc" ''
    (theme "System")
  '';

  gimp = pkgs.symlinkJoin {
    inherit (pkgs.gimp3) pname version;

    paths = [
      pkgs.gimp3
      pkgs.gimp3.man
    ];

    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in gimp gimp-3 gimp-3.2; do
        wrapProgram $out/bin/$bin --add-flags --system-gimprc=${gimprc}
      done
    '';
  };
in
{
  home.packages = [ gimp ];
}
