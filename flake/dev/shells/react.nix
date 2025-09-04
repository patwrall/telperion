{ mkShell
, pkgs
, lib
, ...
}:
mkShell {
  packages =
    with pkgs;
    [
      nodejs_22
      pnpm
      yarn
      bun
      typescript-language-server
      typescript
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      react-native-debugger
    ];

  shellHook = ''

    echo 🔨 React DevShell


  '';
}
