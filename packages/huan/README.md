# huan

A voice agent for the telperion desktop, named after the hound of Valinor. Wake
it with **"hey huan"** (custom-trained openWakeWord model) or hold **SUPER+V**;
either one barges in over its own speech.

## Architecture: three tiers, one voice

```
mic ── Silero VAD ── faster-whisper (CUDA) ── transcript
                                                 │
              ┌───────────── routing ────────────┤
              │                                  │
        regex fast path                    3B router (llama.cpp)
        workspace/close/media/sleep        conversational phrasings
        <10ms dispatch                     ~100ms
              │                                  │
              └── everything else ───────────────┘
                            │
                    THE BRAIN (persistent Claude process, haiku)
                    one continuous conversation, live world-state
                    per turn, MCP tools: dispatch, fullscreen,
                    media, remember_fact, recall_days, delegate_task
                            │ delegate_task
                    THE AGENT (Claude CLI headless, sonnet)
                    reads files, runs commands, researches;
                    result summarized to 1-2 spoken sentences
```

Spoken replies: ElevenLabs websocket streaming (piper offline fallback),
sentence-chunked as they generate, with cached "hmm" fillers covering
think-time. After any reply the mic stays hot for 30s — one wake word per
conversation, not per sentence.

## Awareness

The world-state blob (inspect: `huan ctl context`) carries: time, workspace,
focused window, running/finished shell commands (fish preexec/postexec hook),
now-playing (MPRIS), recent desktop notifications (D-Bus), background-task
truth, and long-term memory facts. Grounding rule: state overrides everything
the models remember.

Proactivity: long commands are announced when they finish; fail loops (3+
consecutive, or repeated long-command failures) trigger an unprompted offer to
investigate. Rate-limited, silenced while sleeping.

## Persistence

SQLite at `~/.local/share/huan/huan.db`: conversation history, agent and brain
session ids (memory survives reboots), ambient events. `memory.md` beside it
holds voice-written facts ("remember that ...") — plain markdown, edit freely. A
04:00 timer compacts each day's events into a digest line (`recall_days`
retrieves them) and prunes raw data.

## Operations

- `huan ctl status|context|sleep|wake|toggle|text|say` — poke the daemon
- `huan eval routing|convo|all` — the quality harness; trend in
  `~/.local/share/huan/evals.jsonl`, full reports beside it
- `huan compact` — manual compaction run
- SUPER+SHIFT+V or "go to sleep" — free the GPU (wake word stays on CPU)
- `journalctl --user -u huan -f` — per-stage latency on every request
- tests run in the package checkPhase: a failing test is a failing build

Configuration lives in `modules/home/services/huan`; the ElevenLabs API key is a
runtime file (`~/.config/huan/elevenlabs-key`), never in the repo.

## Known issues / ideas

- Short garbled fragments (STT mishears a couple words, e.g. "buds", "team
  marks") still get passed straight to routing instead of triggering a
  clarifying question — a confidence threshold that asks for a repeat would cut
  down on wrong guesses.
- Media-pause-at-ears-on (see `a52996c`) only pauses one MPRIS player; other
  concurrent audio sources (browser tab, terminal bell) can still bleed into the
  mic during converse mode.
- `silence_ms` (config.py, default 450ms) cuts capture on any pause that long,
  including mid-sentence thinking pauses — bump to ~650ms as a first pass,
  validate with `huan eval convo`. Real fix for "thinking out loud" pauses is a
  two-stage endpointing: on hitting silence_ms, run a partial transcript through
  the existing 3B router asking whether the utterance sounds finished; if not,
  extend the window instead of cutting. Only costs extra latency on
  already-ambiguous pauses.
- Conversational turns ("the brain", haiku-class persistent process in brain.py)
  take ~4-5s from end of capture to first spoken sentence even though STT
  (<250ms) and TTS-first-audio (440-900ms) are both fast — streaming is already
  wired up (brain.py flushes per-sentence), so the gap is genuine model
  think-time. Two unverified suspects worth profiling: (1) whether
  extended-thinking/reasoning is on by default for that subprocess and adding
  hidden latency before the first sentence, and (2) accumulated conversation
  history cost as the persistent session grows toward its max_turns=8 rotation.
