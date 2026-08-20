---
name: ab-run-step
description: Run the current A/B test step — dispatch a Codex agent per case with the fixed prompt, collect dependency-cruiser and scc metrics into results/, commit, and advance the step. Requires ab-start-test first.
---

# ab-run-step

Run the current step of an armed test. Requires `.ab-test/state.json` with
`phase: "testing"` — otherwise stop and point the user at `ab-start-test`.

## 1. Read the current step

Read `state.json` for `step` (N) and `cases`. Extract ONLY line `N:` from
`steps.md` (e.g. `grep '^N:' steps.md`). Do not read the other steps. If line
N does not exist, the test is over — set `phase: "done"` and report.

## 2. Run one Codex agent per case

For each case, sequentially, run from inside that case directory with EXACTLY
this prompt and nothing more:

```bash
cd cases/<case> && codex exec --full-auto "Plan and build this: <step text>. Do as well as possible and keep the code clean. Do not look at any files outside this directory. Do not change lint or TypeScript rules. Do not commit or push."
```

Do not add context, hints, or files to the prompt. Do not edit anything in
`cases/*` yourself. If codex is long-running, use a generous Bash timeout
(600000 ms) or run in the background and wait for completion.

If any case agent fails, report the failure and STOP — no metrics, no commit,
no state advance. The step can be re-run.

## 3. Collect metrics (only after ALL cases finish)

Ensure `results/` exists, then for each case:

```bash
npx depcruise cases/<case> --no-config --output-type json > results/step-<N>-<case>.dep.json
scc cases/<case> --format json > results/step-<N>-<case>.scc.json
```

(If the case has a dependency-cruiser config of its own, use it instead of
`--no-config`.)

## 4. Commit and advance

```bash
git add -A && git commit -m "step: <N> completed"
```

Then update `state.json`: if step N+1 exists in `steps.md`, set
`step: N+1`; otherwise set `phase: "done"`.

Report to the user: which cases ran, where the results files are, and either
the next step number or that the test is complete.
