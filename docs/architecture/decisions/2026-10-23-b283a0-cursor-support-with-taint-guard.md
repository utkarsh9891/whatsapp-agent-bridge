# 2026-10-23-b283a0 — Cursor support: a dedicated workspace and a mode-independent taint guard

- **Status:** accepted
- **Date:** 2026-10-23
- **Deciders:** Utkarsh Upadhyay
- **Scope:** plugin
- **Supersedes / Amends:** —

## Context
The owner wants to use either Claude Code or Cursor, depending on which has token budget, against the same
bridge, store and allowlist. The Claude guard ([8f4095](./2026-10-23-8f4095-dedicated-session-and-bypass-guard.md))
works by reading `permission_mode` and blocking WhatsApp tools when prompts are off. Cursor's hooks receive no
equivalent field: nothing tells a hook whether a chat is in auto-run ("Run Everything", `--yolo`) mode. So
"block in bypass mode" can't be built for Cursor. The guarantee needed is the same: **text read from WhatsApp must
never become an action without the user approving it.**

## Decision
1. **Dedicated workspace.** `~/.whatsapp-mcp/cursor-workspace` holds the WhatsApp MCP server in its project
   `.cursor/mcp.json` and the triage rules in `.cursor/rules/`. The server is **not** added to the global
   `~/.cursor/mcp.json`. `wa-cursor` opens it in the Cursor app; `wa-cursor --cli` starts the `agent` CLI in it
   and refuses `--force`/`--yolo`.
2. **A user-level guard** in `~/.cursor/hooks.json` (applies to every window), `failClosed: true`, handling:
   - `beforeMCPExecution` for the WhatsApp server: **deny** outside the WhatsApp workspace; **ask** for
     `send_message`, `send_file`, `send_audio_message`, `download_media`; allow read tools. Any WhatsApp call
     **taints** the conversation (marker file per `conversation_id`).
   - `beforeShellExecution`, and `beforeMCPExecution` for any other server: **ask** in a tainted conversation.
   - Unparseable input: deny.
   The guard needs no knowledge of the run mode: sends always ask, and once WhatsApp text is in a conversation,
   nothing else runs without approval.
3. **Fallback if "ask" isn't enforced.** If testing shows Cursor ignores `ask` for these hooks in auto-run, the
   guard denies instead, and Cursor is read-only (replies only from the Claude `wa` session).

## Assumptions
- 1. Cursor runs user-level hooks for `beforeMCPExecution` and `beforeShellExecution` in the app and the `agent`
     CLI, including in auto-run mode (Cursor 3.27 / CLI 2026.10.22). **Verified before merge.**
- 2. `permission: "ask"` from those hooks makes Cursor ask the user, even in auto-run; in headless `-p` runs it
     does not proceed. **Verified before merge;** if false, decision 3 applies.
- 3. Hook input carries `conversation_id`, `workspace_roots`, `mcp_server_name` and `tool_name` (Cursor docs, 2026-10).
- 4. `failClosed: true` makes a crashed or timed-out hook block the action (Cursor docs, 2026-10).

## Reversal triggers
- Revisit if Cursor exposes the run mode to hooks: block outright in auto-run, as on Claude (Assumption #2 becomes moot).
- Revisit if a Cursor release changes hook semantics (Assumptions #1, #2): rerun the guard's live checks on upgrade.
- Revisit if the user wants WhatsApp tools in ordinary Cursor projects: today they are denied outside the workspace.

## Consequences
- Both clients share one bridge, store and allowlist; switching is choosing which app to open.
- After reading WhatsApp in a Cursor chat, every shell command in that chat asks, including harmless ones. That
  friction is the price of not knowing the run mode.
- Taint markers accumulate in `~/.whatsapp-mcp/cursor-taint/`; they hold only conversation IDs.

## Alternatives considered
- **Register globally in `~/.cursor/mcp.json`:** rejected; puts WhatsApp next to every project.
- **Deny all WhatsApp tools when auto-run is on:** not possible; hooks can't see the mode (the reason for this ADR).
- **Ask on every WhatsApp read too:** rejected as the default; reads alone can't act, and the taint rule covers
  what an injected read could lead to.
- **Cursor read-only from the start:** kept as the fallback under Assumption #2.
