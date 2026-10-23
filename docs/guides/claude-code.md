# Using WhatsApp from Claude Code

Back to [AGENTS.md](../../AGENTS.md). Why it works this way: [ADR 2026-10-23-8f4095](../architecture/decisions/2026-10-23-8f4095-dedicated-session-and-bypass-guard.md).

Start the WhatsApp session in a terminal with **`wa`**. It is a normal Claude Code session with only the WhatsApp
tools, permission prompts on, and bypass mode disabled. Your other sessions can't use WhatsApp; if they try, the
guard hook blocks it.

| You ask | What happens |
|---|---|
| "What needs my attention in the last 12 hours?" | `digest` runs (no prompt); you get a summary by group |
| "Show me the escalation in Field Ops North" | `list_messages` for that chat and window (no prompt) |
| "Reply in Field Ops North that the fix is live" | the assistant drafts the text and names the chat; the send asks for your approval |
| "Download the photo from that message" | `download_media` asks for approval; files land in `~/.whatsapp-mcp/media/` |
| "Send the report" | only files you put in `~/.whatsapp-mcp/outbox` can be sent, after approval |

Only allowlisted chats have content: [allowlist guide](./allowlist.md). `wa` refuses bypass and config-override
flags; other Claude flags (for example `--model`, `-p`) pass through.
