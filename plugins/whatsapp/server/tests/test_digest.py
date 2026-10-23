"""Digest tests against a messages.db written by the bridge's own MessageStore."""
import os
import subprocess
import sys
from datetime import datetime, timezone

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from digest import _parse_ts, digest  # noqa: E402

BRIDGE = os.path.join(os.path.dirname(__file__), "..", "..", "bridge")


@pytest.fixture(scope="module")
def wa_home(tmp_path_factory):
    home = tmp_path_factory.mktemp("wa")
    subprocess.run(
        ["go", "test", "-run", "TestWriteFixture", "-count=1", "."],
        cwd=BRIDGE, env={**os.environ, "FIXTURE_HOME": str(home)}, check=True, capture_output=True,
    )
    return str(home)


def by_name(result):
    return {c["name"]: c for c in result["allowlisted_chats_with_activity"]}


def test_parse_ts_formats():
    assert _parse_ts("2026-10-23 18:37:13+05:30").utcoffset().total_seconds() == 19800
    assert _parse_ts("2026-10-23 18:37:13.123456789+05:30").microsecond == 123456
    assert _parse_ts("garbage") is None
    assert _parse_ts("") is None


def test_window_counts_and_unanswered(wa_home):
    chats = by_name(digest(wa_home, since_hours=24, keywords=[]))
    north, south = chats["Field Ops North"], chats["Field Ops South"]
    assert north["messages"] == 4
    assert north["unanswered_since_my_last_reply"] == 2
    assert north["i_have_replied_ever"] is True
    assert south["messages"] == 2  # the 48h-old message is outside the window
    assert south["media"] == 1
    assert south["unanswered_since_my_last_reply"] == 2
    assert south["i_have_replied_ever"] is False


def test_keyword_hits(wa_home):
    north = by_name(digest(wa_home, keywords=["down", "fail"]))["Field Ops North"]
    texts = {h["text"]: h["keywords"] for h in north["keyword_hits"]}
    assert texts["app is down at my location"] == ["down"]
    assert texts["@919999 merchant onboarding failed for 3 leads"] == ["fail"]


def test_mentions_use_my_number(wa_home, monkeypatch):
    import digest as d
    monkeypatch.setattr(d, "_my_ids", lambda _: ["919999"])
    north = by_name(d.digest(wa_home, keywords=["fail"]))["Field Ops North"]
    assert [m["id"] for m in north["mentions_of_me"]] == ["n3"]
    assert [h["id"] for h in north["keyword_hits"]] == []  # a mention is not double-counted


def test_not_allowlisted_chats_listed_by_name_only(wa_home):
    other = digest(wa_home)["other_active_chats_not_allowlisted"]
    assert [c["name"] for c in other["chats"]] == ["Not Allowlisted Busy"]  # Old Group is outside the window
    assert "text" not in other["chats"][0]


def test_empty_window(wa_home):
    future = datetime(2100, 1, 1, tzinfo=timezone.utc)
    assert digest(wa_home, now=future)["allowlisted_chats_with_activity"] == []


def test_snippets_truncated(wa_home):
    import digest as d
    assert len(d._snippet("x" * 1000)) == d.SNIPPET_CHARS
