{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, ...
}:
rustPlatform.buildRustPackage rec {
  pname = "popcorn-cli";
  version = "1.1.44";

  src = fetchFromGitHub {
    owner = "gpu-mode";
    repo = "popcorn-cli";
    rev = "v${version}";
    hash = "sha256-jQzPvMP8BJd3V78vGbRQrF4CBmis/DshUtwNazBaiO4=";
  };

  cargoHash = "sha256-eMhhoONOUNRDx+vxzkcv9AE2XE3mQ8XLH2QqlgDbXeI=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  # OpenSSL is required for network operations
  OPENSSL_NO_VENDOR = 1;

  meta = with lib; {
    description = "A command-line interface tool for submitting solutions to the Popcorn Discord Bot";
    homepage = "https://github.com/gpu-mode/popcorn-cli";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "popcorn-cli";
    platforms = platforms.unix;
  };
}

