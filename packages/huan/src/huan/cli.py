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

    sub.add_parser("compact", help="compact yesterday's events into a daily note")

    eval_parser = sub.add_parser("eval", help="run the quality eval harness")
    eval_parser.add_argument("which", choices=["routing", "convo", "all"])
    eval_parser.add_argument("--config", default=None, help="path to config JSON")

    shellev = sub.add_parser("shellev", help="report a shell command event (fish hook)")
    shellev.add_argument("phase", choices=["start", "end"])
    shellev.add_argument("id")
    shellev.add_argument("exit")
    shellev.add_argument("duration")
    shellev.add_argument("cwd")
    shellev.add_argument("cmd", nargs=argparse.REMAINDER)

    ctl_parser = sub.add_parser("ctl", help="send a command to the running daemon")
    ctl_parser.add_argument(
        "command",
        choices=[
            "status",
            "ptt-start",
            "ptt-stop",
            "converse",
            "sleep",
            "wake",
            "toggle",
            "text",
            "say",
            "context",
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
    if args.mode == "eval":
        from .evals import run as eval_run

        return eval_run(args.which, args.config)
    if args.mode == "compact":
        from .compact import run as compact_run

        return compact_run(None)
    if args.mode == "shellev":
        data = {
            "phase": args.phase,
            "id": args.id,
            "cwd": args.cwd,
            "cmd": " ".join(args.cmd)[:300],
        }
        if args.phase == "end":
            try:
                data["exit"] = int(args.exit)
                data["duration"] = float(args.duration)
            except ValueError:
                pass
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
                sock.connect(str(Config().control_socket))
                sock.sendall(
                    (json.dumps({"cmd": "event", "data": data}) + "\n").encode()
                )
        except OSError:
            pass  # daemon down: shell must never notice
        return 0
    return _ctl(args)


if __name__ == "__main__":
    sys.exit(main())
