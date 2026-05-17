{ ... }:
{
  programs.mangohud = {
    enable = true;

    settings = {
      horizontal = true;
      legacy_layout = 0;
      hud_no_margin = true;
      gpu_stats = true;
      gpu_temp = true;
      gpu_core_clock = true;
      gpu_mem_clock = true;
      gpu_power = true;
      gpu_name = true;
      cpu_stats = true;
      cpu_temp = true;
      cpu_power = true;
      cpu_mhz = true;
      vram = true;
      vram_color = "ad64c1";
      ram = true;
      ram_color = "c26693";
      fps = true;
      frame_timing = 1;
      frametime_color = "00ff00";
      text_color = "ffffff";
    };
  };
}
