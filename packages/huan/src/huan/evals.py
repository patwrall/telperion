"""Eval harness: measured quality instead of vibes.

`huan eval routing` scores the intent path (regex + 3B router) against
the corpus. `huan eval convo` runs scripted scenarios against a fresh
brain wired to MOCK tools (the desktop is never touched), then has a
stronger model judge the transcripts against a rubric. Results append
to ~/.local/share/huan/evals.jsonl so quality is a trend, not a feeling.
"""

import asyncio
import datetime
import json
import logging
import os
import sys
import tempfile
from pathlib import Path

from . import brain as brain_mod
from . import intent, llm
from .config import Config
from .evals_corpus import JUDGE_RUBRIC, ROUTING_CASES, SCENARIOS

log = logging.getLogger("huan.evals")


# -- routing -----------------------------------------------------------------


async def eval_routing(config: Config) -> dict:
    import httpx

    http = httpx.AsyncClient()
    results = []
    for case in ROUTING_CASES:
        got = intent.classify(case["text"])
        source = "regex"
        if got is None and case.get("source") != "regex" and config.llama_url:
            try:
                got = await llm.classify(http, config.llama_url, case["text"])
                source = "llm"
            except Exception as exc:
                results.append({**case, "got": f"error: {exc}", "ok": False})
                continue
        # mirror the daemon's status guard
        action = got.action if got is not None else "none"
        if action == "delegate" and intent.is_status_question(case["text"]):
            action = "none"
        ok = action == case["expect"] and (
            case.get("arg") is None or (got is not None and got.arg == case["arg"])
        )
        results.append({**case, "got": action, "source": source, "ok": ok})
    await http.aclose()

    passed = sum(r["ok"] for r in results)
    return {
        "kind": "routing",
        "passed": passed,
        "total": len(results),
        "accuracy": round(passed / len(results), 3),
        "failures": [r for r in results if not r["ok"]],
    }


# -- conversation ------------------------------------------------------------


def _mock_mcp_config(log_path: str) -> str:
    config = {
        "mcpServers": {
            "huan": {
                "command": os.path.abspath(sys.argv[0]),
                "args": ["mcp"],
                "env": {"HUAN_MCP_MOCK": "1", "HUAN_MCP_MOCK_LOG": log_path},
            }
        }
    }
    fd, path = tempfile.mkstemp(suffix=".json", prefix="huan-eval-mcp-")
    with os.fdopen(fd, "w") as f:
        json.dump(config, f)
    return path


def _tools_match(expected: list, called: list) -> bool:
    """Expected tools must appear in order; extra speak calls are fine.
    With no expectations, any *acting* tool call is a failure but
    speaking isn't."""
    acting = [t for t in called if t != "speak"]
    if not expected:
        return not acting
    it = iter(acting)
    return all(any(tool == want for tool in it) for want in expected)


async def eval_convo(config: Config) -> dict:
    scenario_results = []
    for scenario in SCENARIOS:
        tool_log = tempfile.mkstemp(suffix=".jsonl", prefix="huan-eval-tools-")[1]
        mcp_config = _mock_mcp_config(tool_log)
        brain = brain_mod.Brain(
            config.agent_cmd, config.brain_model, mcp_config=mcp_config
        )
        transcript = []
        try:
            for turn in scenario["turns"]:
                reply = await brain.ask(turn["user"], turn["state"], timeout_s=60)
                transcript.append({**turn, "reply": reply})
        except Exception as exc:
            transcript.append({"error": str(exc)})
        finally:
            await brain.stop()
        tools_called = [
            json.loads(line)["tool"]
            for line in Path(tool_log).read_text().splitlines()
            if line.strip()
        ]
        tools_ok = _tools_match(scenario["expect_tools"], tools_called)
        judged = await judge(scenario, transcript, tools_called, config)
        scenario_results.append(
            {
                "name": scenario["name"],
                "transcript": transcript,
                "tools_called": tools_called,
                "tools_expected": scenario["expect_tools"],
                "tools_ok": tools_ok,
                "scores": judged,
            }
        )
        log.info(
            "scenario %s: tools_ok=%s overall=%s",
            scenario["name"],
            tools_ok,
            judged.get("overall"),
        )

    overalls = [
        r["scores"].get("overall")
        for r in scenario_results
        if isinstance(r["scores"].get("overall"), (int, float))
    ]
    return {
        "kind": "convo",
        "scenarios": scenario_results,
        "mean_overall": round(sum(overalls) / len(overalls), 2) if overalls else None,
        "tools_ok": sum(r["tools_ok"] for r in scenario_results),
        "total": len(scenario_results),
    }


async def judge(scenario, transcript, tools_called, config: Config) -> dict:
    prompt = (
        f"{JUDGE_RUBRIC}\n"
        f"Scenario-specific requirement: {scenario['rubric_extra']}\n"
        f"Tools the assistant called: {tools_called or 'none'} "
        f"(expected: {scenario['expect_tools'] or 'none'})\n\n"
        f"Conversation (state blocks were visible to the assistant):\n"
        f"{json.dumps(transcript, indent=1)}\n\n"
        'Respond with ONLY a JSON object: {"grounded": n, "natural": n, '
        '"brevity": n, "agency": n, "no_leaks": n, "overall": n, "note": "..."}'
    )
    proc = await asyncio.create_subprocess_exec(
        config.agent_cmd,
        "-p",
        "--output-format",
        "json",
        "--model",
        "sonnet",
        "--max-turns",
        "1",
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.DEVNULL,
    )
    stdout, _ = await asyncio.wait_for(proc.communicate(prompt.encode()), timeout=120)
    try:
        payload = json.loads(stdout.decode())
        if isinstance(payload, list):
            payload = [p for p in payload if p.get("type") == "result"][-1]
        text = payload.get("result", "")
        start, end = text.find("{"), text.rfind("}")
        return json.loads(text[start : end + 1])
    except Exception as exc:
        return {"error": f"judge unparsable: {exc}"}


# -- entry -------------------------------------------------------------------


def _trend_path() -> Path:
    base = Path(os.environ.get("XDG_DATA_HOME", "~/.local/share")).expanduser()
    return base / "huan" / "evals.jsonl"


def run(which: str, config_path: str | None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    config = Config.load(config_path)
    reports = []
    if which in ("routing", "all"):
        reports.append(asyncio.run(eval_routing(config)))
    if which in ("convo", "all"):
        if not config.agent_cmd:
            config.agent_cmd = "claude"
        reports.append(asyncio.run(eval_convo(config)))

    trend = _trend_path()
    trend.parent.mkdir(parents=True, exist_ok=True)
    reports_dir = trend.parent / "eval-reports"
    reports_dir.mkdir(exist_ok=True)
    stamp = datetime.datetime.now().isoformat(timespec="seconds")
    failed = False
    with open(trend, "a") as f:
        for report in reports:
            summary = {
                k: v for k, v in report.items() if k not in ("failures", "scenarios")
            }
            f.write(json.dumps({"ts": stamp, **summary}) + "\n")
            full = reports_dir / f"{stamp}-{report['kind']}.json"
            full.write_text(json.dumps(report, indent=1))
            print(json.dumps(report, indent=1)[:4000])
            print(f"full report: {full}")
            if report["kind"] == "routing" and report["accuracy"] < 1.0:
                failed = True
    print(f"\ntrend appended to {trend}")
    return 1 if failed else 0
