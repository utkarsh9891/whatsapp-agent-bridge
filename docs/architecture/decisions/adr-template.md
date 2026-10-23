# YYYY-MM-DD-<hash> — <short decision title>

<!--
  Filename: YYYY-MM-DD-<hash>-<slug>.md — UTC authoring date + `openssl rand -hex 3` + a short slug.
  Add a row to ./README.md in the same PR. Rules: ./README.md.
-->

- **Status:** accepted   <!-- accepted | superseded by <id> | amended by <id>. `proposed` only on a draft PR. -->
- **Date:** YYYY-MM-DD
- **Deciders:** <names>
- **Scope:** bridge | server | plugin | repo
- **Supersedes / Amends:** <adr-id> | —

## Context
The durable problem and its constraints. Facts that can expire belong under **Assumptions**.

## Decision
The choice, stated plainly.

## Assumptions
Numbered, each datable or falsifiable. If one flips, this decision reopens.
- 1. <…>

## Reversal triggers
1–3 "revisit if…" conditions, usually the negation of an assumption.
- <…>

## Consequences
What gets easier, harder or newly required. Blast radius and follow-up work.

## Alternatives considered
One line each; pin a rejection to the assumption it depends on (`Rejected under Assumption #1`).

<!-- Superseding or amending ADRs only:
## What changed since <prior-adr-id>
The expired assumption, named. -->
