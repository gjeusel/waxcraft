---
description: Trim the code and tests added on this branch down to what the change needs
argument-hint: "[file or scope]"
---
Slim down what this branch added against its base branch (`master` or `main`, whichever exists), plus
any uncommitted changes. Behavior must stay the same.

- Tests: follow the python-unittest skill for Python. Keep the tests that pin the new behavior at its
  boundaries, merge near-duplicates into parametrized cases, and drop tests that only restate the
  implementation, cover trivial plumbing, or duplicate existing coverage.
- Code: follow the simplify skill. Inline helpers used once, remove dead branches, speculative options,
  and defensive checks the callers cannot trigger, and reuse existing utilities over new ones.
- Touch only what this branch added or changed; leave pre-existing code alone.
- Run the affected tests and checks, then summarize what was removed and why. Do not commit.

Scope: ${@:-the whole branch}
