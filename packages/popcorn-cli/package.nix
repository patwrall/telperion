{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, ...
}:
rustPlatform.buildRustPackage rec {
  pname = "popcorn-cli";
  version = "1.3.29";

  src = fetchFromGitHub {
    owner = "gpu-mode";
    repo = "popcorn-cli";
    rev = "v${version}";
    hash = "sha256-ISetaKF8Uwc0vRyP0sM7qOwRzricRc1sB5SwXRt5xS8=";
  };

  cargoHash = "sha256-hVmsLNBZLXP6fqc30Q6ZAVYlLTIJKWujNStuEPFDeYk=";

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
