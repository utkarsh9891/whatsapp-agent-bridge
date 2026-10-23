# Using WhatsApp from Cursor

Back to [AGENTS.md](../../AGENTS.md). Why it works this way: [ADR 2026-10-23-b283a0](../architecture/decisions/2026-10-23-b283a0-cursor-support-with-taint-guard.md).

Cursor uses the same bridge, messages and allowlist as Claude Code, so reading and triage work in whichever has
budget. **Cursor is read-only for WhatsApp:** replies go through the Claude `wa` session. Nothing is set up twice.

## Setup (once per machine)

```bash
plugins/whatsapp/bin/install.sh cursor
```

It creates the WhatsApp workspace `~/.whatsapp-mcp/cursor-workspace` (WhatsApp MCP server + triage rules) and adds
the guard to `~/.cursor/hooks.json`, keeping any hooks you already have. In Cursor, enable the `whatsapp` MCP
server for that workspace when asked.

## Use

| Command | Opens |
|---|---|
| `wa-cursor` | the WhatsApp workspace in the Cursor app |
| `wa-cursor --cli` | the Cursor `agent` CLI in that workspace (`--force` / `--yolo` refused) |
| `wa-cursor --cli -p "<question>"` | one answer and exit (background) |

Ask the same reading questions as in Claude ("what needs my attention today?", "what did Field Ops North say
about the outage?"). To reply, draft it here and send it from `wa`.

## Model

`wa-cursor --cli` defaults to a cheap model, **`composer-2.5`**. Override with `--model` (for example
`wa-cursor --cli --model claude-opus-5-5-medium`) or `WA_CURSOR_MODEL`; `agent models` lists what your account
allows. In the Cursor app, pick the model in the chat's model menu; a launcher can't set it.

## What the guard does

Cursor doesn't tell hooks whether a chat is in auto-run, and in auto-run it ignores a hook's "ask" (tested), so
the guard only allows or blocks:

| Situation | Result |
|---|---|
| WhatsApp read tools (`digest`, `list_messages`, …) in the WhatsApp workspace | allowed |
| `send_message`, `send_file`, `send_audio_message`, `download_media` | **blocked**: reply from `wa` |
| any shell command, or another MCP server's tool, in a chat that has used WhatsApp | **blocked**: start a new chat |
| WhatsApp tools in any other Cursor project | blocked |

The Cursor rules installed in the workspace tell the agent it is read-only, so it drafts replies for you to send
from `wa` instead of offering to send. The Claude Code guard also runs inside Cursor; it lets the Cursor guard decide when that guard is installed.
