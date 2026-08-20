---
name: ab-setup
description: Set up an A/B test run in the current directory — validate steps.md and base/, create cases, check tools, init git, write .ab-test/state.json. Run this first, before ab-start-test.
---

# ab-setup

Set up an A/B test run in the current working directory. Follow these steps in
order. Ask the user only the questions listed; keep everything else automatic.

## 1. steps.md

Look for `steps.md` in the current directory. If missing, ask the user for it
(they can point at a file to copy in, or paste steps for you to write).

Expected format, one step per line, run in order:

```
1: "make some change to the code"
2: "refactor something ..."
```

Parse it and confirm the step count with the user. If no lines match
`N: description`, show the problem and ask them to fix or let you fix it.

## 2. base/

Look for a `base/` directory containing the starting codebase. If missing, ask
the user where the base codebase is and copy it to `base/` (exclude
`node_modules`, `.git`, build output). `base/` is never modified after setup.

## 3. cases/

If `cases/` contains no case directories (single-word lowercase names like
`a`, `b`, `c`):

- Copy `base/` to `cases/a` and `cases/b` (again excluding `node_modules`,
  `.git`, build output — then run the project's install command in each case
  if it has one, e.g. `npm install`).
- Ask the user: "Will there be more cases than a and b?" Create any extras
  (`c`, `d`, ...) the same way.

If case directories already exist, list them and use those.

## 4. Special test conditions

Ask the user: "Do you want help setting up special test conditions for any
case (a, b, both, ...), or will you set those up yourself?"

- If they want help, make the edits they describe inside the named case
  directories. This is the ONLY phase in which you may touch `cases/*`.
- If they'll do it themselves, tell them to say so when done.

## 5. Tool check

Check availability (report missing ones; do NOT install anything):

```bash
command -v codex; command -v scc; npx --no-install depcruise --version
```

If `depcruise` is unavailable via `--no-install`, note that `npx depcruise`
will fetch it on first use — that is acceptable, just tell the user.

## 6. Git

Ensure the test-run directory is a git repository (`git init` if needed) and
that a `.gitignore` excludes `node_modules` and build output within cases.
Commit the setup state: `git add -A && git commit -m "ab-test: setup"`.

## 7. State file

Write `.ab-test/state.json`:

```json
{ "phase": "setup", "step": 0, "cases": ["a", "b"] }
```

(with the actual case list). Then tell the user setup is complete and to run
`ab-start-test` when they are ready to begin.
