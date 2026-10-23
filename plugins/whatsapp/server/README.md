# server — MCP tools

Manifest: [`module.yaml`](./module.yaml) · Back to [AGENTS.md](../../../AGENTS.md) · How the assistant should use
these tools: [triage skill](../skills/whatsapp-triage/SKILL.md)

| File | Responsibility |
|---|---|
| `main.py` | FastMCP tool definitions |
| `whatsapp.py` | store queries, bridge API calls (token from `$WA_HOME/token`), diagnostics to stderr only (stdout is the MCP channel) |
| `digest.py` | `digest(since_hours, keywords)`: per allowlisted chat, message and media counts, unanswered since your last reply, @-mentions of you, keyword hits (snippets ≤ 200 chars); active non-allowlisted chats by name only |
| `audio.py` | converts audio to Opus `.ogg` (ffmpeg) into the outbox |
| `tests/test_digest.py` | digest tests over a fixture written by the bridge |

Read tools never write. Send tools and `download_media` call the bridge, which enforces the allowlist and outbox.
