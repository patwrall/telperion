{ lib
, python3
, fetchurl
, ...
}:
python3.pkgs.buildPythonApplication rec {
  pname = "canvas-mcp";
  version = "1.4.0";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/2d/25/148b9fe001f36707ee34d128f8bec25e53f883a33f81bf40ba4c7a10143d/canvas_mcp-${version}.tar.gz";
    hash = "sha256-9rCD82ZezgctDXf3PxFwTCjY3rrX3mlL1vMOSXWQiU8=";
  };

  build-system = with python3.pkgs; [ hatchling ];

  dependencies = with python3.pkgs; [
    mcp
    httpx
    python-dotenv
    pydantic
    python-dateutil
    uvicorn
  ];

  pythonRelaxDeps = [ "pydantic" ];
  doCheck = false;

  meta = with lib; {
    description = "MCP server for Canvas LMS — read courses, assignments, grades, and announcements";
    homepage = "https://github.com/vishalsachdev/canvas-mcp";
    license = licenses.mit;
    mainProgram = "canvas-mcp-server";
    platforms = platforms.unix;
  };
}
