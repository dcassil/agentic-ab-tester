# A/B Tester Plugin — Design

Date: 2026-08-20
Status: Approved

## Purpose

A Claude Code plugin for A/B testing agentic code development. Given a numbered
list of coding steps and a base codebase, it runs each step against two or more
copies of the codebase ("cases"), each built by an independent OpenAI Codex CLI
agent, and collects objective metrics (dependency-cruiser, scc) per step per
case so the variants can be compared.

Goals: simple, well-gated, no over-engineering. The gates are real (hooks +
state file), not just instructions.

## Test-run layout

A "test run" is any directory with this structure:

```
<test-run>/
  steps.md            # numbered steps: 1: "make some change..." 2: "refactor..."
  base/               # pristine starting codebase (never modified after setup)
  cases/a/  cases/b/  # copies of base, one per variant (more allowed: c, d, ...)
  results/            # step-<n>-<case>.dep.json / step-<n>-<case>.scc.json
  .ab-test/state.json # { phase, step, cases }
```

`steps.md` format: one step per line, `N: description`. Steps run in order.

`state.json` fields:
- `phase`: `"setup"` | `"testing"` | `"done"`
- `step`: current 1-based step number (only meaningful in `testing`)
- `cases`: array of case names, e.g. `["a", "b"]`

## Components

### Skill: `ab-setup`
- Finds `steps.md` (asks for it if missing) and `base/` (asks if missing).
- If `cases/` has no case dirs, copies `base` → `cases/a` and `cases/b`.
- Asks whether there will be more cases than a and b; creates them if so.
- Asks whether the user wants help setting up special test conditions for any
  case, or will do it themselves.
- Checks that `codex`, `npx depcruise`, and `scc` are available; reports what
  is missing (does not install anything).
- Ensures git is initialized in the test-run directory.
- Writes `.ab-test/state.json` with `phase: "setup"`.

### Skill: `ab-start-test`
The gate-keeper. Verifies setup is complete (steps.md parses, cases exist, git
initialized, tools present), then flips state to `phase: "testing", step: 1`
and restates the primary-agent rules. Arming the state file arms the hook.

Primary-agent rules while testing:
- DO NOT change lint or TypeScript rules.
- DO NOT make any changes to `cases/*` yourself.
- DO NOT give the case agents any information beyond the fixed prompt.
- DO ensure git is initialized, run the case agents, collect metrics, commit.

### Skill: `ab-run-step`
Runs the current step from `state.json`:
1. Reads only the current step's text from `steps.md`.
2. For each case, runs `codex exec` with cwd set to that case directory and
   exactly this prompt (nothing else):

   > Plan and build this: \<step text\>. Do as well as possible and keep the
   > code clean. Do not look at any files outside this directory. Do not
   > change lint or TypeScript rules. Do not commit or push.

3. Cases run sequentially. After ALL cases finish:
   - dependency-cruiser per case → `results/step-<n>-<case>.dep.json`
   - scc per case → `results/step-<n>-<case>.scc.json`
   - `git commit -am "step: <n> completed"`
   - Advance `state.json` to the next step, or `phase: "done"` after the last.

### Hook: PreToolUse gate
One script, active only when a `.ab-test/state.json` is found with
`phase: "testing"`. It blocks the primary agent from:
- Writing/editing any file under `cases/*` (Edit, Write, and Bash writes).
- Editing lint/TS configs anywhere in the test run: `.eslintrc*`,
  `eslint.config.*`, `tsconfig*`, `biome.json`.
- Running a step out of order (state must show the prior step committed).

Outside `testing` phase, the hook is inert so setup and special-condition
editing work normally.

## Error handling
- Missing steps.md/base/tools: setup reports and asks; nothing proceeds.
- A codex agent failing: report the failure, do not run metrics or commit for
  that step; the step can be re-run.
- Hook blocks emit a clear message naming the violated rule.

## Testing
- A tiny fixture test run (few-file base, 2-step steps.md) exercised manually:
  setup → start-test → run-step, verifying results files, commits, and that
  hook blocks an attempted edit to `cases/a` during testing.

## Deliberately out of scope
- Configurable agent command (codex is hardcoded), parallel case execution,
  result analysis/scoring, installing missing tools, more than one concurrent
  test run per directory.
