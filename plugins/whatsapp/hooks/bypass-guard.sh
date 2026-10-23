#!/bin/bash
# Blocks every WhatsApp MCP tool call in bypass-permissions mode. Incoming
# messages are untrusted text; with permission prompts off, one of them could
# steer Claude into sending messages or running commands. Fails closed.
mode=$(jq -r '.permission_mode // "unknown"' 2>/dev/null) || mode="unknown"
case "$mode" in
  default|acceptEdits|plan) exit 0 ;;
esac
echo "WhatsApp tools are blocked in permission mode '$mode'. Start a WhatsApp session with: wa" >&2
exit 2
