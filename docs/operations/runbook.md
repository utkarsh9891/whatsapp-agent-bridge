# Runbook

Back to [AGENTS.md](../../AGENTS.md). Paths: [on-disk layout](../architecture/overview.md#on-disk-layout-whatsapp-mcp-mode-0700).

## Install

Prereqs (macOS): `brew install go uv` (`jq` ships with macOS 15+).

```text
/plugin marketplace add utkarsh9891/whatsapp-agent-bridge
/plugin install whatsapp@whatsapp-agent-bridge
/wa-setup 91XXXXXXXXXX
```

Without Claude: `plugins/whatsapp/bin/install.sh` then `plugins/whatsapp/bin/install.sh pair 91XXXXXXXXXX`.
If `wa` isn't found, add `~/.local/bin` to `PATH`.

## Cursor

`install.sh cursor` once per machine ([guide](../guides/cursor.md)); `install.sh status` shows the workspace and the
number of guard hooks (2). Reinstalling keeps other hooks in `~/.cursor/hooks.json`; the first run saves a backup
as `hooks.json.bak-whatsapp`. `install.sh uninstall` removes only the guard's entries.

## Pair (link this machine)

`install.sh pair <number>` prints an 8-character code: on the phone, **WhatsApp → Settings → Linked devices →
Link a device → Link with phone number instead**, enter it within ~2 minutes. Without a number it opens a QR
image to scan. On success the background service starts.

## Service

| Task | Command |
|---|---|
| status | `install.sh status` |
| restart | `install.sh service` |
| logs | `tail -f ~/.whatsapp-mcp/bridge.log` |
| stop | `launchctl bootout gui/$(id -u)/com.whatsapp-agent-bridge.bridge` |

## Update

`/plugin marketplace update whatsapp-agent-bridge`, then `/wa-setup` (rebuilds `~/.whatsapp-mcp/app`; data, pairing
and allowlist are kept).

## Several machines

Each machine is a separate linked device (WhatsApp allows four): install and pair on each. Replies sent from any
device reach all of them. Each machine stores from its own pairing onwards. The allowlist is shared through your
self-chat ([allowlist guide](../guides/allowlist.md)); nothing needs syncing.

## Uninstall

`install.sh uninstall` stops the service and removes the launchers; `~/.whatsapp-mcp` is kept. To unlink fully,
delete `~/.whatsapp-mcp` and remove the device under **Linked devices** on the phone.

## Troubleshooting

| Symptom | Check | Fix |
|---|---|---|
| `paired: no` after it worked | phone unlinked the device, or it expired | `install.sh pair <number>` |
| no new messages | `install.sh status`, `tail ~/.whatsapp-mcp/bridge.log` | `install.sh service`; if logged out, pair again |
| chat missing in `digest` | `wa-allow list <name>`: no `*`, or ⏳ pending | `wa-allow add` it; for ⏳, check the exact name or use the JID |
| `#wa` command got no reaction | that machine's bridge is down | `install.sh status`; it applies on reconnect |
| send refused "not in allow_chats" | as above | allowlist the chat |
| send refused "media must be inside" | file location | move the file into `~/.whatsapp-mcp/outbox` |
| "WhatsApp tools are blocked in permission mode" | you're in a normal session | use `wa` |
| `/plugin marketplace add` fails on clone | network blocks SSH | `gh auth login && gh auth setup-git`, or use the HTTPS URL |
| bridge won't build after an update | `go version` vs `go.mod` | `brew upgrade go` |
