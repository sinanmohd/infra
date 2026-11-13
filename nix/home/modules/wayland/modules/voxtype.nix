{
  config,
  pkgs,
  lib,
  ...
}:
let
  swaymsg = lib.getExe' config.wayland.windowManager.sway.package "swaymsg";

  # NOTE: pinned instead of services.voxtype.loadModels, which downloads at
  # runtime. voxtype takes an absolute dir holding these names and prefers
  # the *_quantized.onnx files
  moonshineRev = "b1e9b6aae3c3c7298f10c3798393fdf38e8fbbad";
  moonshineFile =
    path: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/onnx-community/moonshine-base-ONNX/resolve/${moonshineRev}/${path}";
      inherit hash;
    };
  model = pkgs.linkFarm "voxtype-moonshine-base" {
    "encoder_model_quantized.onnx" =
      moonshineFile "onnx/encoder_model_quantized.onnx" "sha256-HdmrCn+YcRPTCv/LpaBo0RyPkPoCI8qj5JGt5DGtl1E=";
    "decoder_model_merged_quantized.onnx" =
      moonshineFile "onnx/decoder_model_merged_quantized.onnx" "sha256-zJ881mmKNpxgCLQapgqj+zMi5/A8m98Z2Oa3IAr8pPM=";
    "tokenizer.json" =
      moonshineFile "tokenizer.json" "sha256-e5E0BL3QOa9HVngyGK9EQLwH+31tgljWd+NPlbPsQW8=";
  };
in
{
  services.voxtype = {
    enable = true;
    # TODO: UPSTREAM: voxtype-onnx 1.1.1 at the locked nixpkgs misses sqlite
    # and oniguruma in buildInputs. already fixed in newer nixpkgs, drop this
    # override on the next lock bump to get the cached build back
    package = pkgs.voxtype-onnx.overrideAttrs (old: {
      buildInputs = old.buildInputs ++ [
        pkgs.sqlite
        pkgs.oniguruma
      ];
    });

    # TODO: UPSTREAM: output hooks run via `sh -c`, but the home-manager unit's
    # PATH only has coreutils/which.
    environment.PATH = lib.makeBinPath [
      pkgs.bash
      pkgs.coreutils
      pkgs.which
    ];

    settings = {
      osd.enabled = false;
      hotkey.enabled = false;
      engine = "moonshine";
      moonshine.model = toString model;

      audio.feedback = {
        enabled = true;
        volume = 0.32;
      };

      output = {
        notification.on_transcription = false;
        pre_recording_command = "${swaymsg} mode voxtype_is_recording";
        pre_output_command = "${swaymsg} mode voxtype_is_typing";
        post_output_command = "${swaymsg} mode default";
      };
    };
  };
}
