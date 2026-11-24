# Reviewing an opencode run

The agent's report is a claim, not a result. Check it before telling the user
the plan is done.

## Every run

- [ ] **Commits:** `git log --oneline <start>..HEAD` matches the report.
      `git show --stat` for each commit touches only the files the plan
      scoped.
- [ ] **Nothing that must stay out was committed:** local config,
      allowlists, secrets, caches (`__pycache__`, build dirs), result folders,
      stray copies in the wrong folder (`git status --short`, `git ls-files`).
- [ ] **Project conventions:** commit-message rules, line endings (look for
      whole-file diffs), hooks that stage extra files, files never to stage.
- [ ] **Tests:** run the test suites yourself, rather than trusting the
      reported pass count.
- [ ] **Clean end state:** the working tree holds only expected leftovers, and
      shared hardware or services are back in their normal state.

## Read the code, not just the tests

- Read the diff of anything safety-critical, and **trace every path** to the
      dangerous action (e.g. every caller of a flash, delete or deploy
      function). A check that exists but runs too late, or a helper nobody
      calls, won't show up in a passing test.
- Look for dead helpers that skip a guard. A later agent may call them.
- Look for silent degradation: an `#if`/flag that falls back to a no-op, a
      default that disables a check, a missing include that changes behaviour.
- Compare each "expected" value in the report with the plan's source data.

## Decide on each finding

- **Small and clear:** fix it yourself as a follow-up commit, with a message
  that says what the review found.
- **The plan was wrong** (a STOP condition too strict, a bad estimate): fix
  the plan, and say so plainly in the continuation and to the user.
- **The agent's code is wrong and the fix is large:** send a continuation
  with the finding, the verified current state and the exact fix.
- Record the outcome in the plan's status or index: executor model, session
  id, result (done, or STOP and why), number of continuations, and follow-up
  commits.
- Record lessons for every finding a better plan would have prevented
  ([LESSONS.md](LESSONS.md)).

## Tell the user

Give a short verdict, what you verified yourself, any gap you found and how
it was fixed, and what still can't be verified (e.g. steps that need a human).
Say plainly when an issue was the plan's fault rather than the agent's.
