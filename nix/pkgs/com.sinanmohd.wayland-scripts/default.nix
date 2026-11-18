{
  stdenvNoCC,
  lib,
  makeWrapper,

  bash,
  sway,
  ffmpeg,
  libnotify,
  jq,
  coreutils,
  mpv,
  mpvScripts,
  util-linux,
  gnugrep,
  file,
  wl-clipboard,
  xdg-utils,
  wtype,
  tailscale,
  alacritty,
  linkFarm,
  fetchurl,
  gnused,
  piper-tts,
}:
let
  piperVoice =
    let
      base = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/hfc_female/medium/en_US-hfc_female-medium";
    in
    linkFarm "piper-voice-en_US-hfc_female-medium" {
      "voice.onnx" = fetchurl {
        url = "${base}.onnx";
        hash = "sha256-kUxHN4j8H6i2Os4c3NtEWI9K5SPTqzffFTZhaDWhQLc=";
      };
      "voice.onnx.json" = fetchurl {
        url = "${base}.onnx.json";
        hash = "sha256-A/H6BiK4BGMoNZLZesqfbomuw0WlxWtyV3I+AJPFi2w=";
      };
    };

  # NOTE: own mpris bus name, so waybar shows the speak icon and playerctl can
  # target speak apart from other mpv players
  speakMpris = mpvScripts.mpris.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace mpris.c \
        --replace-fail '"org.mpris.MediaPlayer2.mpv"' '"org.mpris.MediaPlayer2.speak"'
    '';
  });
  speakMpv = mpv.override { scripts = [ speakMpris ]; };
in
stdenvNoCC.mkDerivation {
  pname = "wayland-scipts";
  version = "1717606223";
  src = ./src;

  strictDeps = true;
  outputs = [ "out" ];
  buildInputs = [ bash ];
  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    for sh in bin/*; do
      patchShebangs --host "$sh"
    done
  '';

  installPhase = ''
    runHook preInstall
    cp -r ./ $out
    runHook postInstall
  '';

  postInstall = ''
    wrapProgram $out/bin/cwall \
      --prefix PATH : ${
        lib.makeBinPath [
          ffmpeg
          libnotify
          sway
        ]
      }
    wrapProgram $out/bin/ttyasrt \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          alacritty
        ]
      }
    wrapProgram $out/bin/freezshot \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          sway
          jq
          coreutils
        ]
      }
    wrapProgram $out/bin/damb \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          (mpv.override { scripts = [ mpvScripts.mpris ]; })
          util-linux
          gnugrep
          coreutils
          file
        ]
      }
    wrapProgram $out/bin/dbook \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          file
          coreutils
          wl-clipboard
          xdg-utils
          wtype
        ]
      }
    wrapProgram $out/bin/vpn \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          gnugrep
          tailscale
        ]
      }
    wrapProgram $out/bin/yo \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
        ]
      }
    wrapProgram $out/bin/speak \
      --set-default SPEAK_VOICE ${piperVoice}/voice.onnx \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          gnused
          speakMpv
          piper-tts
        ]
      }
  '';

  meta = {
    description = "Wayland scripts for sway";
    homepage = "https://www.sinanmohd.com";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    mainProgram = "pinentry-fuzzel";
    maintainers = with lib.maintainers; [ sinanmohd ];
  };
}
