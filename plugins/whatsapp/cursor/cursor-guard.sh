#!/bin/bash
# Cursor guard for WhatsApp tools (ADR 2026-10-23-b283a0). Cursor hooks can't see
# whether auto-run is on, and in auto-run Cursor does not honour "ask" (verified
# 2026-10-24), so every decision here is allow or deny: Cursor is read-only for
# WhatsApp (sends and downloads denied; reply from the Claude `wa` session), and
# once a conversation has used WhatsApp its shell commands and other MCP tools
# are denied. WhatsApp tools are denied outside the WhatsApp workspace.
# Registered in ~/.cursor/hooks.json with failClosed; malformed input is denied.
WA_HOME="${WA_HOME:-$HOME/.whatsapp-mcp}"
WORKSPACE="$WA_HOME/cursor-workspace"
TAINT_DIR="$WA_HOME/cursor-taint"

respond() { # permission, message
  jq -nc --arg p "$1" --arg m "$2" '{permission: $p, user_message: $m, agent_message: $m}'
  exit 0
}

input=$(cat)
event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null) || respond deny "WhatsApp guard: unreadable hook input"
[ -n "$event" ] || respond deny "WhatsApp guard: unreadable hook input"
field() { jq -r "$1 // empty" <<<"$input"; }

conv=$(field .conversation_id | tr -cd 'A-Za-z0-9._-')
tainted() { [ -z "$conv" ] || [ -e "$TAINT_DIR/$conv" ]; }

case "$event" in
  beforeMCPExecution)
    server=$(field .mcp_server_name)
    tool=$(field .tool_name)
    if [[ "$server" == *whatsapp* || ( -z "$server" && "$tool" == *whatsapp* ) ]]; then
      in_ws=$(jq -r --arg ws "$WORKSPACE" '[.workspace_roots[]? | rtrimstr("/")] | index($ws) != null' <<<"$input")
      [ "$in_ws" = true ] || respond deny "WhatsApp tools only run in the WhatsApp workspace: start it with wa-cursor"
      [ -n "$conv" ] || respond deny "WhatsApp guard: no conversation id"
      mkdir -p "$TAINT_DIR" && chmod 700 "$TAINT_DIR" && : > "$TAINT_DIR/$conv"
      case "$tool" in
        *send_message|*send_file|*send_audio_message|*download_media)
          respond deny "Cursor is read-only for WhatsApp: ${tool} is blocked. Reply from the Claude session (wa)." ;;
      esac
      respond allow ""
    fi
    tainted && respond deny "This chat has read WhatsApp messages, so other tools are blocked in it. Start a new chat for ${server:-MCP} ${tool}."
    respond allow ""
    ;;
  beforeShellExecution)
    cmd=$(field .command)
    tainted && respond deny "This chat has read WhatsApp messages, so shell commands are blocked in it. Start a new chat to run: ${cmd:0:120}"
    respond allow ""
    ;;
  *)
    respond allow ""
    ;;
esac
