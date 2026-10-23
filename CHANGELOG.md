# Changelog

Notable changes per plugin version (`plugins/whatsapp/.claude-plugin/plugin.json`). Back to [AGENTS.md](./AGENTS.md).

## 0.1.0 — 2026-10-23

- Hardened fork of lharries/whatsapp-mcp: loopback-only, token-authenticated bridge API; outbox-only media
  sends; path sanitising; no message text in logs; current whatsmeow ([ADR de419c](./docs/architecture/decisions/2026-10-23-de419c-fork-and-harden-whatsapp-mcp.md)).
- Chat allowlist gating storage, downloads and sends ([ADR e302a3](./docs/architecture/decisions/2026-10-23-e302a3-allowlist-gates-content-and-sends.md)).
- `wa` session, bypass guard hook, `/wa-setup`, triage skill, `digest` tool, pairing-code login, launchd service
  ([ADR 8f4095](./docs/architecture/decisions/2026-10-23-8f4095-dedicated-session-and-bypass-guard.md)).
