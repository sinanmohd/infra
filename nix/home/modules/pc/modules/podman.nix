{
  services.podman = {
    enable = true;
    settings.registries = {
      search = [ "docker.io" ];
    };
  };
}
