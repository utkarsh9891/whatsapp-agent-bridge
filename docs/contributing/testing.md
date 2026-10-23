# Testing

Back to [contributing](./README.md). Every CI job is a required check on `main`.

| CI job | Runs | Locally |
|---|---|---|
| `bridge` | gofmt, `go vet`, `go test`, build | `cd plugins/whatsapp/bridge && gofmt -l . && go vet ./... && go test ./...` |
| `server` | digest tests (fixture written by the bridge's own `MessageStore`), MCP server lists its tools | `cd plugins/whatsapp/server && uv run --with pytest python -m pytest tests -q` |
| `plugin` | manifest checks, shellcheck, Claude bypass-guard test (12 cases, incl. under Cursor), Cursor taint-guard test (19 cases) | `plugins/whatsapp/hooks/test-bypass-guard.sh && plugins/whatsapp/cursor/test-cursor-guard.sh` |
| `docs` | documentation gate | `python3 scripts/check-docs.py` |

**Fixtures match the writer.** Test databases are produced by the bridge's real writer
(`bridge/fixture_test.go`), never hand-built, so the tests read exactly what production writes.

**Guard changes need a live check too.** After changing a guard or upgrading Claude Code, rerun the live checks
listed in the [security model](../architecture/security-model.md) "Proven by" column with `claude -p` against a
fixture `WA_HOME`.
