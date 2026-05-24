---
description: Add a new ad-hoc function to ~/src/op/quickfixes.py
argument-hint: <description of what the quickfix should do>
allowed-tools: Read, Edit, Bash(uv pip show:*), mcp__postgres__*
---

Add a new ad-hoc function to `~/src/op/quickfixes.py` that does the following:

$ARGUMENTS

## Rules

- Append the new function **just before** the `if __name__ == "__main__":` block at the bottom of the file. Do not touch unrelated code unless the task is to modify an existing quickfix.
- It **is** OK to modify or extend an existing function in this file when the task is a continuation/iteration of a previous quickfix. Prefer editing in place over duplicating a near-identical function.
- The file is a flat module of one-off ops scripts — keep the new code at module level, do **not** introduce classes or wrap things in `main()`.
- Reuse the globals already defined in the file: `session`, `m` (zefire models), `pe` (peregreen client), `logger`, `console`, `zefire`. Do **not** redefine them.
- Reuse existing top-of-file imports (`sa`, `pd`, `tqdm`, `mock`, `flag_modified`, `TypeAdapter`, …). If you need a new import that's not already there, add it to the top of the file alongside the existing imports — do **not** import inside the function unless it's a heavy/optional dependency that follows a pattern already used in the file.
- For write operations: `session.add(...)` / `session.flush()` then `__import__("pdb").set_trace()  # BREAKPOINT` then `session.commit()`. The breakpoint before commit is intentional — keep it so the user can inspect before committing.
- Use `logger.info(...)` / `logger.warning(...)` for progress messages, `tqdm(...)` for loops over many items.
- Give the function a descriptive snake_case name (e.g. `fixup_xxx`, `checkup_xxx`, `backfill_xxx`) matching the existing naming style.
- **Caller placement:** the new caller goes **inside** the `if __name__ == "__main__":` block, after the existing `setup()` call, under a banner line `# ------- QFIX CLAUDE ------`. If the banner already exists inside that block, append the new caller below the existing ones; if not, add the banner first (still inside the block, after `setup()`).
  - **Always comment out any other callers already present below the banner** so only the new caller is active. The new caller goes **last** (at the very bottom of the file) and is the only uncommented one. This keeps the file in a "ready to run the latest fix" state without losing the history of previous quickfix calls.
  - Example shape (after this command runs, with two prior quickfixes already in the file):

  ```python
  if __name__ == "__main__":
      setup()
      # ------- QFIX CLAUDE ------
      # fixup_aaa()
      # fixup_bbb()
      fixup_xxx()
  ```
- Do **not** run the function. Do **not** run tests. This is an ad-hoc script file — it is exercised manually by the user.
- Do **not** add docstrings or comments narrating what the code does. Add a short comment only if there's a non-obvious "why".

## Data-oriented quickfixes

If the task involves inspecting, reconciling, or mutating database rows (i.e. you need to know the actual shape, counts, distinct values, or relationships of data before writing the function), use the **postgres MCP** (`mcp__postgres__*`) to gather that context first:

- `list_schemas` / `list_objects` / `get_object_details` to discover tables and columns.
- `execute_sql` for read-only exploratory queries (counts, samples, distinct values, joins) — never use it for writes; writes still go through `session` in the quickfix.
- `explain_query` / `analyze_query_indexes` if a query is going to scan a large table and you want to confirm it's reasonable before committing it to the file.

Surface the relevant findings (row counts, edge cases, ambiguous data) before writing the function so the implementation is informed by the real data, not assumptions.
