{ config, lib, ... }:
let
  bashHistory = config.xdg.stateHome + "/bash/history";
in
{
  home.activation.init = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run --silence mkdir -p ${builtins.dirOf bashHistory}
  '';

  gtk.gtk2.configLocation = config.xdg.configHome + "/gtk-2.0/gtkrc";

  home.sessionVariables = {
    HISTFILE = bashHistory;
    GOPATH = config.xdg.dataHome + "/go";
  };
}
