from huan import intent
from huan.evals import _tools_match
from huan.evals_corpus import JUDGE_RUBRIC, ROUTING_CASES, SCENARIOS


class TestToolMatching:
    def test_exact_order(self):
        assert _tools_match(["a", "b"], ["a", "b"])

    def test_extra_speak_ignored(self):
        assert _tools_match(["fullscreen_toggle"], ["speak", "fullscreen_toggle"])

    def test_missing_expected_fails(self):
        assert not _tools_match(["delegate_task"], ["speak"])

    def test_wrong_order_fails(self):
        assert not _tools_match(["a", "b"], ["b", "a"])

    def test_no_expectations_but_acted_fails(self):
        assert not _tools_match([], ["close_focused_window"])

    def test_no_expectations_speaking_ok(self):
        assert _tools_match([], ["speak"])
        assert _tools_match([], [])


class TestCorpusIntegrity:
    def test_regex_cases_pass_offline(self):
        """Every corpus case marked source=regex is part of the build gate."""
        for case in ROUTING_CASES:
            if case.get("source") != "regex":
                continue
            got = intent.classify(case["text"])
            action = got.action if got is not None else "none"
            assert action == case["expect"], f"{case['text']!r} -> {action}"
            if case.get("arg") is not None:
                assert got.arg == case["arg"], case["text"]

    def test_expected_actions_are_valid(self):
        valid = {
            "workspace",
            "close-window",
            "media",
            "sleep",
            "wake",
            "cancel",
            "none",
        }
        for case in ROUTING_CASES:
            assert case["expect"] in valid, case

    def test_scenarios_well_formed(self):
        for scenario in SCENARIOS:
            assert scenario["name"] and scenario["turns"]
            assert "rubric_extra" in scenario and "expect_tools" in scenario
            for turn in scenario["turns"]:
                assert turn["user"] and turn["state"]

    def test_rubric_covers_the_transcript_failures(self):
        # the judge must penalize exactly what the user complained about
        assert "no_leaks" in JUDGE_RUBRIC
        assert "agency" in JUDGE_RUBRIC
        assert "grounded" in JUDGE_RUBRIC
