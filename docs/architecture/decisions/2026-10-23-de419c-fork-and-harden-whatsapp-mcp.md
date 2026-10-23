# 2026-10-23-de419c — Build on a hardened fork of lharries/whatsapp-mcp

- **Status:** accepted
- **Date:** 2026-10-23
- **Deciders:** Utkarsh Upadhyay
- **Scope:** repo
- **Supersedes / Amends:** —

## Context
The goal is to read, triage and reply to a **personal** WhatsApp account, including membership of 200+ groups,
from an AI coding assistant. WhatsApp offers no official API for personal accounts. The only practical route is
to act as a *linked device* (as WhatsApp Web does) through an unofficial protocol library. A widely used MCP
project, [lharries/whatsapp-mcp](https://github.com/lharries/whatsapp-mcp), already pairs the Go library
[whatsmeow](https://github.com/tulir/whatsmeow) with a Python MCP server.

Reviewing upstream at `7d6a06dc` (2025-07-13) found it unsafe to run as is:
- its local send API listened on **all interfaces with no authentication**, and `media_path` read **any file**;
  anyone on the same network could send as the user or pull files off the machine through WhatsApp;
- document downloads wrote to a path built from the **sender-chosen filename** (path traversal);
- every message's text was **logged**;
- the MCP server `print()`ed to stdout, corrupting the MCP protocol stream;
- its whatsmeow pin was seven months old and needed API changes to build against current releases.

## Decision
Vendor upstream into `plugins/whatsapp/{bridge,server}` at `7d6a06dc` and maintain it as a fork with the fixes
above, then build the allowlist ([e302a3](./2026-10-23-e302a3-allowlist-gates-content-and-sends.md)), the
`digest` tool, pairing-code login and the plugin packaging on top. The upstream licence is kept in
[`LICENSE.upstream`](../../../plugins/whatsapp/LICENSE.upstream). whatsmeow is kept current through Dependabot.

## Assumptions
- 1. WhatsApp has no official API for personal (non-Business) accounts (true 2026-10-23).
- 2. whatsmeow is actively maintained and tracks WhatsApp protocol changes (latest pseudo-version 2026-10-17).
- 3. Upstream whatsapp-mcp is not maintained (no commits since 2025-07-13), so fixes can't be sent upstream and
     waited on.

## Reversal triggers
- Revisit if WhatsApp ships an official API usable with personal accounts (Assumption #1).
- Revisit if whatsmeow stops being maintained or a protocol change breaks it for weeks (Assumption #2).
- Revisit if upstream resumes and accepts the security fixes; then track upstream instead of a fork (Assumption #3).

## Consequences
- Using an unofficial client is against WhatsApp's terms; a small risk of the number being restricted is
  accepted and stated in the README and [security model](../security-model.md).
- The repo owns the security of the bridge, so the bridge carries its own tests and guard-file review.
- whatsmeow upgrades can break the build (they did once: added `context.Context` parameters); CI catches it.

## Alternatives considered
- **WhatsApp Business Cloud API:** official, but business numbers only, webhooks, 24-hour reply window. Rejected
  under Assumption #1; it can't read a personal account's groups.
- **Run upstream unmodified:** rejected for the security defects above.
- **Write a bridge from scratch on whatsmeow:** rejected; upstream's storage and tool surface were sound and the
  defects were local fixes.
- **Browser automation of WhatsApp Web:** rejected; brittle, heavier, and no better on terms of service.
