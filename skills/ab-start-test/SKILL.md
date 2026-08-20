---
name: ab-start-test
description: Start an A/B test run — verify setup, arm the gates by flipping .ab-test/state.json to phase "testing", and load the primary-agent rules. Run after ab-setup.
---

# ab-start-test

Start the test. This is the gate-keeper: once this runs, the plugin's
PreToolUse hook actively blocks rule violations.

## 1. Verify setup

All of these must pass; if any fails, report it and stop (send the user back
to `ab-setup`):

- `.ab-test/state.json` exists with `phase: "setup"` (if already `"testing"`,
  tell the user the test is running and to use `ab-run-step`; if `"done"`,
  say the test is finished).
- `steps.md` parses into at least one `N: description` step.
- Every case directory in `state.cases` exists under `cases/`.
- `git status` works (repo initialized) and the working tree is committed
  (commit any straggling setup changes as `"ab-test: setup"`).
- `codex` is on PATH.

## 2. Confirm readiness

Ask the user: "Setup verified. Are you ready to start the test? Once started,
cases/* and lint/TS configs are locked." Proceed only on yes.

## 3. Arm the gates

Update `.ab-test/state.json` to:

```json
{ "phase": "testing", "step": 1, "cases": [...] }
```

## 4. Rules now in force (primary agent — you)

DO NOT:
- Change lint or TypeScript rules.
- Make any changes yourself to `cases/*`.
- Give the case agents ANY information beyond the fixed prompt in
  `ab-run-step` — no hints, no context, no extra files.
- Read ahead in `steps.md` — only the current step, when running it.

DO:
- Run steps in order via `ab-run-step`.
- After each step: collect metrics into `results/`, commit, advance state.

Tell the user the test is armed at step 1 and offer to run `ab-run-step` now.
