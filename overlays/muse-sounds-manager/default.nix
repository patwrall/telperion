_:
final: prev: {
  muse-sounds-manager = prev.muse-sounds-manager.overrideAttrs (oldAttrs: {
    nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
    postInstall = (oldAttrs.postInstall or "") + ''
      mkdir -p $out/lib
      mv $out/bin/lib*.so $out/lib/
      wrapProgram $out/bin/muse-sounds-manager \
        --prefix LD_LIBRARY_PATH : $out/lib
    '';
  });
}
