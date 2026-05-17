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
          default = "DeepMind Sans";
        }
      );
      packages = lib.mkOption (
        packages
        // {
          default = [ pkgs.dm-sans ];
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
          default = [ pkgs.nerd-fonts.terminess-ttf ];
        }
      );
    };
  };
}
