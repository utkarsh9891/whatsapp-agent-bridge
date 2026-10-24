#!/bin/bash
# Cases for bypass-guard.sh; run by CI (job plugin).
set -u
guard="$(cd "$(dirname "$0")" && pwd)/bypass-guard.sh"
WA_HOME=$(mktemp -d); export WA_HOME
trap 'rm -rf "$WA_HOME"' EXIT
fail=0

# check label, expected ("block" = exit 2, "none" = exit 0 with no decision, or a decision), payload
check() {
  local out code got
  out=$(printf '%s' "$3" | "$guard" 2>/dev/null); code=$?
  if [ "$code" = 2 ]; then got=block
  elif [ "$code" = 0 ] && [ -z "$out" ]; then got=none
  else got=$(jq -r '.hookSpecificOutput.permissionDecision // "bad"' <<<"$out" 2>/dev/null || echo bad); fi
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got $got, want $2"; fail=1; fi
}
p() { # mode, tool, recipient
  jq -nc --arg m "$1" --arg t "mcp__whatsapp__$2" --arg r "${3:-}" \
    '{hook_event_name: "PreToolUse", permission_mode: $m, tool_name: $t, tool_input: {recipient: $r}}'
}

check "manual (default) read"            none  "$(p default digest)"
check "acceptEdits read"                 none  "$(p acceptEdits list_chats)"
check "plan read"                        none  "$(p plan digest)"
check "auto read"                        none  "$(p auto digest)"
check "bypassPermissions blocked"        block "$(p bypassPermissions digest)"
check "dontAsk blocked"                  block "$(p dontAsk digest)"
check "unknown mode blocked"             block "$(p whatever digest)"
check "missing mode blocked"             block '{"tool_name":"mcp__whatsapp__digest"}'
check "malformed input blocked"          block 'not json'
check "empty input blocked"              block ''
check "Cursor input blocked"             block '{"cursor_version":"3.27.6","hook_event_name":"beforeMCPExecution","tool_name":"digest"}'
check "bypass send still blocked"        block "$(p bypassPermissions send_message 919999)"

check "send before pairing: asks"        ask   "$(p auto send_message 919999@s.whatsapp.net)"

sqlite3 "$WA_HOME/whatsapp.db" "CREATE TABLE whatsmeow_device (jid TEXT, lid TEXT); INSERT INTO whatsmeow_device VALUES ('919999:54@s.whatsapp.net', '12345:54@lid');"
check "send to own number: allowed"      allow "$(p auto send_message 919999)"
check "send to own PN JID: allowed"      allow "$(p default send_message 919999@s.whatsapp.net)"
check "send to own LID: allowed"         allow "$(p auto send_file 12345@lid)"
check "send to own device JID: allowed"  allow "$(p auto send_message 919999:54@s.whatsapp.net)"
check "send to someone else: asks"       ask   "$(p auto send_message 911111)"
check "send to a group: asks"            ask   "$(p auto send_file 120363000@g.us)"
check "own digits on group server: asks" ask   "$(p auto send_message 919999@g.us)"
check "LID digits as phone number: asks" ask   "$(p auto send_message 12345)"
check "empty recipient: asks"            ask   "$(p auto send_audio_message "")"
check "download: allowed"                allow "$(p auto download_media)"
check "download in bypass: blocked"      block "$(p bypassPermissions download_media)"

exit $fail
