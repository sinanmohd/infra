{ ... }:
{
  programs.firefox = {
    enable = true;
    policies = {
      DisableFirefoxAccounts = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisplayBookmarksToolbar = "never";
      OfferToSaveLogins = false;
      OverrideFirstRunPage = "";
      NoDefaultBookmarks = true;
      DontCheckDefaultBrowser = true;
      # SanitizeOnShutdown = true;

      FirefoxHome = {
        Locked = true;
        TopSites = false;
        Highlights = false;
        Snippets = false;
        Pocket = false;
      };

      FirefoxSuggest = {
        Locked = true;
        SponsoredSuggestions = false;
      };

      Containers.Default = [
        {
          name = "botnet";
          icon = "fence";
          color = "blue";
        }
        {
          name = "work";
          icon = "briefcase";
          color = "yellow";
        }
      ];

      ExtensionSettings = {
        "uBlock0@raymondhill.net" = {
          installation_mode = "force_installed";
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        };
        "jid1-MnnxcxisBPnSXQ@jetpack" = {
          installation_mode = "force_installed";
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
        };
        "{21f1ba12-47e1-4a9b-ad4e-3a0260bbeb26}" = {
          installation_mode = "force_installed";
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/remove-youtube-s-suggestions/latest.xpi";
        };
        "tridactyl.vim@cmcaine.co.uk" = {
          installation_mode = "force_installed";
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/tridactyl-vim/latest.xpi";
        };
        "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
          installation_mode = "force_installed";
          default_area = "menupanel";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden_password_manager/latest.xpi";
        };
      };
    };

    profiles."default".settings = {
      "media.ffmpeg.vaapi.enabled" = true;
      "browser.ml.chat.provider" = "https://grok.com/";

      "browser.uiCustomization.state" = builtins.toJSON {
        currentVersion = 1337;

        placements = {
          widget-overflow-fixed-list = [ ];
          unified-extensions-area = [ ];
          nav-bar = [
            "back-button"
            "forward-button"
            "stop-reload-button"
            "customizableui-special-spring1"
            "urlbar-container"
            "customizableui-special-spring2"
            "downloads-button"
            "unified-extensions-button"
          ];
          toolbar-menubar = [ "menubar-items" ];
          TabsToolbar = [
            "tabbrowser-tabs"
            "new-tab-button"
            "alltabs-button"
          ];
        };

        dirtyAreaCache = [
          "nav-bar"
          "toolbar-menubar"
          "TabsToolbar"
        ];
      };

      "media.webrtc.camera.allow-pipewire" = true;
      "browser.newtabpage.activity-stream.default.sites" = "";
      "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
    };
  };
}
