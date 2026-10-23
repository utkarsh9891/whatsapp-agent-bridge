## What and why

<!-- One or two sentences. Link an issue if there is one. -->

## Checklist

- [ ] Tests run locally (`go test ./...` in `bridge/`, `pytest` in `server/`) and CI is green
- [ ] Touches a guard file (`bridge/config.go`, `hooks/`, `wa/settings.json`, `bin/wa`, `bin/install.sh`)? Explain what still stops a send in bypass mode
- [ ] No real phone numbers, chat names, message text or tokens in code, tests or this PR
- [ ] Bumped `version` in `plugins/whatsapp/.claude-plugin/plugin.json` if users need to reinstall
