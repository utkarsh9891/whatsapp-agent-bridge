# Choosing which chats are captured

Back to [AGENTS.md](../../AGENTS.md). Decision: [ADR 2026-10-23-e302a3](../architecture/decisions/2026-10-23-e302a3-allowlist-gates-content-and-sends.md).

Nothing is captured until you allow it. The bridge keeps every chat's **name** so you can find it, but stores
**messages**, downloads media and **sends** only for allowlisted chats.

```bash
wa-allow list                    # every chat seen; * marks allowlisted
wa-allow list ops                # filter by name or JID
wa-allow add "Field Ops North"   # a name must match exactly one chat; otherwise pass the JID
wa-allow remove 1203630000@g.us
wa-allow direct on               # allow every 1:1 chat
```

Changes apply immediately (the bridge re-reads `~/.whatsapp-mcp/config.json`). Messages from before a chat was
added are not fetched. Removing a chat stops capture and sends; already-stored messages stay until you delete them.

The allowlist is per machine; each machine keeps its own `config.json`.
