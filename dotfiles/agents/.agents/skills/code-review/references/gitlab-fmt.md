# GitLab review output

Render the canonical review from `SKILL.md`; this is a presentation adapter, not another review pass.
Keep the terminal and MR versions identical in substance, including diff excerpts and caveats.

## Select the MR

Use an explicitly targeted MR; otherwise find open MRs for the reviewed source branch with `glab`.
Resolve the GitLab host and project from the repository, and verify source project/branch as well as
target project (especially for forks). Never select an unrelated MR just because it exists.

- No matching MR: retain terminal output; do not create one.
- Multiple matches: show the terminal review and ask which MR should receive it.
- Lookup/authentication failure: report the blocker, not "no MR exists."
- Before posting, recheck that the MR head SHA matches the reviewed committed snapshot. If it moved,
  or the review includes unpushed/uncommitted changes, retain the terminal review and explain the
  mismatch. Ask before posting a clearly labelled local-snapshot review; never push to align it.
  A deliberately narrower range or path scope is fine when identified in the report.

## Render GitLab-flavoured Markdown

Use the same concise body and per-axis ordering as the terminal review. Replace plain priority labels
with badges and local locations with commit-pinned links. Keep clean/skipped-axis statuses on one
line; only axes with findings need headings. Use this shape, replacing the placeholders:

````markdown
## Code review

<Same one-line count/verdict and clean/skipped-axis statuses.>

### <Axis with findings>

1. ![P2](https://img.shields.io/badge/P2-daff01?style=flat-square) **<Consequence title>** · [<path>:<line>](<source-project-url>/-/blob/<full-sha>/<path>#L<line>)

   <Same short impact paragraph, with any rule/requirement citation inline.>

   ```diff
   <Same verbatim diff excerpt.>
   ```

<sub>Reviewed <scope and SHAs> · Spec: <source, if any> · Checks: <actual results/limits></sub>
````

Badge colours: `P0` → `ff6d6d`, `P1` → `ff9c7f`, `P2` → `daff01`, `P3` → `c4c4c4`.
Priority definitions and inclusion thresholds remain in `SKILL.md`.

Link changed lines to the reviewed full head SHA in the source project; link deleted lines to the
base-side revision/path. Encode paths correctly and use narrow line anchors (`#L42` or `#L42-45`).
For an explicitly authorized local-snapshot report, use plain locations where a permalink cannot
resolve. Link issue/spec citations directly when available.

A clean review needs only the verdict/status line and scope/check metadata. HTML is only for the
small metadata footer: omit confidence scores, collapsible narrative summaries, and repeated evidence.

## Publish and verify

Post one general MR note through `glab`, targeting an explicit project and MR IID. Use inline
threads only if requested. Pass Markdown through stdin or a safely serialized payload so shell
expansion cannot alter backticks or code. Consult the installed command's help for supported flags.

Read the resulting note back and compare its body with the prepared Markdown before reporting
success; return the note URL. If a request times out or a retry is needed, check for an identical
note by the same author on that MR first. Keep the prepared Markdown on publication failure and
state the blocker rather than claiming it was uploaded.
