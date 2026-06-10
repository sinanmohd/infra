{
  stdenvNoCC,
  lib,
  makeWrapper,
  bash,
}:

stdenvNoCC.mkDerivation {
  pname = "nnvim";
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

  meta = {
    description = "Helper to cow edit nix store files";
    homepage = "https://www.sinanmohd.com";
    license = lib.licenses.gpl3;
    platforms = lib.platforms.unix;
    mainProgram = "nnvim";
    maintainers = with lib.maintainers; [ sinanmohd ];
  };
}
