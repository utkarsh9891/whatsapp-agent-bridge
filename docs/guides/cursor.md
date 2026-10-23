# Using WhatsApp from Cursor

Back to [AGENTS.md](../../AGENTS.md). Why it works this way: [ADR 2026-10-23-b283a0](../architecture/decisions/2026-10-23-b283a0-cursor-support-with-taint-guard.md).

Cursor uses the same bridge, messages and allowlist as Claude Code. Pick whichever has budget; nothing is set up twice.

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

Ask the same things as in Claude ("what needs my attention today?", "reply in Field Ops North that…").

## What the guard does

Cursor doesn't tell hooks whether a chat is in auto-run, so the guard doesn't depend on it:

| Situation | Result |
|---|---|
| WhatsApp read tools (`digest`, `list_messages`, …) in the WhatsApp workspace | allowed |
| `send_message`, `send_file`, `send_audio_message`, `download_media` | **always asks**, auto-run or not |
| any shell command, or another MCP server's tool, in a chat that has used WhatsApp | **asks** |
| WhatsApp tools in any other Cursor project | denied |

So after you read WhatsApp in a chat, every terminal command in that chat asks first. Start a new chat for
unrelated work.
