{
  config,
  pkgs,
  lib,
  ...
}:
let
  user = config.global.userdata.name;
in
{
  disabledModules = [
    "services/networking/pppd.nix"
  ];
  imports = [
    ./modules/nix.nix
    ./modules/user.nix
    ./modules/environment.nix
    ./modules/pppd.nix
    ./modules/network.nix
  ];

  home-manager.users.${user}.imports = [
    ../../../home/modules/common
  ];
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = false;
  };

  system.stateVersion = "26.05";
  time.timeZone = "Asia/Kolkata";
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  programs.nix-index-database.comma.enable = true;

  zramSwap.enable = true;
  swapDevices = lib.mkDefault [
    {
      device = "/swapfile";
      size = 2048; # 2GB
    }
  ];

  boot = {
    loader.timeout = 0;
    initrd.systemd.enable = true;
    tmp.cleanOnBoot = true;
  };

  services.udev.extraRules =
    let
      cmd = "${pkgs.systemd}/bin/systemctl hibernate";
    in
    ''
      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="${cmd}"
    '';
  programs.bash.promptInit = ''
    if [ "$UID" -ne 0 ]; then
        PROMPT_COLOR="1;32m"
    else
        PROMPT_COLOR="1;31m"
    fi

    PS1="\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
  '';
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "nvidia-x11"
      "slack"
    ];
}
