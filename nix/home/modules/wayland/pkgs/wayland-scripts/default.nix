{
  stdenvNoCC,
  lib,
  makeWrapper,

  bash,
  sway,
  ffmpeg,
  libnotify,
  bemenu,
  jq,
  coreutils,
  mpv,
  util-linux,
  gnugrep,
  file,
  wl-clipboard,
  xdg-utils,
  wtype,
  curl,
  tailscale,
  bc,
}:

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
    wrapProgram $out/bin/daskpass \
      --prefix PATH : ${lib.makeBinPath [ bemenu ]}
    wrapProgram $out/bin/ttyasrt \
      --prefix PATH : ${lib.makeBinPath [ libnotify ]}
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
          bemenu
          mpv
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
          bemenu
          coreutils
          wl-clipboard
          xdg-utils
          wtype
        ]
      }
    wrapProgram $out/bin/pirowatch \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          curl
          bemenu
          coreutils
          gnugrep
          # webtorrent
        ]
      }
    wrapProgram $out/bin/tcsv \
      --prefix PATH : ${
        lib.makeBinPath [
          libnotify
          curl
          bemenu
          bc
          # webtorrent
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
  '';

  meta = {
    description = "Wayland scripts for sway";
    homepage = "https://www.sinanmohd.com";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ sinanmohd ];
  };
}
