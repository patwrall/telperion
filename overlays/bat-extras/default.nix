{ inputs
, ...
}:
final: prev: {
    bat-extras = prev.bat-extras.overrideAttrs (oldAttrs: {
    doCheck = false;
    doInstallCheck = false;
  });
}
