# Changelog

Notable changes per plugin version (`plugins/whatsapp/.claude-plugin/plugin.json`). Back to [AGENTS.md](./AGENTS.md).

## 0.3.2 — 2026-10-24

- `#wa add me` (also `myself`, `self`) allowlists your own "Message yourself" chat by its phone-number and LID
  JIDs; it has no name to match.
- The Cursor workspace rules state that Cursor is read-only for WhatsApp, so the agent drafts replies for `wa`
  instead of offering to send.

## 0.3.1 — 2026-10-24

- Cheap models by default: `wa` uses `haiku`, `wa-cursor --cli` uses `composer-2.5`. Override with `--model` or
  `WA_MODEL` / `WA_CURSOR_MODEL`. Guides cover background one-shot runs (`wa -p`, `wa-cursor --cli -p`).

## 0.3.0 — 2026-10-24

- **Cursor support (read-only)**: `install.sh cursor` adds a WhatsApp workspace and a user-level taint guard;
  `wa-cursor` opens it (app or `--cli`). Reading and triage in Cursor; sends blocked (reply from `wa`); after
  WhatsApp is read in a chat, its shell commands and other tools are blocked. Cursor ignores a hook's "ask" in
  auto-run, so the guard only allows or denies. The Claude guard defers to it inside Cursor ([ADR b283a0](./docs/architecture/decisions/2026-10-23-b283a0-cursor-support-with-taint-guard.md)).

## 0.2.1 — 2026-10-24

- Renamed the repo and plugin source to **whatsapp-agent-bridge** (it serves Claude Code and, next, Cursor). Install
  as `whatsapp@whatsapp-agent-bridge`; the old GitHub URL redirects. The background service label becomes
  `com.whatsapp-agent-bridge.bridge`; `install.sh service` removes the old one.

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
