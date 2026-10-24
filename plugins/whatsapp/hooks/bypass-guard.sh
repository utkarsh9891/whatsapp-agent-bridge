#!/bin/bash
# Guard for WhatsApp MCP tools (ADR 2026-10-23-8f4095, amended by 2026-10-24-f10233).
# Incoming messages are untrusted text, so the tools only run in permission modes
# where Claude still checks actions: manual (default), acceptEdits, plan, auto.
# Bypass, dontAsk and unknown modes are blocked; malformed input fails closed.
# Sends are decided here by recipient: to the owner's own chat, allowed; to anyone
# else, the user is asked. Downloads are allowed.
WA_HOME="${WA_HOME:-$HOME/.whatsapp-mcp}"
input=$(cat)

# Cursor also runs Claude Code hooks, without a permission_mode: blocked as "unknown".
mode=$(jq -r '.permission_mode // "unknown"' 2>/dev/null <<<"$input") || mode="unknown"
case "$mode" in
  default|acceptEdits|plan|auto) ;;
  *)
    echo "WhatsApp tools are blocked in permission mode '$mode'. Start a WhatsApp session with: wa" >&2
    exit 2
    ;;
esac

decide() { # decision, reason
  jq -nc --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# is_self reports whether a recipient (phone number or JID) is the owner's own chat,
# using the linked device's phone-number JID and LID from the bridge's store.
is_self() {
  local r="$1" user server own pn lid
  own=$(sqlite3 "file:$WA_HOME/whatsapp.db?mode=ro" "SELECT jid || ' ' || COALESCE(lid, '') FROM whatsmeow_device LIMIT 1" 2>/dev/null) || return 1
  read -r pn lid <<<"$own"
  pn=${pn%%@*}; pn=${pn%%:*}; pn=${pn%%.*}
  lid=${lid%%@*}; lid=${lid%%:*}; lid=${lid%%.*}
  if [[ "$r" == *@* ]]; then user=${r%%@*}; server=${r#*@}; else user=$r; server=s.whatsapp.net; fi
  user=${user%%:*}
  [ -n "$user" ] || return 1
  { [ -n "$pn" ] && [ "$server" = s.whatsapp.net ] && [ "$user" = "$pn" ]; } && return 0
  { [ -n "$lid" ] && [ "$server" = lid ] && [ "$user" = "$lid" ]; } && return 0
  return 1
}

tool=$(jq -r '.tool_name // ""' <<<"$input")
case "$tool" in
  *__send_message|*__send_file|*__send_audio_message)
    recipient=$(jq -r '.tool_input.recipient // ""' <<<"$input")
    is_self "$recipient" && decide allow "Sending to your own chat"
    decide ask "WhatsApp: send to ${recipient}? Check the chat and the text."
    ;;
  *__download_media)
    decide allow "Download into ~/.whatsapp-mcp/media"
    ;;
esac
exit 0
