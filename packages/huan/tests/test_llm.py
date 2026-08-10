import json

import pytest
from huan import llm
from hypothesis import given
from hypothesis import strategies as st


def decision(action, workspace=None, task=None):
    return json.dumps({"action": action, "workspace": workspace, "task": task})


class TestClassify:
    async def test_workspace(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("workspace", 3))])
        intent = await llm.classify(http, "http://x", "third one please")
        assert intent.action == "workspace" and intent.arg == 3

    async def test_workspace_out_of_range_rejected(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("workspace", 42))])
        assert await llm.classify(http, "http://x", "x") is None

    async def test_workspace_null_rejected(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("workspace", None))])
        assert await llm.classify(http, "http://x", "x") is None

    async def test_delegate_carries_task(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("delegate", task="dig into the build"))])
        intent = await llm.classify(http, "http://x", "why is it broken")
        assert intent.action == "delegate" and intent.task == "dig into the build"

    async def test_remember_carries_fact(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("remember", task="likes tea"))])
        intent = await llm.classify(http, "http://x", "remember I like tea")
        assert intent.action == "remember" and intent.task == "likes tea"

    @pytest.mark.parametrize("action", ["details", "cancel"])
    async def test_bare_actions(self, fake_http, chat_reply, action):
        http = fake_http([chat_reply(decision(action))])
        intent = await llm.classify(http, "http://x", "x")
        assert intent.action == action

    @pytest.mark.parametrize(
        ("action", "text"),
        [
            ("close-window", "make it go away"),
            ("sleep", "time to sleep"),
            ("wake", "wake back up"),
        ],
    )
    async def test_acked_actions(self, fake_http, chat_reply, action, text):
        http = fake_http([chat_reply(decision(action))])
        intent = await llm.classify(http, "http://x", text)
        assert intent.action == action and intent.ack

    async def test_none_maps_to_no_intent(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("none"))])
        assert await llm.classify(http, "http://x", "hello") is None

    async def test_undo_guard_overrides_cancel(self, fake_http, chat_reply):
        # eval-caught: 3B misroutes "okay undo that" to cancel
        http = fake_http([chat_reply(decision("cancel"))])
        assert await llm.classify(http, "http://x", "okay undo that") is None

    async def test_wake_guard_requires_wake_words(self, fake_http, chat_reply):
        # eval-caught: 3B misroutes "good morning" to wake
        http = fake_http([chat_reply(decision("wake"))])
        assert await llm.classify(http, "http://x", "good morning") is None

    async def test_real_wake_passes_guard(self, fake_http, chat_reply):
        http = fake_http([chat_reply(decision("wake"))])
        intent = await llm.classify(http, "http://x", "wake up buddy")
        assert intent is not None and intent.action == "wake"

    async def test_503_retries_then_succeeds(self, fake_http, chat_reply, monkeypatch):
        # regression: llama-server answers 503 while reloading after the
        # sleep toggle; commands in that window must not be dropped
        sleeps = []

        async def fast_sleep(s):
            sleeps.append(s)

        monkeypatch.setattr(llm.asyncio, "sleep", fast_sleep)
        http = fake_http(
            [
                chat_reply("", status_code=503),
                chat_reply("", status_code=503),
                chat_reply(decision("workspace", 2)),
            ]
        )
        intent = await llm.classify(http, "http://x", "workspace two")
        assert intent.arg == 2
        assert len(sleeps) == 2

    async def test_503_gives_up_after_four_attempts(
        self, fake_http, chat_reply, monkeypatch
    ):
        async def fast_sleep(s):
            pass

        monkeypatch.setattr(llm.asyncio, "sleep", fast_sleep)
        http = fake_http([chat_reply("", status_code=503) for _ in range(4)])
        import httpx

        with pytest.raises(httpx.HTTPStatusError):
            await llm.classify(http, "http://x", "x")
        assert len(http.requests) == 4


class TestSchema:
    def test_schema_actions_match_parser(self):
        parsed_actions = {
            "workspace",
            "close-window",
            "sleep",
            "wake",
            "delegate",
            "details",
            "cancel",
            "remember",
            "none",
        }
        assert set(llm.SCHEMA["properties"]["action"]["enum"]) == parsed_actions

    def test_prompt_mentions_every_action(self):
        for action in llm.SCHEMA["properties"]["action"]["enum"]:
            assert f'"{action}"' in llm.SYSTEM_PROMPT


class TestSpeechShaping:
    async def test_respond_strips_quotes(self, fake_http, chat_reply):
        http = fake_http([chat_reply('"On three."')])
        line = await llm.respond(http, "http://x", "said", "did", "ctx")
        assert line == "On three."

    async def test_summarize_truncates_huge_reports(self, fake_http, chat_reply):
        http = fake_http([chat_reply("Short summary.")])
        await llm.summarize(http, "http://x", "task", "x" * 50_000)
        _, kwargs = http.requests[0]
        sent = kwargs["json"]["messages"][1]["content"]
        assert len(sent) < 10_000


@given(
    action=st.sampled_from(list("abcdefgh")) | st.none(),
    workspace=st.integers(-5, 20) | st.none() | st.text(max_size=3),
)
async def test_classify_tolerates_arbitrary_decisions(action, workspace):
    """Whatever JSON the model emits within schema-ish shape, classify
    must return None or a valid Intent — never crash."""

    class OneShot:
        async def post(self, url, **kwargs):
            import json as j

            class R:
                status_code = 200

                def raise_for_status(self):
                    pass

                def json(self):
                    return {
                        "choices": [
                            {
                                "message": {
                                    "content": j.dumps(
                                        {"action": action, "workspace": workspace}
                                    )
                                }
                            }
                        ]
                    }

            return R()

    intent = await llm.classify(OneShot(), "http://x", "anything")
    if intent is not None and intent.action == "workspace":
        assert 1 <= intent.arg <= 10
