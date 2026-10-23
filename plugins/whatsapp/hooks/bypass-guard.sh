#!/bin/bash
# Blocks every WhatsApp MCP tool call in bypass-permissions mode. Incoming
# messages are untrusted text; with permission prompts off, one of them could
# steer Claude into sending messages or running commands. Fails closed.
input=$(cat)

# Cursor also runs Claude Code hooks, without a permission_mode. There the Cursor
# guard decides (ADR 2026-10-23-b283a0), but only if it is registered; otherwise
# this guard still blocks.
if jq -e 'has("cursor_version")' >/dev/null 2>&1 <<<"$input"; then
  if jq -e '[.hooks.beforeMCPExecution[]?.command // empty | select(test("cursor-guard\\.sh$"))] | length > 0' \
       "$HOME/.cursor/hooks.json" >/dev/null 2>&1; then
    exit 0
  fi
  echo "WhatsApp tools in Cursor need the Cursor guard: run install.sh cursor" >&2
  exit 2
fi

mode=$(jq -r '.permission_mode // "unknown"' 2>/dev/null <<<"$input") || mode="unknown"
case "$mode" in
  default|acceptEdits|plan) exit 0 ;;
esac
echo "WhatsApp tools are blocked in permission mode '$mode'. Start a WhatsApp session with: wa" >&2
exit 2
