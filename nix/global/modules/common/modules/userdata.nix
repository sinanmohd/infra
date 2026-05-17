{ config, lib, ... }:
let
  cfg = config.global.userdata;
in
{
  options.global.userdata = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "sinan";
      description = "Owner's username";
    };
    nameFq = lib.mkOption {
      type = lib.types.str;
      default = "sinanmohd";
      description = "Owner's fully qualified username";
    };
    domain = lib.mkOption {
      type = lib.types.str;
      default = "sinanmohd.com";
      description = "Owner's domain";
    };
    email = lib.mkOption {
      type = lib.types.str;
      default = "${cfg.name}@${cfg.domain}";
      description = "Owner's email";
    };
  };
}
