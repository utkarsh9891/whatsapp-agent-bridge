#!/bin/bash
# Feeds the guard the PreToolUse payload for each permission mode and checks
# that only default/acceptEdits/plan are let through. Run by CI.
set -u
guard="$(dirname "$0")/bypass-guard.sh"
fail=0

check() { # payload, expected exit, label
  printf '%s' "$1" | "$guard" >/dev/null 2>&1
  local got=$?
  if [ "$got" -ne "$2" ]; then
    echo "FAIL $3: exit $got, want $2"; fail=1
  else
    echo "ok   $3"
  fi
}

payload() { printf '{"hook_event_name":"PreToolUse","tool_name":"mcp__whatsapp__send_message","permission_mode":"%s"}' "$1"; }

check "$(payload default)" 0 "default allowed"
check "$(payload acceptEdits)" 0 "acceptEdits allowed"
check "$(payload plan)" 0 "plan allowed"
check "$(payload bypassPermissions)" 2 "bypassPermissions blocked"
check "$(payload dontAsk)" 2 "unknown mode blocked"
check '{"tool_name":"mcp__whatsapp__digest"}' 2 "missing mode blocked"
check 'not json' 2 "malformed input blocked"

# Under Cursor (input carries cursor_version, no permission_mode)
HOME=$(mktemp -d); export HOME
cursor='{"cursor_version":"3.27.6","hook_event_name":"beforeMCPExecution","tool_name":"digest"}'
check "$cursor" 2 "Cursor without the Cursor guard: blocked"
mkdir -p "$HOME/.cursor"
echo '{"version":1,"hooks":{"beforeMCPExecution":[{"command":"/x/other.sh"}]}}' > "$HOME/.cursor/hooks.json"
check "$cursor" 2 "Cursor with unrelated hooks only: blocked"
echo '{"version":1,"hooks":{"beforeMCPExecution":[{"command":"/x/app/cursor/cursor-guard.sh","failClosed":true}]}}' > "$HOME/.cursor/hooks.json"
check "$cursor" 0 "Cursor with the Cursor guard registered: deferred"
check "$(payload bypassPermissions)" 2 "Claude bypass still blocked when Cursor guard exists"
check '' 2 "empty input blocked"

exit $fail
