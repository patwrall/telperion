{ inputs
, ...
}:
_final: prev: {
  inherit (inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system})
    zen-browser
    zen-browser-unwrapped
    ;
}
