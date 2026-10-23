# whatsapp-claude

Read, triage and reply to WhatsApp from Claude Code, packaged as a Claude Code plugin.

It links your WhatsApp account as a **linked device** (like WhatsApp Web) using a hardened fork of
[lharries/whatsapp-mcp](https://github.com/lharries/whatsapp-mcp) (MIT), and runs it in a **dedicated Claude
session** with permission prompts on.

> **Unofficial client.** It uses WhatsApp's multi-device protocol via [whatsmeow](https://github.com/tulir/whatsmeow).
> That is against WhatsApp's terms and carries a small risk of the number being restricted.
> **Data:** messages from allowlisted chats are stored unencrypted in `~/.whatsapp-mcp/messages.db`, and text
> Claude reads is sent to the model. Check your organisation's policy before capturing work chats, especially
> any containing customer or merchant personal data.

## Install

Prereqs (macOS): `brew install go uv gh` (and `jq` if `/usr/bin/jq` is missing).

The repo is private: you need read access to it (ask the owner to add you as a collaborator), then
`gh auth login && gh auth setup-git` so Claude Code's git clone can authenticate over HTTPS. SSH (port 22) is
often blocked on corporate networks.

```text
/plugin marketplace add https://github.com/utkarsh9891/whatsapp-claude.git
/plugin install whatsapp@whatsapp-claude
/wa-setup 91XXXXXXXXXX          # your number with country code → you get a pairing code
```

Or without Claude: `plugins/whatsapp/bin/install.sh && plugins/whatsapp/bin/install.sh pair 91XXXXXXXXXX`.

## Use

```bash
wa-allow list                    # every chat the bridge has seen (names only)
wa-allow add "Field Ops North"   # start capturing a chat; nothing is stored until you do
wa                               # the WhatsApp Claude session
```

In `wa`: "what needs my attention in the last 12 hours?" → `digest`; "reply in Field Ops North that …" → a
draft, then a permission prompt naming the chat.

## Safety model

| Layer | What it does |
|---|---|
| **Allowlist** (`~/.whatsapp-mcp/config.json`) | The bridge stores message content, downloads media and **sends** only for listed chats. All chats' names are kept so you can find them. Re-read on change. |
| **`wa` session** | Only the WhatsApp MCP server (`--strict-mcp-config`), `--permission-mode default`, bypass disabled via `--settings`, run from `~/.whatsapp-mcp/workspace` so no project settings apply. Sends and downloads always prompt. |
| **Bypass guard hook** | Installed with the plugin, active in **every** session: any `mcp__*whatsapp__*` call is denied unless the permission mode is `default`, `acceptEdits` or `plan`. Fails closed. |
| **Bridge API** | Loopback only, bearer token (`~/.whatsapp-mcp/token`, 0600), JSON-only (blocks browser cross-origin posts). Media sends only from `~/.whatsapp-mcp/outbox`. |
| **Files** | `~/.whatsapp-mcp` is 0700; sender-supplied filenames are reduced to one path component; message text is never logged. |

## Operations

```bash
plugins/whatsapp/bin/install.sh status      # installed / paired / service / allowlist
plugins/whatsapp/bin/install.sh pair        # re-link after logout (QR if no number)
plugins/whatsapp/bin/install.sh uninstall   # stop + remove; data stays in ~/.whatsapp-mcp
```

After a plugin update, run `/wa-setup` again to rebuild. The linked device expires if the phone is offline for
about two weeks; `install.sh status` then shows `paired: no`.

## Changes from upstream

Upstream commit `7d6a06dc` (2025-07-13). whatsmeow bumped to current; data dir, allowlist, API auth and
loopback binding, outbox restriction, path sanitising, no message logging, pairing-code login, PNG QR,
`digest` tool, stdout-safe MCP server. See `git log`.

## Development

```bash
cd plugins/whatsapp/bridge && go test ./...
cd plugins/whatsapp/server && uv run --with pytest python -m pytest tests -q
```
