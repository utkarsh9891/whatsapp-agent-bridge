#!/bin/bash
# Cases for cursor-guard.sh; run by CI (job plugin).
set -u
guard="$(cd "$(dirname "$0")" && pwd)/cursor-guard.sh"
WA_HOME=$(mktemp -d); export WA_HOME
trap 'rm -rf "$WA_HOME"' EXIT
WS="$WA_HOME/cursor-workspace"
fail=0

check() { # label, expected permission, payload
  local got
  got=$(printf '%s' "$3" | "$guard" | jq -r .permission 2>/dev/null)
  if [ "$got" = "$2" ]; then echo "ok   $1"; else echo "FAIL $1: got '$got', want '$2'"; fail=1; fi
}
mcp() { # conversation, workspace root, server, tool
  jq -nc --arg c "$1" --arg w "$2" --arg s "$3" --arg t "$4" \
    '{hook_event_name: "beforeMCPExecution", conversation_id: $c, workspace_roots: [$w], mcp_server_name: $s, tool_name: $t, tool_input: {}}'
}
shell() { jq -nc --arg c "$1" '{hook_event_name: "beforeShellExecution", conversation_id: $c, command: "ls", workspace_roots: []}'; }

check "shell before WhatsApp: allowed"           allow "$(shell c1)"
check "other MCP before WhatsApp: allowed"        allow "$(mcp c1 /proj github list_issues)"
check "WhatsApp outside its workspace: denied"    deny  "$(mcp c1 /proj whatsapp digest)"
check "WhatsApp read in workspace: allowed"       allow "$(mcp c1 "$WS" whatsapp digest)"
check "workspace root with trailing slash"        allow "$(mcp c1 "$WS/" whatsapp list_chats)"
check "send_message: asks"                        ask   "$(mcp c1 "$WS" whatsapp send_message)"
check "prefixed tool name send: asks"             ask   "$(mcp c1 "$WS" whatsapp mcp_whatsapp_send_file)"
check "download_media: asks"                      ask   "$(mcp c1 "$WS" whatsapp download_media)"
check "shell after WhatsApp: asks"                ask   "$(shell c1)"
check "other MCP after WhatsApp: asks"            ask   "$(mcp c1 "$WS" github list_issues)"
check "another conversation stays clean"          allow "$(shell c2)"
check "taint survives a new hook process"         ask   "$(shell c1)"
check "missing conversation id: WhatsApp denied"  deny  "$(mcp "" "$WS" whatsapp digest)"
check "missing conversation id: shell asks"       ask   "$(shell "")"
check "path-like conversation id can't escape"    allow "$(mcp ../../x "$WS" whatsapp digest)"
check "malformed input: denied"                   deny  'not json'
check "empty input: denied"                       deny  ''
check "unrelated event: allowed"                  allow '{"hook_event_name":"stop"}'
[ ! -e "$WA_HOME/../x" ] || { echo "FAIL taint file escaped WA_HOME"; fail=1; }
[ "$(stat -f %Lp "$WA_HOME/cursor-taint" 2>/dev/null || stat -c %a "$WA_HOME/cursor-taint")" = 700 ] || { echo "FAIL taint dir not 0700"; fail=1; }
exit $fail
