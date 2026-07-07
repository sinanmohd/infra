{
  modulesPath,
  config,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  hardware.bluetooth.enable = true;
  services.xserver.videoDrivers = [ "modesetting" ];

  swapDevices = [
    {
      device = "/swapfile";
      size = 14 * 1024; # 14GB
    }
  ];
  zramSwap.memoryPercent = 100;

  boot = {
    blacklistedKernelModules = [ "k10temp" ];
    extraModulePackages = with config.boot.kernelPackages; [ zenpower ];

    initrd.luks.devices."crypt".device = "/dev/disk/by-uuid/84acd784-caad-41a1-a2e4-39468d01fefd";
  };

  fileSystems = {
    "/boot" = {
      device = "/dev/disk/by-uuid/E37E-F611";
      fsType = "vfat";
    };
    "/" = {
      device = "/dev/disk/by-uuid/e063c9ad-b48f-4b6c-b94e-4c21d2238bce";
      fsType = "ext4";
    };
  };
}
