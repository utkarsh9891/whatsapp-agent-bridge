#!/bin/bash
# whatsapp-agent-bridge: build, pair, run as a login service.
#
#   install.sh             build the bridge + MCP server into ~/.whatsapp-mcp, write configs, link `wa` + `wa-allow`
#   install.sh pair [phone] link this machine to WhatsApp (pairing code if phone given, else QR), then start the service
#   install.sh service     (re)start the background bridge (launchd)
#   install.sh cursor      add the Cursor WhatsApp workspace, the Cursor guard hook and `wa-cursor`
#   install.sh status      show what is installed and running
#   install.sh uninstall   stop the service and remove launchers (keeps ~/.whatsapp-mcp data)
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WA_HOME="${WA_HOME:-$HOME/.whatsapp-mcp}"
APP="$WA_HOME/app"
BIN_DIR="$HOME/.local/bin"
LABEL="com.whatsapp-agent-bridge.bridge"
OLD_LABEL="com.whatsapp-claude.bridge"   # pre-0.2.1 name; removed on service (re)start
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need() {
  local missing=()
  for t in go uv jq claude; do command -v "$t" >/dev/null || missing+=("$t"); done
  [ ${#missing[@]} -eq 0 ] || die "missing: ${missing[*]} (brew install ${missing[*]/claude/})"
}

do_install() {
  need
  mkdir -p "$WA_HOME" "$BIN_DIR" && chmod 700 "$WA_HOME"
  local was_running=false
  service_loaded && was_running=true

  rm -rf "$APP.new"
  say "building bridge…"
  (cd "$PLUGIN_ROOT/bridge" && go build -o "$APP.new/whatsapp-bridge" .)
  say "installing MCP server…"
  cp -R "$PLUGIN_ROOT/server" "$APP.new/server"
  rm -rf "$APP.new/server/.venv" "$APP.new/server/tests"
  (cd "$APP.new/server" && uv sync --quiet --no-dev)
  cp "$PLUGIN_ROOT/bin/wa" "$PLUGIN_ROOT/bin/wa-allow" "$PLUGIN_ROOT/bin/wa-cursor" "$APP.new/"
  cp -R "$PLUGIN_ROOT/cursor" "$APP.new/cursor"
  cp "$PLUGIN_ROOT/skills/whatsapp-triage/SKILL.md" "$APP.new/cursor/whatsapp-triage.md"
  # stop the bridge before swapping the binary it runs from
  $was_running && stop_service
  rm -rf "$APP" && mv "$APP.new" "$APP"

  [ -f "$WA_HOME/config.json" ] || printf '{\n  "allow_chats": [],\n  "allow_direct_chats": false,\n  "port": 8080\n}\n' > "$WA_HOME/config.json"
  chmod 600 "$WA_HOME/config.json"
  cp "$PLUGIN_ROOT/wa/settings.json" "$WA_HOME/settings.json"
  jq -n --arg uv "$(command -v uv)" --arg dir "$APP/server" --arg home "$WA_HOME" \
    '{mcpServers: {whatsapp: {command: $uv, args: ["--directory", $dir, "run", "--quiet", "main.py"], env: {WA_HOME: $home}}}}' \
    > "$WA_HOME/mcp.json"

  ln -sf "$APP/wa" "$BIN_DIR/wa"
  ln -sf "$APP/wa-allow" "$BIN_DIR/wa-allow"
  case ":$PATH:" in *":$BIN_DIR:"*) ;; *) say "note: add $BIN_DIR to PATH (echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.zshrc)";; esac

  if $was_running; then do_service; fi
  if [ -d "$WA_HOME/cursor-workspace" ]; then do_cursor; fi
  say "installed to $APP"
  [ -f "$WA_HOME/whatsapp.db" ] || say "next: install.sh pair [phone-with-country-code]"
}

paired() {
  [ -f "$WA_HOME/whatsapp.db" ] && [ -n "$(sqlite3 "file:$WA_HOME/whatsapp.db?mode=ro" 'select jid from whatsmeow_device limit 1' 2>/dev/null)" ]
}

do_pair() {
  [ -x "$APP/whatsapp-bridge" ] || die "run install.sh first"
  paired && { say "already paired"; do_service; return; }
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  local log="$WA_HOME/pair.log" args=()
  [ -n "${1:-}" ] && args=(-pair-phone "${1//[^0-9]/}")
  rm -f "$WA_HOME/pair-code.txt" "$WA_HOME/qr.png"
  : > "$log" && chmod 600 "$log"
  WA_HOME="$WA_HOME" "$APP/whatsapp-bridge" "${args[@]}" >"$log" 2>&1 &
  local pid=$!
  trap 'kill $pid 2>/dev/null || true' EXIT

  for _ in $(seq 1 30); do
    [ -s "$WA_HOME/pair-code.txt" ] || [ -s "$WA_HOME/qr.png" ] && break
    kill -0 $pid 2>/dev/null || { cat "$log" >&2; die "bridge exited"; }
    sleep 1
  done
  if [ -s "$WA_HOME/pair-code.txt" ]; then
    say "PAIRING CODE: $(cat "$WA_HOME/pair-code.txt")"
    say "phone: WhatsApp → Settings → Linked devices → Link a device → 'Link with phone number instead'"
  elif [ -s "$WA_HOME/qr.png" ]; then
    open "$WA_HOME/qr.png"
    say "scan the QR that just opened (phone: WhatsApp → Settings → Linked devices → Link a device)"
  else
    die "no pairing code or QR after 30s; see $log"
  fi

  say "waiting up to 3 minutes for the phone…"
  for _ in $(seq 1 180); do
    grep -q "Connected to WhatsApp!" "$log" && break
    kill -0 $pid 2>/dev/null || { tail -5 "$log" >&2; die "bridge exited before pairing"; }
    sleep 1
  done
  grep -q "Connected to WhatsApp!" "$log" || die "timed out; run install.sh pair again"
  kill $pid 2>/dev/null; wait $pid 2>/dev/null || true
  trap - EXIT
  rm -f "$log"
  say "paired"
  do_service
}

do_service() {
  paired || die "not paired yet: install.sh pair [phone]"
  mkdir -p "$(dirname "$PLIST")"
  cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$APP/whatsapp-bridge</string></array>
  <key>EnvironmentVariables</key><dict><key>WA_HOME</key><string>$WA_HOME</string></dict>
  <key>WorkingDirectory</key><string>$WA_HOME</string>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>30</integer>
  <key>StandardOutPath</key><string>$WA_HOME/bridge.log</string>
  <key>StandardErrorPath</key><string>$WA_HOME/bridge.log</string>
</dict></plist>
PLIST
  touch "$WA_HOME/bridge.log" && chmod 600 "$WA_HOME/bridge.log"
  launchctl bootout "gui/$(id -u)/$OLD_LABEL" 2>/dev/null || true
  rm -f "$HOME/Library/LaunchAgents/$OLD_LABEL.plist"
  stop_service
  # bootstrap can fail briefly right after a bootout (exit 5); retry
  local i
  for i in 1 2 3 4 5; do
    launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null && break
    [ "$i" = 5 ] && die "could not start the bridge service (launchctl bootstrap failed)"
    sleep 2
  done
  service_loaded || die "bridge service did not start"
  say "bridge service running (log: $WA_HOME/bridge.log)"
}

service_loaded() { launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; }

# stop_service unloads the bridge and waits until launchd has really let it go.
stop_service() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  local i
  for i in $(seq 1 20); do
    service_loaded || return 0
    sleep 0.5
  done
  die "bridge service did not stop"
}

CURSOR_HOOKS="$HOME/.cursor/hooks.json"

do_cursor() {
  [ -x "$APP/cursor/cursor-guard.sh" ] || die "run install.sh first"
  local ws="$WA_HOME/cursor-workspace" guard="$APP/cursor/cursor-guard.sh"
  mkdir -p "$ws/.cursor/rules"
  jq '{mcpServers: {whatsapp: (.mcpServers.whatsapp + {type: "stdio"})}}' "$WA_HOME/mcp.json" > "$ws/.cursor/mcp.json"
  { printf -- '---\ndescription: How to read, triage and reply to WhatsApp chats safely\nalwaysApply: true\n---\n'
    awk 'f>=2{print} /^---$/{f++}' "$APP/cursor/whatsapp-triage.md"; } > "$ws/.cursor/rules/whatsapp-triage.mdc"

  # Guard hooks in the user-level hooks file (every Cursor window), keeping any other hooks
  mkdir -p "$(dirname "$CURSOR_HOOKS")"
  [ -f "$CURSOR_HOOKS" ] || echo '{"version": 1, "hooks": {}}' > "$CURSOR_HOOKS"
  [ -f "$CURSOR_HOOKS.bak-whatsapp" ] || cp "$CURSOR_HOOKS" "$CURSOR_HOOKS.bak-whatsapp"
  jq --arg cmd "$guard" '
    .version = (.version // 1)
    | .hooks = (.hooks // {})
    | reduce ("beforeMCPExecution", "beforeShellExecution") as $e (.;
        .hooks[$e] = ([(.hooks[$e] // [])[] | select((.command // "") | test("cursor-guard\\.sh$") | not)]
                      + [{command: $cmd, failClosed: true, timeout: 10}]))
  ' "$CURSOR_HOOKS" > "$CURSOR_HOOKS.tmp" && mv "$CURSOR_HOOKS.tmp" "$CURSOR_HOOKS"

  ln -sf "$APP/wa-cursor" "$BIN_DIR/wa-cursor"
  say "Cursor: workspace $ws, guard in $CURSOR_HOOKS; open it with wa-cursor"
}

remove_cursor_hooks() {
  [ -f "$CURSOR_HOOKS" ] || return 0
  jq '.hooks |= with_entries(.value |= map(select((.command // "") | test("cursor-guard\\.sh$") | not)))' \
    "$CURSOR_HOOKS" > "$CURSOR_HOOKS.tmp" && mv "$CURSOR_HOOKS.tmp" "$CURSOR_HOOKS"
}

do_status() {
  say "data dir:  $WA_HOME $( [ -d "$WA_HOME" ] && echo ok || echo MISSING)"
  say "app:       $( [ -x "$APP/whatsapp-bridge" ] && echo installed || echo 'not installed')"
  say "paired:    $(paired && echo yes || echo no)"
  if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    say "service:   $(launchctl print "gui/$(id -u)/$LABEL" | awk '/state =/{print $3; exit}')"
  else
    say "service:   not loaded"
  fi
  say "allowlist: $(jq -r '"\(.allow_chats | length) chats, direct=\(.allow_direct_chats)"' "$WA_HOME/config.json" 2>/dev/null || echo none)"
  say "launcher:  $(command -v wa || echo "not on PATH ($BIN_DIR)")"
  say "cursor:    $( [ -f "$WA_HOME/cursor-workspace/.cursor/mcp.json" ] && echo "workspace ok" || echo "not set up") / guard $(jq -r '[.hooks[]?[]? | select((.command // "") | test("cursor-guard"))] | length' "$CURSOR_HOOKS" 2>/dev/null || echo 0) hooks"
  say "last log:  $(tail -1 "$WA_HOME/bridge.log" 2>/dev/null || echo -)"
}

do_uninstall() {
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootout "gui/$(id -u)/$OLD_LABEL" 2>/dev/null || true
  remove_cursor_hooks
  rm -f "$PLIST" "$HOME/Library/LaunchAgents/$OLD_LABEL.plist" "$BIN_DIR/wa" "$BIN_DIR/wa-allow" "$BIN_DIR/wa-cursor"
  rm -rf "$APP"
  say "removed service and launchers; data kept in $WA_HOME (delete it to unlink fully, and remove the device in WhatsApp → Linked devices)"
}

case "${1:-install}" in
  install) do_install ;;
  pair) shift; do_pair "${1:-}" ;;
  service) do_service ;;
  cursor) do_cursor ;;
  status) do_status ;;
  uninstall) do_uninstall ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac
