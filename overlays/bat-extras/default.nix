_:
_final: prev: {
  bat-extras = prev.bat-extras.overrideAttrs (_oldAttrs: {
    doCheck = false;
    doInstallCheck = false;
  });
}
