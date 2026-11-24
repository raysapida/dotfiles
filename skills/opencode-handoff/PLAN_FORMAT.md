# Plan format for a smaller executing model

A plan is executable when a model that can't make judgement calls can still
follow it, and knows when to stop.

## Required sections

1. **Header block**
   - Executor instructions: follow the steps in order, run every Verify, and
     stop and report on any STOP condition.
   - A **drift check**: `git log --oneline -1` must be commit X or a
     descendant, and `git diff --stat X..HEAD -- <files>` must be empty.
     Otherwise STOP.
2. **Status**: priority, effort, risk, dependencies, branch, and the commit the
   plan was written against.
3. **Why this matters**: two or three sentences with evidence (log lines,
   file:line). The agent uses it to judge edge cases.
4. **Current state**: quoted code at exact `file:line`, the facts the steps
   rely on, and gotchas (line endings, hooks that stage files, local edits
   that must never be staged).
5. **Scope**: in scope (the only files to touch) and out of scope.
6. **Git workflow**:
   - branch;
   - commit message(s);
   - project commit conventions;
   - "do not push".
7. **Steps**. Each step has exact edits and ends with a **Verify** command and
   its **expected output**.
8. **Test plan**, **Done criteria** (as a checklist), **STOP conditions**, and
   **Maintenance notes**.

## Rules that prevented problems

- **Expected values come from real data.** Take them from an existing log,
  measurement or test run, and name the source ("reference: bench_020.log,
  W2 recovery 25.1 s, pass ≤ 35 s"). An estimated count ("about 115 frames")
  produced a false STOP.
- **Give ranges, not exact moments, for anything timing-based.** Say when an
  event happens relative to something else ("at the first request after the
  window ends").
- **Write STOP conditions narrowly, and list expected differences.** A parity
  check that ignored known harmless differences (a version stamp, a known
  local edit) would have avoided a false STOP.
- **Nothing interactive.** No `git add -p`, editors or prompts. To stage part
  of a file, write a patch into the project temp folder and run
  `git apply --cached --unidiff-zero`.
- **State the one-thing-at-a-time constraints**: one build at a time,
  exclusive hardware, which folder temp files go in.
- **Name the files for each commit**, and say to check `git show --stat HEAD`
  after committing. That catches hooks that stage extra files.
- **Keep safety checks in code, not in prose**, when the plan builds tooling. A
  guard the agent can skip isn't a guard.
- **Say where things must happen.** "Before anything is written" or "before
  flashing" must be explicit. An agent put a pre-flash check after the flash.
- **Split big work into step groups with one commit each,** so a STOP leaves a
  clean, reviewable state.
- **When a plan removes or renames something, search the whole repo for it
  while planning**, including headers and test mocks. Put every hit in the
  steps or in the expected output. A removal plan that only listed the main
  source file missed a header declaration, a second `#ifdef` and two mock
  files; the agent's Step 0 check caught it and stopped.
- **Leave design-level plans (no numbered steps) for Claude**, or refine them
  into steps before handing them off.
- **When you refresh an old plan, re-check every section, not just the line
  numbers.** That includes the drift check base, the Git workflow (the branch
  name) and the scope. The prompt and the plan must agree: when they
  conflicted over the branch, the agent followed the plan and created a new,
  plan-numbered branch.
