{
  config,
  pkgs,
  lib,
  ...
}:
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

  cfg = config.global.font;
in
{
  options.global.font = {
    sans = {
      sizePx = lib.mkOption size;
      sizePt = lib.mkOption (
        size
        // {
          # 0.75 is used for 96 DPI
          default = if cfg.sans.sizePx != null then lib.floor (cfg.sans.sizePx * 0.75) else null;
        }
      );
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
      sizePx = lib.mkOption size;
      sizePt = lib.mkOption (
        size
        // {
          # 0.75 is used for 96 DPI
          default = if cfg.monospace.sizePx != null then lib.floor (cfg.monospace.sizePx * 0.75) else null;
        }
      );
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
