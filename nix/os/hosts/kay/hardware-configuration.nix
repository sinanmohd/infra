{ modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot = {
    loader.systemd-boot.enable = true;

    kernelModules = [ "kvm-intel" ];
    blacklistedKernelModules = [ "nouveau" ];
    initrd.availableKernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "usbhid"
      "sd_mod"
    ];
  };

  services.fstrim.enable = true;
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/2eeacf49-c51e-4229-bd4a-ae437014725f";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/A902-90BB";
      fsType = "vfat";
    };
    "/hdd" = {
      device = "/dev/disk/by-uuid/c941edb4-e393-4254-bbef-d1b3728290e9";
      fsType = "ext4";
      options = [ "nofail" ];
    };
  };
}
