# Commit conventions

Back to [contributing](./README.md).

- **Subject:** imperative, ≤ 72 characters, no trailing period (`Add pairing-code login`, `Fix outbox symlink escape`).
- **Body:** why, then what; wrap at ~72. Name the threat from the [security model](../architecture/security-model.md)
  when a guard file changes.
- **One meaningful step per commit.** Within a PR, the ADR or doc commit comes before the code commit
  ([documentation mandate](./documentation-mandate.md)).
- **Attribution:** AI-assisted commits end with a `Co-Authored-By:` trailer.
- **Identity:** commit with your GitHub no-reply address, not an employer address.
- Never commit real phone numbers, chat names, message text, `~/.whatsapp-mcp` files or tokens.
