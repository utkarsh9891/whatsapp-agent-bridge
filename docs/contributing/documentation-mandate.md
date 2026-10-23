# Documentation mandate

Back to [contributing](./README.md).

1. **Doc first, in order.** A change that alters behaviour, a guard, a module's contract or a design choice
   commits its documentation **before** the code, in the same PR: an ADR when a decision could later be
   reversed ([decisions](../architecture/decisions/README.md)), otherwise the affected module README, guide,
   runbook or [security model](../architecture/security-model.md). Code first, docs after is a violation even if
   both land together.
2. **No merge without the doc update.** A PR that changes behaviour and no `.md` is incomplete.
3. **Every document is reachable from [`AGENTS.md`](../../AGENTS.md).** New docs are linked from the nearest index.
4. **Every module has a `module.yaml` and a `README.md`.** `module.yaml` is the machine-readable source of a
   module's purpose, dependencies and commands; keep it in sync with the build files.
5. **Current state only.** Docs describe how things are now; history belongs in ADRs, the
   [CHANGELOG](../../CHANGELOG.md) and git.
6. **Code comments don't count** as the documentation this mandate requires; they explain lines, docs explain
   purpose, alternatives and reversal.

Enforced by [`scripts/check-docs.py`](../../scripts/check-docs.py) (CI job `docs`): module manifests present,
relative links resolve, every `.md` reachable from `AGENTS.md`, ADR filenames and headers valid, every ADR indexed.
