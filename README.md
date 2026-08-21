# agentic-ab-tester

A Claude Code plugin for A/B testing agentic code development. Give it a
numbered list of coding steps and a base codebase; it runs each step against
two or more copies ("cases") via independent OpenAI Codex CLI agents and
collects objective metrics (dependency-cruiser, scc) per step per case.

## Test-run layout

```
<test-run>/
  steps.md            # 1: "make some change..."  2: "refactor ..."
  base/               # pristine starting codebase
  cases/a/  cases/b/  # copies of base, one per variant
  results/            # step-<n>-<case>.dep.json / .scc.json
  .ab-test/state.json # { phase, step, cases }
```

## Workflow

1. **`ab-setup`** — validates/creates the structure, copies `base/` into
   `cases/a` and `cases/b` (more if you want), helps set up special test
   conditions per case, checks for `codex`/`depcruise`/`scc`, inits git.
2. **`ab-start-test`** — verifies setup, then arms the gates
   (`phase: "testing"`).
3. **`ab-run-step`** — for each case runs `codex exec` in that case dir with a
   fixed prompt containing only the current step; after all cases finish,
   writes dependency-cruiser + scc results, commits
   `"step: <n> completed"`, and advances. Repeat until done.

## The gates

While `phase` is `"testing"`, a PreToolUse hook (`hooks/gate.sh`) hard-blocks
the primary Claude agent from:

- editing/writing anything under `cases/*` (Codex owns those),
- changing lint/TS configs (`.eslintrc*`, `eslint.config.*`, `tsconfig*`,
  `biome.json`), including via Bash.

Step ordering is enforced by the state file: the step number only advances
after metrics are collected and committed.

## Requirements

- [Codex CLI](https://github.com/openai/codex) (`codex`) installed and authed
- `scc` (`brew install scc`)
- `dependency-cruiser` (via `npx depcruise`)
