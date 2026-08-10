import argparse
import json
import socket
import sys

from .config import Config


def _ctl(args) -> int:
    request = {"cmd": args.command}
    if args.text:
        request["text"] = " ".join(args.text)
    sock_path = str(Config().control_socket)
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.connect(sock_path)
            sock.sendall((json.dumps(request) + "\n").encode())
            response = sock.makefile().readline()
    except (ConnectionRefusedError, FileNotFoundError):
        print(f"huan daemon not running (no socket at {sock_path})", file=sys.stderr)
        return 1
    print(response.strip())
    return 0 if json.loads(response).get("ok") else 1


def main() -> int:
    parser = argparse.ArgumentParser(prog="huan")
    sub = parser.add_subparsers(dest="mode", required=True)

    daemon_parser = sub.add_parser("daemon", help="run the voice agent daemon")
    daemon_parser.add_argument("--config", default=None, help="path to config JSON")

    sub.add_parser("mcp", help="run the MCP server exposing desktop primitives")

    ctl_parser = sub.add_parser("ctl", help="send a command to the running daemon")
    ctl_parser.add_argument(
        "command",
        choices=[
            "status",
            "ptt-start",
            "ptt-stop",
            "sleep",
            "wake",
            "toggle",
            "text",
            "say",
        ],
    )
    ctl_parser.add_argument("text", nargs="*", help="text for the text/say commands")

    args = parser.parse_args()
    if args.mode == "daemon":
        from .daemon import run

        run(args.config)
        return 0
    if args.mode == "mcp":
        from .mcp_server import main as mcp_main

        mcp_main()
        return 0
    return _ctl(args)


if __name__ == "__main__":
    sys.exit(main())
