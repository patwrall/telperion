{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, cmake
, installShellFiles
, writableTmpDirAsHomeHook
, alsa-lib
, libpulseaudio
, portaudio
, libjack2
, SDL2
, gst_all_1
, dbus
, fontconfig
, libsixel
, withStreaming ? true
, withDaemon ? true
, withAudioBackend ? "rodio"
, withMediaControl ? true
, withImage ? true
, withNotify ? true
, withSixel ? true
, withFuzzy ? true
, stdenv
, makeBinaryWrapper
, nix-update-script
, ...
}:

let
  audioBackends = [
    ""
    "alsa"
    "pulseaudio"
    "rodio"
    "portaudio"
    "jackaudio"
    "rodiojack"
    "sdl"
    "gstreamer"
  ];
in
assert lib.assertOneOf "withAudioBackend" withAudioBackend audioBackends;

rustPlatform.buildRustPackage {
  pname = "spotify-player";
  version = "unstable-main";

  src = fetchFromGitHub {
    owner = "aome510";
    repo = "spotify-player";
    rev = "bd38dd05a3c52107f76665dc88002e5a0815d095";
    hash = "sha256-DCIZHAfI3x9I6j2f44cDcXbMpZbNXJ62S+W19IY6Qus=";
  };

  cargoHash = "sha256-fNDztl0Vxq2fUzc6uLNu5iggNRnRB2VxzWm+AlSaoU0=";

  nativeBuildInputs = [
    pkg-config
    cmake
    rustPlatform.bindgenHook
    installShellFiles
    writableTmpDirAsHomeHook
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin [ makeBinaryWrapper ];

  buildInputs = [ openssl dbus fontconfig ]
    ++ lib.optionals withSixel [ libsixel ]
    ++ lib.optionals (withAudioBackend == "alsa") [ alsa-lib ]
    ++ lib.optionals (withAudioBackend == "pulseaudio") [ libpulseaudio ]
    ++ lib.optionals (withAudioBackend == "rodio" && stdenv.isLinux) [ alsa-lib ]
    ++ lib.optionals (withAudioBackend == "portaudio") [ portaudio ]
    ++ lib.optionals (withAudioBackend == "jackaudio") [ libjack2 ]
    ++ lib.optionals (withAudioBackend == "rodiojack") [ alsa-lib libjack2 ]
    ++ lib.optionals (withAudioBackend == "sdl") [ SDL2 ]
    ++ lib.optionals (withAudioBackend == "gstreamer") (with gst_all_1; [
    gstreamer
    gst-devtools
    gst-plugins-base
    gst-plugins-good
  ]);

  buildNoDefaultFeatures = true;

  buildFeatures = [ ]
    ++ lib.optional (withAudioBackend != "") "${withAudioBackend}-backend"
    ++ lib.optional withMediaControl "media-control"
    ++ lib.optional withImage "image"
    ++ lib.optional withDaemon "daemon"
    ++ lib.optional withNotify "notify"
    ++ lib.optional withStreaming "streaming"
    ++ lib.optional withSixel "sixel"
    ++ lib.optional withFuzzy "fzf";

  postInstall = ''
    ${lib.optionalString (stdenv.buildPlatform.canExecute stdenv.hostPlatform) ''
      installShellCompletion --cmd spotify_player \
        --bash <($out/bin/spotify_player generate bash) \
        --fish <($out/bin/spotify_player generate fish) \
        --zsh <($out/bin/spotify_player generate zsh)
    ''}

    ${lib.optionalString (stdenv.isDarwin && withSixel) ''
      wrapProgram $out/bin/spotify_player \
        --prefix DYLD_LIBRARY_PATH : "${lib.makeLibraryPath [ libsixel ]}"
    ''}
  '';

  passthru.updateScript = nix-update-script { };

  meta = with lib; {
    description =
      "A terminal Spotify player that has feature parity with the official client";
    homepage = "https://github.com/aome510/spotify-player";
    changelog =
      "https://github.com/aome510/spotify-player/commits/main";
    mainProgram = "spotify_player";
    license = licenses.mit;
    maintainers = with maintainers; [ dit7ya xyven1 _71zenith caperren ];
  };
}
