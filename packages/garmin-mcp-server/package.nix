{ lib
, python3
, fetchFromGitHub
, ...
}:
python3.pkgs.buildPythonApplication rec {
  pname = "garmin-mcp";
  version = "0-unstable-2026-09-06";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "taxuspt";
    repo = "garmin_mcp";
    rev = "e8554bcd761a4494dc12a98461224bb3dcf1fbc5";
    hash = "sha256-6ynRwD1qKkeoCGlLUueXHdQXrfPmahWDVhfFcRpg6cU=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    python-dotenv
    garminconnect
    requests
    mcp
    fitparse
  ];

  # Upstream pins garminconnect==0.3.2 and requests==2.33.0; nixpkgs carries
  # newer point releases of both.
  pythonRelaxDeps = [ "garminconnect" "requests" ];
  doCheck = false;

  meta = with lib; {
    description = "MCP server exposing Garmin Connect fitness and health data";
    homepage = "https://github.com/taxuspt/garmin_mcp";
    license = licenses.mit;
    mainProgram = "garmin-mcp";
    platforms = platforms.unix;
  };
}
