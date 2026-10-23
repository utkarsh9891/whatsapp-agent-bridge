# whatsapp-agent-bridge

Read, triage and reply to WhatsApp from AI coding agents (Claude Code and Cursor), safely: only the chats you
allowlist, in a dedicated
session, with a hard block on permission-bypass mode.

**Start at [`AGENTS.md`](./AGENTS.md)**, the map of every document in this repo.

> **Unofficial client.** It links your account as a WhatsApp linked device through
> [whatsmeow](https://github.com/tulir/whatsmeow), a hardened fork of
> [lharries/whatsapp-mcp](https://github.com/lharries/whatsapp-mcp). That is against WhatsApp's terms and carries
> a small risk of the number being restricted. Messages from allowlisted chats are stored unencrypted in
> `~/.whatsapp-mcp`, and text the assistant reads goes to the model provider. Check your organisation's policy
> before capturing work chats with personal data.

## Install

Prereqs (macOS): `brew install go uv`.

```text
/plugin marketplace add utkarsh9891/whatsapp-agent-bridge
/plugin install whatsapp@whatsapp-agent-bridge
/wa-setup 91XXXXXXXXXX          # your number with country code → an 8-character pairing code
```

## Use

```bash
wa-allow list                    # every chat seen (names only)
wa-allow add "Field Ops North"   # start capturing a chat
wa                               # the WhatsApp Claude session
wa-cursor                        # or the WhatsApp workspace in Cursor (after install.sh cursor)
```

More: [Claude Code guide](./docs/guides/claude-code.md) · [Cursor guide](./docs/guides/cursor.md) · [allowlist](./docs/guides/allowlist.md) ·
[runbook](./docs/operations/runbook.md) · [security model](./docs/architecture/security-model.md) ·
[contributing](./CONTRIBUTING.md)
