{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, makeDesktopItem
, copyDesktopItems
, addDriverRunpath
, gtk3
, libnotify
, libsecret
, libuuid
, nss
, nspr
, at-spi2-core
, at-spi2-atk
, atk
, cairo
, cups
, dbus
, expat
, fontconfig
, freetype
, gdk-pixbuf
, glib
, libdrm
, mesa
, alsa-lib
, systemdLibs
, libxkbcommon
, pango
, libpulseaudio
, wayland
, xdg-utils
, vulkan-loader
, libglvnd
, libxcb
, libxshmfence
, libx11
, libxcomposite
, libxdamage
, libxext
, libxfixes
, libxrandr
, libxtst
, libxscrnsaver
, libxcursor
, libxi
, libxrender
, ...
}:

let
  # The x.ai/bot download button hides behind a rolling redirect; this is the
  # versioned artifact it resolves to. To bump: follow
  # https://api2.cursor.sh/updates/download/stable/linux-x64/grok-bot-fb0a830618be0c54
  # and take the final URL.
  version = "0.47.0";

  runtimeLibs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    libxrender
    libxscrnsaver
    libxshmfence
    libxtst
    libxi
    libxcursor
    mesa
    nspr
    nss
    pango
    systemdLibs
    vulkan-loader
    wayland
    stdenv.cc.cc.lib
  ];
in
stdenv.mkDerivation {
  pname = "grok-bot";
  inherit version;

  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/c1e7d7a46549956d25f53e9c0b9f59666e03aa3a/linux/x64/grok-bot_${version}_amd64.deb";
    hash = "sha256-EcoPUaU1uXr1GjUq35wPns0uGwQwpprpRRtoinoGWAg=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  unpackPhase = ''
    runHook preUnpack
    ar x $src
    tar xf data.tar.xz
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt/grok-bot
    cp -r "opt/Grok Bot/." $out/opt/grok-bot/

    for icon in usr/share/icons/hicolor/*/apps/grok-bot.png; do
      size=$(basename "$(dirname "$(dirname "$icon")")")
      install -Dm444 "$icon" $out/share/icons/hicolor/$size/apps/grok-bot.png
    done

    makeWrapper $out/opt/grok-bot/grok-bot $out/bin/grok-bot \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:${addDriverRunpath.driverLink}/lib" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --suffix VK_ADD_DRIVER_FILES : "${addDriverRunpath.driverLink}/share/vulkan/icd.d"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "grok-bot";
      exec = "grok-bot %U";
      icon = "grok-bot";
      desktopName = "Grok Bot";
      genericName = "AI assistant";
      comment = "Grok Bot desktop agent by xAI";
      categories = [ "Utility" "Development" ];
      # Deep-link schemes the app registers for its OAuth callback ("sand" is
      # the vendor's internal codename, still emitted by the login flow).
      mimeTypes = [ "x-scheme-handler/grokbot" "x-scheme-handler/sand" ];
      startupNotify = true;
      startupWMClass = "grok-bot";
    })
  ];

  meta = {
    description = "Grok Bot desktop agent by xAI";
    homepage = "https://x.ai/bot";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok-bot";
  };
}
