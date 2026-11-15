{
  config,
  lib,
  ...
}:
let
  domain = config.global.userdata.domain;
  ssh-add = lib.getExe' config.services.ssh-agent.package "ssh-add";
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "Host *" = {
        Compression = true;
        AddKeysToAgent = "yes";
      };
      "Host kay".HostName = domain;
      "Host exy" = {
        Port = 8022;
        User = "u0_a369";
      };
    };
  };

  services.ssh-agent.enable = true;
  systemd.user.services.ssh-add = {
    Unit = {
      Description = "Load the default ssh key into ssh-agent";
      After = [ "ssh-agent.service" ];
      Requires = [ "ssh-agent.service" ];
      ConditionPathExists = "%h/.ssh/id_ed25519";
    };
    Service = {
      Type = "oneshot";
      Environment = "SSH_AUTH_SOCK=%t/${config.services.ssh-agent.socket}";
      ExecStart = "${ssh-add} %h/.ssh/id_ed25519";
      Restart = "on-failure";
      RestartSec = 1;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
