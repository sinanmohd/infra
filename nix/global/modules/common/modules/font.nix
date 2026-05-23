{ pkgs, lib, ... }:
let
  name = {
    type = lib.types.str;
    example = "Terminess Nerd Font";
  };
  size = {
    type = with lib.types; nullOr int;
    default = null;
  };
  packages = {
    type = with lib.types; listOf path;
    example = "[ pkgs.nerd-fonts.terminess-ttf ]";
  };
in
{
  options.global.font = {
    sans = {
      size = lib.mkOption size;
      name = lib.mkOption (
        name
        // {
          default = "DeepMindSans Nerd Font";
        }
      );
      packages = lib.mkOption (
        packages
        // {
          default = [
            (pkgs.dm-sans.overrideAttrs (o: {
              nativeBuildInputs = [ pkgs.nerd-font-patcher ];
              postInstall = ''
                mkdir -p $out/share/fonts/truetype/{dm-sans,dm-sans-nerd}
                mv $out/share/fonts/truetype/*.ttf $out/share/fonts/truetype/dm-sans/
                for f in $out/share/fonts/truetype/dm-sans/*.ttf; do
                  nerd-font-patcher --complete --outputdir $out/share/fonts/truetype/dm-sans-nerd/ $f
                done
              '';
            }))
          ];
        }
      );
    };

    monospace = {
      size = lib.mkOption size;
      name = lib.mkOption (
        name
        // {
          default = "Terminess Nerd Font";
        }
      );
      packages = lib.mkOption (
        packages
        // {
          default = [
            (pkgs.terminus_font_ttf.overrideAttrs (o: {
              nativeBuildInputs = [ pkgs.nerd-font-patcher ];
              postInstall = ''
                mkdir -p $out/share/fonts/truetype/{terminus,terminus-nerd}
                mv $out/share/fonts/truetype/*.ttf $out/share/fonts/truetype/terminus/
                for f in $out/share/fonts/truetype/terminus/*.ttf; do
                  nerd-font-patcher --complete --outputdir $out/share/fonts/truetype/terminus-nerd/ $f
                done
              '';
            }))
          ];
        }
      );
    };
  };
}
