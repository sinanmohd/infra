{
  swapDevices = [
    {
      device = "/swapfile";
      size = 14 * 1024; # 14GB
    }
  ];
  zramSwap.memoryPercent = 100;
}
