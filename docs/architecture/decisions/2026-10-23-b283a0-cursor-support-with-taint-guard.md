# 2026-10-23-b283a0 — Cursor support: a dedicated workspace, read-only, with a taint guard

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
2. **A user-level guard** in `~/.cursor/hooks.json` (applies to every window), `failClosed: true`, that only
   ever returns `allow` or `deny`:
   - `beforeMCPExecution` for the WhatsApp server: **deny** outside the WhatsApp workspace; **deny**
     `send_message`, `send_file`, `send_audio_message`, `download_media` (**Cursor is read-only for WhatsApp**;
     replies go through the Claude `wa` session); allow read tools. Any WhatsApp call **taints** the
     conversation (marker file per `conversation_id`).
   - `beforeShellExecution`, and `beforeMCPExecution` for any other server: **deny** in a tainted conversation.
   - Unparseable input: deny.
3. **The Claude guard defers under Cursor.** Cursor also runs Claude Code's hooks, without a `permission_mode`.
   The Claude guard ([8f4095](./2026-10-23-8f4095-dedicated-session-and-bypass-guard.md)) steps aside when the
   input carries `cursor_version` **and** the Cursor guard is registered; otherwise it still blocks.

Why deny rather than ask: the first design asked for sends and for tools in tainted chats. Live tests in
`agent --yolo` showed Cursor **ignores `ask`** from these hooks in auto-run: the shell command ran and the send
reached the bridge. Hooks can't see the run mode, so the only safe answer is deny.

## Assumptions
- 1. Cursor runs user-level hooks for `beforeMCPExecution` and `beforeShellExecution` in the `agent` CLI,
     including in `--yolo` (**verified 2026-10-24**, Cursor CLI 2026.10.22, app 3.27.6).
- 2. In auto-run Cursor does **not** honour `permission: "ask"` from those hooks (**verified 2026-10-24**: a
     tainted shell command ran and a send reached the bridge); `deny` is honoured (**verified**: both blocked).
- 3. Hook input carries `conversation_id`, `workspace_roots`, `mcp_server_name`, `tool_name` and `cursor_version`
     (**verified 2026-10-24** from logged hook input).
- 4. Cursor also runs Claude Code plugin hooks (**verified 2026-10-24**: the Claude guard fired in Cursor).
- 5. `failClosed: true` makes a crashed or timed-out hook block the action (Cursor docs, 2026-10).

## Reversal triggers
- Revisit if Cursor honours `ask` in auto-run, or exposes the run mode to hooks (Assumption #2): sends could then
  ask instead of being denied, making Cursor read-write.
- Revisit if a Cursor release changes hook semantics (Assumptions #1–#4): rerun the live checks on upgrade.
- Revisit if the user wants WhatsApp tools in ordinary Cursor projects: today they are denied outside the workspace.

## Consequences
- Both clients share one bridge, store and allowlist. Reading and triage work in either; **replies only from
  Claude** (`wa`).
- After reading WhatsApp in a Cursor chat, shell commands and other tools are blocked in that chat; unrelated work
  needs a new chat.
- Taint markers accumulate in `~/.whatsapp-mcp/cursor-taint/`; they hold only conversation IDs.

## Alternatives considered
- **Register globally in `~/.cursor/mcp.json`:** rejected; puts WhatsApp next to every project.
- **Deny all WhatsApp tools when auto-run is on:** not possible; hooks can't see the mode (the reason for this ADR).
- **Ask instead of deny:** the first design; rejected under Assumption #2 after live testing.
- **Ask on every WhatsApp read:** rejected for the same reason; `ask` isn't enforced in auto-run.
