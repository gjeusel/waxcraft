---
description: Add a new ad-hoc function to ~/src/op/quickfixes.py
argument-hint: <description of what the quickfix should do>
allowed-tools: Read, Edit, Bash(uv pip show:*)
---

Add a new ad-hoc function to `~/src/op/quickfixes.py` that does the following:

$ARGUMENTS

## Rules

- Append the new function **just before** the `if __name__ == "__main__":` block at the bottom of the file. Do not touch unrelated code.
- The file is a flat module of one-off ops scripts — keep the new code at module level, do **not** introduce classes or wrap things in `main()`.
- Reuse the globals already defined in the file: `session`, `m` (zefire models), `pe` (peregreen client), `logger`, `console`, `zefire`. Do **not** redefine them.
- Reuse existing top-of-file imports (`sa`, `pd`, `tqdm`, `mock`, `flag_modified`, `TypeAdapter`, …). If you need a new import that's not already there, add it to the top of the file alongside the existing imports — do **not** import inside the function unless it's a heavy/optional dependency that follows a pattern already used in the file.
- For write operations: `session.add(...)` / `session.flush()` then `__import__("pdb").set_trace()  # BREAKPOINT` then `session.commit()`. The breakpoint before commit is intentional — keep it so the user can inspect before committing.
- Use `logger.info(...)` / `logger.warning(...)` for progress messages, `tqdm(...)` for loops over many items.
- Give the function a descriptive snake_case name (e.g. `fixup_xxx`, `checkup_xxx`, `backfill_xxx`) matching the existing naming style.
- After adding the function, also add a commented-out call to it in the `if __name__ == "__main__":` block (matching the pattern of the existing commented entries there), so the user can uncomment to run it.
- Do **not** run the function. Do **not** run tests. This is an ad-hoc script file — it is exercised manually by the user.
- Do **not** add docstrings or comments narrating what the code does. Add a short comment only if there's a non-obvious "why".
