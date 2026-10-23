# plugin — Claude Code packaging

Manifest: [`module.yaml`](./module.yaml) · Back to [AGENTS.md](../../AGENTS.md) ·
Decision: [ADR 2026-10-23-8f4095](../../docs/architecture/decisions/2026-10-23-8f4095-dedicated-session-and-bypass-guard.md)

| Path | What it is |
|---|---|
| [`hooks/bypass-guard.sh`](./hooks/bypass-guard.sh) | `PreToolUse` hook on `mcp__.*whatsapp__.*`: allows only `default`, `acceptEdits`, `plan`; fails closed. Test: [`hooks/test-bypass-guard.sh`](./hooks/test-bypass-guard.sh) |
| [`wa/settings.json`](./wa/settings.json) | permissions of the `wa` session: bypass disabled, reads allowed, sends and downloads ask |
| [`bin/wa`](./bin/wa) | launches the WhatsApp-only Claude session ([guide](../../docs/guides/claude-code.md)) |
| [`cursor/cursor-guard.sh`](./cursor/cursor-guard.sh) | Cursor hook (`beforeMCPExecution`, `beforeShellExecution`): sends ask, tainted chats ask, WhatsApp denied outside its workspace. Test: [`cursor/test-cursor-guard.sh`](./cursor/test-cursor-guard.sh) ([guide](../../docs/guides/cursor.md)) |
| [`bin/wa-cursor`](./bin/wa-cursor) | opens the WhatsApp workspace in Cursor, or `--cli` for the `agent` CLI |
| [`bin/wa-allow`](./bin/wa-allow) | allowlist CLI ([guide](../../docs/guides/allowlist.md)) |
| [`bin/install.sh`](./bin/install.sh) | `install`, `pair [phone]`, `service`, `cursor`, `status`, `uninstall` ([runbook](../../docs/operations/runbook.md)) |
| [`commands/wa-setup.md`](./commands/wa-setup.md) | `/wa-setup [phone]`: install, pair and start the service from Claude Code |
| [`skills/whatsapp-triage/SKILL.md`](./skills/whatsapp-triage/SKILL.md) | how the assistant reads (digest first), and replies (draft, confirm target, approve) |
| [`bridge/`](./bridge/README.md), [`server/`](./server/README.md) | the two runtime modules |

Changing any guard file: read the [security model](../../docs/architecture/security-model.md) first.
