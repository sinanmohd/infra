{ pkgs, inputsSinan, ... }:
let
  chromium = inputsSinan.self.packages.${pkgs.stdenv.hostPlatform.system}.chromium;

  extension = {
    installation_mode = "force_installed";
    update_url = "https://clients2.google.com/service/update2/crx";
    toolbar_pin = "default_unpinned";
  };
in
{
  programs.chromium = {
    enable = true;
    package = chromium.override {
      policies = {
        SyncDisabled = true;
        BrowserSignin = 0;
        MetricsReportingEnabled = false;
        BookmarkBarEnabled = false;
        PasswordManagerEnabled = false;
        PromotionalTabsEnabled = false;
        DefaultBrowserSettingEnabled = false;
        NTPCardsVisible = false;
        NTPCustomBackgroundEnabled = false;

        ExtensionSettings = {
          "ddkjiahejlhfcafbddmgiahcphecmpfh" = extension; # ublock origin lite
          "pkehgijcmpdhfbdbbnkijodmdjhbjlgp" = extension; # privacy badger
          "cdhdichomdnlaadbndgmagohccgpejae" = extension; # remove youtube suggestions
          "dbepggeogbaibhgnhhndojpepiihcmeb" = extension; # vimium
          "nngceckbapebfimnlniiiahkandclblb" = extension; # bitwarden
        };
      };
    };
    commandLineArgs = [
      "--password-store=gnome-libsecret"
      "--remote-debugging-port=9222"
    ];
  };
}
