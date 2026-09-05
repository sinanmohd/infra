{
  specialisation.nvidia.configuration = {
    hardware.graphics.enable = true;
    services.xserver.videoDrivers = [ "nvidia" ];
    hardware.nvidia.open = true;

    hardware.nvidia = {
      modesetting.enable = true;
      dynamicBoost.enable = true;
      powerManagement.enable = true;
      prime = {
        sync.enable = true;
        # offload = {
        #   enable = true;
        #   enableOffloadCmd = true;
        # };
        nvidiaBusId = "PCI:1@0:0:0";
        amdgpuBusId = "PCI:5@0:0:0";
      };
    };
  };
}
