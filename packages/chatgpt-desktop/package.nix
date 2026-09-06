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
, libusb1
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
  # Vendor ships only a rolling "latest" URL, no versioned releases -- if
  # nixos-rebuild starts failing with a hash mismatch, upstream has shipped a
  # new build: re-download and update both version and hash below.
  version = "26.901.41600";

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
    libusb1
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
  pname = "chatgpt-desktop";
  inherit version;

  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
    hash = "sha256-Fc9CKnfo8op1U9MYC4xyeEqZRDihQXhMgtcs3pPvync=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = runtimeLibs;

  # libqt5_shim.so/libqt6_shim.so are optional KDE tray/dialog integration,
  # unused outside a Qt desktop environment; the *.musl.node addons are
  # musl-libc builds of native Node modules that ship alongside the
  # glibc ones and are never loaded on NixOS.
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-x86_64.so.1"
  ];

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

    mkdir -p $out/opt/chatgpt $out/share/icons/hicolor/512x512/apps
    cp -r usr/lib/chatgpt/. $out/opt/chatgpt/
    install -Dm444 usr/share/pixmaps/chatgpt.png $out/share/icons/hicolor/512x512/apps/chatgpt.png

    makeWrapper $out/opt/chatgpt/ChatGPT $out/bin/chatgpt \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath runtimeLibs}:${addDriverRunpath.driverLink}/lib" \
      --suffix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --suffix VK_ADD_DRIVER_FILES : "${addDriverRunpath.driverLink}/share/vulkan/icd.d"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "chatgpt";
      exec = "chatgpt %U";
      icon = "chatgpt";
      desktopName = "ChatGPT";
      genericName = "AI assistant";
      comment = "ChatGPT by OpenAI";
      categories = [ "Utility" "Development" ];
      # http/https deliberately excluded: the vendor .desktop claims them too,
      # which makes ChatGPT a candidate default web browser and can hijack
      # xdg-open (see the OAuth-login-loop bug this caused). Only the app's
      # own deep-link scheme (used for the OAuth callback) belongs here.
      mimeTypes = [ "x-scheme-handler/codex" ];
      startupNotify = true;
    })
  ];

  meta = {
    description = "ChatGPT desktop app (Linux preview) by OpenAI";
    homepage = "https://developers.openai.com/codex/app";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "chatgpt";
  };
}
