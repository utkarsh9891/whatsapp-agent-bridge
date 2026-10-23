#!/bin/bash
# Cursor guard for WhatsApp tools (ADR 2026-10-23-b283a0). Cursor hooks can't see
# whether auto-run is on, so this doesn't depend on it: sends always ask, and
# once a conversation has used WhatsApp, its shell commands and other MCP tools
# ask too. WhatsApp tools are denied outside the WhatsApp workspace. Registered
# in ~/.cursor/hooks.json with failClosed; malformed input is denied.
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
          respond ask "WhatsApp: approve ${tool}? Check the chat and the text first." ;;
      esac
      respond allow ""
    fi
    tainted && respond ask "This chat has read WhatsApp messages; approve ${server:-MCP} tool ${tool}?"
    respond allow ""
    ;;
  beforeShellExecution)
    cmd=$(field .command)
    tainted && respond ask "This chat has read WhatsApp messages; approve the command: ${cmd:0:120}"
    respond allow ""
    ;;
  *)
    respond allow ""
    ;;
esac
