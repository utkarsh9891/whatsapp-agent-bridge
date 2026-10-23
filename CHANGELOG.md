# Changelog

Notable changes per plugin version (`plugins/whatsapp/.claude-plugin/plugin.json`). Back to [AGENTS.md](./AGENTS.md).

## 0.2.0 — 2026-10-24

- The allowlist is shared by every machine through your WhatsApp "Message yourself" chat: `#wa add|remove|direct`
  typed on the phone or posted by `wa-allow`; applied once per machine, with a ✅ ⏳ ❓ ❌ reaction; no file sync
  ([ADR f28675](./docs/architecture/decisions/2026-10-23-f28675-allowlist-carried-in-whatsapp-self-chat.md)).
  Reinstall with `/wa-setup` on each machine.

## 0.1.0 — 2026-10-23

- Hardened fork of lharries/whatsapp-mcp: loopback-only, token-authenticated bridge API; outbox-only media
  sends; path sanitising; no message text in logs; current whatsmeow ([ADR de419c](./docs/architecture/decisions/2026-10-23-de419c-fork-and-harden-whatsapp-mcp.md)).
- Chat allowlist gating storage, downloads and sends ([ADR e302a3](./docs/architecture/decisions/2026-10-23-e302a3-allowlist-gates-content-and-sends.md)).
- `wa` session, bypass guard hook, `/wa-setup`, triage skill, `digest` tool, pairing-code login, launchd service
  ([ADR 8f4095](./docs/architecture/decisions/2026-10-23-8f4095-dedicated-session-and-bypass-guard.md)).
