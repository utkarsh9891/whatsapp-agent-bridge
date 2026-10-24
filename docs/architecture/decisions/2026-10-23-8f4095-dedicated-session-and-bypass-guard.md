# 2026-10-23-8f4095 — WhatsApp tools only in a dedicated `wa` session, plus a hook that blocks them in bypass mode

- **Status:** amended by [2026-10-24-f10233](./2026-10-24-f10233-auto-mode-self-sends-and-send-folders.md)
- **Date:** 2026-10-23
- **Deciders:** Utkarsh Upadhyay
- **Scope:** plugin
- **Supersedes / Amends:** —

## Context
Incoming messages are untrusted text. If the assistant reads one while permission prompts are off, an injected
instruction can become an action (a send, a shell command, a file read) with no human in the loop. The primary
user's global Claude Code default is `bypassPermissions`, so "prompts off" is the normal state of their
sessions, which also carry access to production tooling.

## Decision
Three independent layers, so one being bypassed doesn't open the path:
1. **No global registration.** The MCP server loads only via the `wa` launcher: `--mcp-config` with
   `--strict-mcp-config` (no other servers), `--settings wa/settings.json`, `--permission-mode default`, run from
   `~/.whatsapp-mcp/workspace` so no project settings apply. `wa` refuses bypass and config-override flags.
2. **Bypass disabled in that session.** `wa/settings.json` sets `disableBypassPermissionsMode: disable` and
   `defaultMode: default`; read tools are allowed, `send_*` and `download_media` are `ask`.
3. **A guard hook in every session.** The plugin installs a `PreToolUse` hook matching `mcp__.*whatsapp__.*` that
   exits 2 (deny) unless `permission_mode` is `default`, `acceptEdits` or `plan`. It fails closed on missing or
   malformed input. It blocks reads too, because reading is where injection enters.

## Assumptions
- 1. Claude Code passes `permission_mode` to `PreToolUse` hooks and honours exit code 2 as a deny in every mode,
     including bypass (verified on 2.1.309, 2026-10-23).
- 2. `--settings` with `disableBypassPermissionsMode` overrides a global `defaultMode: bypassPermissions` and the
     `--dangerously-skip-permissions` flag (verified on 2.1.309).
- 3. `ask` rules take precedence over `allow` rules and `--allowedTools` (verified on 2.1.309).

## Reversal triggers
- Revisit if a Claude Code release changes hook input or exit-code semantics (Assumption #1); the guard test and
  a live check must be rerun on upgrade.
- Revisit if Claude Code gains per-MCP-server permission modes, which would make the dedicated session redundant.

## Consequences
- Replying means switching to the `wa` session; everyday sessions can't touch WhatsApp at all.
- The guard is part of the plugin, so a machine with the server installed but the plugin disabled loses layer 3;
  layers 1 and 2 still hold.
- Every guard file is in [`CODEOWNERS`](../../../.github/CODEOWNERS) and covered by the [security model](../security-model.md).

## Alternatives considered
- **Register the server globally and rely on prompts:** rejected; the user's sessions run in bypass by default.
- **Hook only, no dedicated session:** rejected; a single layer, and it would put WhatsApp tools next to
  production tooling in normal sessions.
- **Block only send tools in bypass:** rejected; reading injected text is the entry point, so reads are blocked too.
