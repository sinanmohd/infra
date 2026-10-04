# NOTE: this here because some VPS providers like Hetzner has uRPFso BGP can't be used
# on that without messy adhocly adding static routes on hetzner control panel. but with
# this we get our own layer2 capable network on top of the layer 3 only hetzner setup
# static FDB is needed here cause multicast need layer2 capable network, if it was layer2
# we would not need this anyway. i choose this over GRE tunnel even if it has a lower
# overhead of 24 bytes because we will not have to create multiple interfaces per node
# to get a lan like mesh network. damn you uRPF and greedy/skill issue VPS providers
{ config, lib, ... }:
let
  cfg = config.sinan.vxlan;
in
{
  options.sinan.vxlan = {
    enable = lib.mkEnableOption "VXLAN with Static FDB";
    ipOverlay = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Overlay IP addresses";
    };
    ipUnderlayPeers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Underlay IP addresses of vxlan peers";
    };
    ifaceUnderlay = lib.mkOption {
      type = lib.types.str;
      default = null;
      description = "Underlay Iface to use";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces.${cfg.ifaceUnderlay}.allowedUDPPorts = [ 8472 ];
    systemd.network = {
      netdevs = {
        "20-vxlan0" = {
          netdevConfig = {
            Name = "vxlan0";
            Kind = "vxlan";
          };
          vxlanConfig = {
            VNI = 100;
            MacLearning = "yes";
          };
        };
      };
      networks = {
        "30-${cfg.ifaceUnderlay}".networkConfig.VXLAN = "vxlan0";
        "30-vxlan0" = {
          matchConfig.Name = "vxlan0";

          # NOTE: BUM traffic does not scale well on HER vxlan
          # Unknown Unicast is needed so let's enable that only
          linkConfig.Multicast = false;
          addresses =
            let
              genAddrs =
                ip: accumulator:
                accumulator
                ++ [
                  {
                    Address = ip;
                    Broadcast = false;
                  }
                ];
            in
            lib.lists.foldr genAddrs [ ] cfg.ipOverlay;

          bridgeFDBs =
            let
              genBridgeFDBs =
                ipPeer: accumulator:
                accumulator
                ++ [
                  {
                    MACAddress = "00:00:00:00:00:00";
                    Destination = ipPeer;
                  }
                ];
            in
            lib.lists.foldr genBridgeFDBs [ ] cfg.ipUnderlayPeers;
        };
      };
    };
  };
}
