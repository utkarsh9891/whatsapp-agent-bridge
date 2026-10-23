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

# Cursor runs Claude Code hooks too; its input has cursor_version and no permission_mode
check '{"cursor_version":"3.27.6","hook_event_name":"beforeMCPExecution","tool_name":"digest"}' 2 "Cursor input blocked"
check '' 2 "empty input blocked"

exit $fail
