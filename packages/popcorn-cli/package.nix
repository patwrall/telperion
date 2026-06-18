{ lib
, rustPlatform
, fetchFromGitHub
, pkg-config
, openssl
, ...
}:
rustPlatform.buildRustPackage rec {
  pname = "popcorn-cli";
  version = "1.3.13";

  src = fetchFromGitHub {
    owner = "gpu-mode";
    repo = "popcorn-cli";
    rev = "v${version}";
    hash = "sha256-A2cBI1deDK2N34X1dZ8GlmuswOJvCMW8ZAHhJ4ScQpY=";
  };

  cargoHash = "sha256-uaorpgeaHvIvsHi1H6qE743JnNwmTAGVd6oiKbyCNRc=";

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
