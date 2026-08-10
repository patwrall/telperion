{ lib
, python3Packages
, piper-tts
, ctranslate2
, withCuda ? false
, ...
}:
let
  # nixpkgs' cached ctranslate2 is CPU-only; the CUDA variant (needed for
  # faster-whisper on the GPU) is a from-source rebuild, so it's opt-in.
  faster-whisper =
    if withCuda then
      python3Packages.faster-whisper.override
        {
          ctranslate2 = python3Packages.ctranslate2.override {
            ctranslate2-cpp = ctranslate2.override {
              withCUDA = true;
              withCuDNN = true;
            };
          };
        }
    else
      python3Packages.faster-whisper;
in
python3Packages.buildPythonApplication {
  pname = "huan";
  version = "0.1.0";
  pyproject = true;

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./pyproject.toml
      ./src
    ];
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = [
    faster-whisper
    python3Packages.httpx
    python3Packages.numpy
    python3Packages.sounddevice
    python3Packages.websockets
    python3Packages.wyoming
  ];

  # piper is invoked by name at runtime for TTS synthesis
  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ piper-tts ]}"
  ];

  meta = {
    description = "Fast/slow voice agent daemon for Hyprland (reflex tier of the huan desktop agent)";
    license = lib.licenses.mit;
    mainProgram = "huan";
    platforms = lib.platforms.linux;
  };
}
