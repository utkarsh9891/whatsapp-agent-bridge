"""Cheap triage view across allowlisted chats.

Reads messages.db and returns counts plus only the messages that need attention
(mentions of me, keyword hits), so a catch-up across many groups costs a few
thousand tokens instead of the raw history.
"""
import os
import sqlite3
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional

SNIPPET_CHARS = 200
DEFAULT_KEYWORDS = ["urgent", "escalat", "down", "fail", "not working", "help"]


def _parse_ts(value: str) -> Optional[datetime]:
    """Parse a bridge timestamp ('2026-10-23 18:37:13+05:30', possibly with fractional seconds)."""
    if not value:
        return None
    try:
        ts = datetime.fromisoformat(value)
    except ValueError:
        # Go may write nanoseconds; trim the fraction to microseconds
        head, _, rest = value.partition(".")
        digits = "".join(c for c in rest if c.isdigit())
        tz = rest[len(digits):]
        try:
            ts = datetime.fromisoformat(f"{head}.{digits[:6]}{tz}")
        except ValueError:
            return None
    return ts if ts.tzinfo else ts.replace(tzinfo=timezone.utc)


def _my_ids(wa_home: str) -> List[str]:
    """My phone number and LID, from the bridge's device store, for spotting @-mentions."""
    path = os.path.join(wa_home, "whatsapp.db")
    if not os.path.exists(path):
        return []
    try:
        conn = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
        try:
            cols = {r[1] for r in conn.execute("PRAGMA table_info(whatsmeow_device)")}
            wanted = [c for c in ("jid", "lid") if c in cols]
            if not wanted:
                return []
            row = conn.execute(f"SELECT {', '.join(wanted)} FROM whatsmeow_device LIMIT 1").fetchone()
        finally:
            conn.close()
    except sqlite3.Error:
        return []
    ids = []
    for jid in row or []:
        if jid:
            ids.append(jid.split("@")[0].split(":")[0].split(".")[0])
    return ids


def _snippet(text: str) -> str:
    text = " ".join((text or "").split())
    return text if len(text) <= SNIPPET_CHARS else text[: SNIPPET_CHARS - 1] + "…"


def digest(
    wa_home: str,
    since_hours: float = 24,
    keywords: Optional[List[str]] = None,
    max_items_per_chat: int = 5,
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    now = now or datetime.now(timezone.utc)
    since = now - timedelta(hours=since_hours)
    keywords = [k.lower() for k in (keywords if keywords is not None else DEFAULT_KEYWORDS)]
    me = _my_ids(wa_home)

    conn = sqlite3.connect(f"file:{os.path.join(wa_home, 'messages.db')}?mode=ro", uri=True)
    try:
        chats = conn.execute("SELECT jid, name, last_message_time FROM chats").fetchall()
        rows = conn.execute(
            "SELECT chat_jid, id, sender, content, timestamp, is_from_me, media_type FROM messages"
        ).fetchall()
    finally:
        conn.close()

    names = {jid: name for jid, name, _ in chats}
    by_chat: Dict[str, list] = {}
    for chat_jid, msg_id, sender, content, ts, from_me, media in rows:
        parsed = _parse_ts(ts)
        if parsed is None:
            continue
        by_chat.setdefault(chat_jid, []).append((parsed, msg_id, sender, content or "", bool(from_me), media or ""))

    active = []
    for chat_jid, msgs in by_chat.items():
        msgs.sort(key=lambda m: m[0])
        recent = [m for m in msgs if m[0] >= since]
        if not recent:
            continue
        mine = [m[0] for m in msgs if m[4]]
        last_mine = mine[-1] if mine else None
        unanswered = [m for m in msgs if not m[4] and (last_mine is None or m[0] > last_mine) and m[0] >= since]

        mentions, hits = [], []
        for ts, msg_id, sender, content, from_me, media in recent:
            if from_me:
                continue
            item = {"id": msg_id, "time": ts.isoformat(), "sender": sender, "text": _snippet(content)}
            if any(f"@{i}" in content for i in me):
                mentions.append(item)
            elif any(k in content.lower() for k in keywords):
                hits.append({**item, "keywords": [k for k in keywords if k in content.lower()]})

        active.append({
            "chat_jid": chat_jid,
            "name": names.get(chat_jid),
            "messages": len(recent),
            "media": sum(1 for m in recent if m[5]),
            "last_message": recent[-1][0].isoformat(),
            "unanswered_since_my_last_reply": len(unanswered),
            "i_have_replied_ever": last_mine is not None,
            "mentions_of_me": mentions[-max_items_per_chat:],
            "keyword_hits": hits[-max_items_per_chat:],
        })

    active.sort(key=lambda c: (len(c["mentions_of_me"]), len(c["keyword_hits"]), c["messages"]), reverse=True)

    # Chats whose content isn't stored (not allowlisted) still have names and activity times
    stored = set(by_chat)
    other_active = sorted(
        (
            {"chat_jid": jid, "name": name, "last_message": t.isoformat()}
            for jid, name, last in chats
            if jid not in stored and (t := _parse_ts(last)) is not None and t >= since
        ),
        key=lambda c: c["last_message"],
        reverse=True,
    )

    return {
        "window": {"since": since.isoformat(), "hours": since_hours},
        "keywords": keywords,
        "allowlisted_chats_with_activity": active,
        "other_active_chats_not_allowlisted": {
            "count": len(other_active),
            "chats": other_active[:20],
            "note": "Content not stored. Add a chat_jid to allow_chats in ~/.whatsapp-mcp/config.json to capture it.",
        },
    }
