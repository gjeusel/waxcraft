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
<!-- code-review:start -->
## Code review

<Same one-line count/verdict and clean/skipped-axis statuses.>

### <Axis with findings>

1. ![P2](https://img.shields.io/badge/P2-daff01?style=flat-square) **<Consequence title>** · [<path>:<line>](<source-project-url>/-/blob/<full-sha>/<path>#L<line>)

   <Same short impact paragraph, with any rule/requirement citation inline.>

   ```diff
   <Same verbatim diff excerpt.>
   ```

<sub>Reviewed <scope and SHAs> · Spec: <source, if any> · Checks: <actual results/limits></sub>
<!-- code-review:end -->
````

The `code-review:start`/`end` markers delimit the review section inside the MR description; they
render invisibly and must not appear anywhere else in the review body.

Badge colours: `P0` → `ff6d6d`, `P1` → `ff9c7f`, `P2` → `daff01`, `P3` → `c4c4c4`.
Priority definitions and inclusion thresholds remain in `SKILL.md`.

Link changed lines to the reviewed full head SHA in the source project; link deleted lines to the
base-side revision/path. Encode paths correctly and use narrow line anchors (`#L42` or `#L42-45`).
For an explicitly authorized local-snapshot report, use plain locations where a permalink cannot
resolve. Link issue/spec citations directly when available.

A clean review needs only the verdict/status line and scope/check metadata. HTML is only for the
small metadata footer: omit confidence scores, collapsible narrative summaries, and repeated evidence.

## Publish and verify

Publish the review into the MR description, not as a note. Use inline threads only if requested.
Target an explicit project and MR IID through the REST API, for example
`glab api projects/<id>/merge_requests/<iid>` to read and the same endpoint with `--method PUT` and
`--field description=@<file>` to write. Pass Markdown through a file or stdin so shell expansion
cannot alter backticks or code; consult the installed command's help for supported flags.

Fetch the current description immediately before writing and splice the review section into it:

- **One marked section** (`<!-- code-review:start -->` … `<!-- code-review:end -->`): replace it,
  markers included, in place.
- **No markers, but an earlier unmarked `## Code review` section:** replace from that heading up
  to the next heading of the same or higher level, or the end of the description.
- **Neither:** append the section after the existing content, separated by one blank line. An empty
  description becomes the section alone.
- **Malformed markers** (unmatched or repeated): do not guess; show the terminal review and ask.

Everything outside the review section stays byte-for-byte identical: never rewrite, reformat, or
trim the author's content. Do not change the title, labels, or any other MR field.

Read the description back after writing: the review section must match the prepared Markdown, and
the surrounding content must match what was fetched. If it changed concurrently, re-splice against
the fresh description rather than overwriting the newer edit. After a timeout, read back before
retrying; the splice is idempotent. Return the MR `web_url`. Keep the prepared Markdown on
publication failure and state the blocker rather than claiming it was uploaded.
