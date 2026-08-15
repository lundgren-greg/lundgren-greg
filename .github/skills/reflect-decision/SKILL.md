---
name: reflect-decision
description: >
  Capture a product decision or clarification the user just made in chat and
  update the authoritative docs so they reflect the latest point. Use when the
  user clarifies semantics, changes scope, defers a feature to a later release,
  says "update the docs to reflect that", or runs /reflect-decision.
---

# Reflect decision

Chat is not a record. When the user states or clarifies a decision, land it in
the docs in the same session, on a branch + PR (never `main`).

## Steps

1. **State the decision back in one sentence** (what changed, what release it
   lands in, what stays out of scope). If any part is ambiguous, ask before
   writing.
2. **Update every authoritative doc that speaks to the point:**
   - `docs/design.md` — scope/non-goals, K-rules, and any PR-plan entry the
     decision changes. Fix contradictions; do not add a duplicate paragraph
     next to a stale one.
   - `docs/FEATURES.md` — feature rows: mark release (R1/R2), add or reword
     the row.
   - `PROJECT.md` — append a dated row to **Decisions log**; update
     **Resolved questions** if the decision answers one.
3. **Search for stale contradictions** the decision invalidates:
   `grep` the key terms across `docs/`, `PROJECT.md`, `README.md`, and wiki
   drafts. Reword or delete anything that now says the opposite.
4. **One source of truth:** the full rationale lives in `docs/design.md`;
   other files link or summarize in one line.
5. **Ship it:** branch `docs/<short-slug>`, commit
   (`docs: reflect decision — <slug>` + Copilot trailer), push, open a PR for
   Greg. Docs-only changes need no test run.

## Guardrails

- Never weaken a safety rule (last-copy, typed plan id, no share links,
  no telemetry) as a side effect of rewording.
- If the decision conflicts with an existing hard rule, stop and surface the
  conflict instead of silently editing the rule.
