# 2026-10-23-3d143d — Drop Cursor support; Claude Code only

- **Status:** accepted
- **Date:** 2026-10-23
- **Deciders:** Utkarsh Upadhyay
- **Scope:** plugin
- **Supersedes / Amends:** supersedes [2026-10-23-b283a0](./2026-10-23-b283a0-cursor-support-with-taint-guard.md)

## Context
Cursor support ([b283a0](./2026-10-23-b283a0-cursor-support-with-taint-guard.md)) was added so WhatsApp triage
could run on whichever client had token budget. Live testing showed Cursor ignores a hook's `ask` in auto-run, so
the only safe Cursor integration was read-only: every reply still had to go through Claude Code. Meanwhile the
Claude `wa` session defaults to Haiku, where a digest costs about a third of a cent.

## Decision
Remove Cursor support: the Cursor guard, workspace, `wa-cursor`, `install.sh cursor`, and the Claude guard's
deferral to the Cursor guard. The repo and plugin source return to the name **whatsapp-claude**.

The Claude guard keeps failing closed when Cursor runs it (Cursor executes Claude Code plugin hooks without a
`permission_mode`), so WhatsApp tools stay blocked in Cursor even if someone wires the MCP server in by hand.
`CURSOR.md` stays: it's the entry point for editing this repo in Cursor, not part of the WhatsApp integration.

## Assumptions
- 1. Claude Code with Haiku is cheap enough for all WhatsApp reading and replying (about $0.003 per digest, 2026-10-24).
- 2. Cursor still doesn't honour a hook's `ask` in auto-run (verified 2026-10-24, CLI 2026.10.22).
- 3. The owner has no other reason to run WhatsApp triage in Cursor.

## Reversal triggers
- Revisit if Claude budget becomes a hard constraint (Assumption #1); the read-only Cursor design in b283a0 is the
  starting point.
- Revisit if Cursor honours `ask` in auto-run or exposes the run mode to hooks (Assumption #2); Cursor could then
  be read-write.

## Consequences
- One client, one guard, one session to reason about; less code on the security boundary.
- Existing Cursor installs keep a stale entry in `~/.cursor/hooks.json` pointing at a script that no longer
  exists; with `failClosed` Cursor would block every MCP and shell call. The [runbook](../../operations/runbook.md)
  gives the one-line removal.

## Alternatives considered
- **Keep Cursor read-only:** rejected under Assumptions #1 and #3; it saved almost nothing and split the workflow.
- **Keep Cursor plus a manual `wa-send` command:** rejected for the same reason.
- **Keep the name whatsapp-agent-bridge:** rejected; the repo serves one client again.
