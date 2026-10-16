---
name: code-review
description: 'Review branches, PRs/MRs, or working changes for bugs and standards/spec gaps. Use for code reviews, including "review since X".'
---

# Code review

Review deeply; report only findings worth the author's attention. Keep source files and Git state
unchanged: this is a review, not an implementation task.

## 1. Pin scope and delivery

Honor the requested ref, range, PR/MR, or working-tree scope. Otherwise use the MR target branch or
an unambiguous repository default; ask when the base is unclear. Resolve refs to SHAs and record the
diff command once. For a branch review use `git diff <base>...<head>` and the corresponding commit list.
Include staged, unstaged, and untracked files when reviewing working changes; do not silently add
them to an explicit committed range. Stop on an invalid ref; report an empty diff as "No changes."

Choose delivery independently of review scope (naming an MR is not a request for MR-only output):

| Requested destination                  | Deliver to                                                      |
| -------------------------------------- | --------------------------------------------------------------- |
| Terminal/local only, or no posting     | Terminal only                                                   |
| GitLab/MR only                         | MR note; return its URL in the terminal                         |
| A file or another explicit destination | That destination only                                           |
| Unspecified                            | Terminal **and** the matching existing GitLab MR, if one exists |

Honor explicit combinations. The default authorizes a review note, not creating an MR, pushing,
approving, or merging. A missing MR leaves a terminal-only review.

**GitLab output:** whenever a review will be posted to GitLab, including the unspecified-destination
default, read [references/gitlab-fmt.md](references/gitlab-fmt.md) before rendering or publishing.
It defines MR selection, GitLab formatting, and publication checks. Explicit local-only requests
need neither that reference nor an MR lookup for publication.

## 2. Review on two axes

Run separate passes yourself, keeping their evidence distinct:

- **Standards:** inspect the full scoped diff, surrounding code, callers, and tests for concrete bugs
  and violations of applicable repository guidance (`AGENTS.md`, `CLAUDE.md`, `REVIEW.md`,
  `CONTRIBUTING.md`, or coding standards). Correctness is always in scope, even without a spec.
- **Spec:** compare the change to the originating requirements. Prefer a user-supplied spec, then
  the linked issue/MR and commit references, then a relevant local spec. Use the repository's tracker
  workflow when available. Check missing, incorrect, or materially out-of-scope behavior. If no spec
  is found, skip this pass without blocking the review; ask only if a supplied spec is inaccessible
  or ambiguous.

Repository rules override generic style preferences. Code smells are investigation clues, not a
checklist of findings: a tuple, duplicated expression, or helper's location alone is not a defect.

## 3. Verify and filter

Before retaining a candidate, try to refute it against the base revision, real callers, guards, and
tests. A finding needs a reachable trigger, a concrete consequence, and a precise location in the
reviewed change. Inspect version-specific behavior when the claim depends on a library detail;
use a focused test or reproduction when it resolves uncertainty.

- Keep introduced regressions, existing defects made newly reachable, and unmet explicit requirements.
  Leave unrelated pre-existing issues out.
- Ground standards/spec claims in an actual applicable rule or requirement, not an inferred preference.
- Treat unsuccessful searches and unrun checks as limitations, not proof that something is broken.
- Leave tooling-enforced style and generic requests for more tests to tooling. Report a test gap as a
  finding only when an explicit requirement is unmet or it conceals a demonstrated behavioral defect.
- Deduplicate by root cause across both passes; assign each finding to the best-fitting axis.
- Drop unresolved speculation. Mention a material verification blocker briefly instead of presenting
  it as a confirmed finding. A clean review with limited coverage is not a claim of merge safety.

Prioritize by impact, not by which axis found it:

- **P0:** critical outage, security exposure, or widespread data loss requiring immediate action.
- **P1:** a serious bug or requirement failure on a realistic supported path; fix before merge.
- **P2:** a concrete narrower regression or material standards/spec gap.
- **P3:** optional design/style judgement; include only when the user requests nits or design feedback.

## 4. Write one compact review

Prepare one canonical set of findings and render it for each destination. Preserve the same wording,
priorities, ordering, locations, diff excerpts, and verification caveats; only presentation changes.

- Open with one line: finding count and a brief verdict, or "No actionable findings." Mark incomplete
  coverage explicitly. Omit numerical confidence scores and repeated worst-finding summaries.
- Keep **Standards** and **Spec** distinct; number findings within each, highest priority first.
  Give clean/skipped axes a single status line, not a padded section. For a missing spec,
  "Spec skipped: no spec found" is enough; keep the search diary out of the report.
- Each finding: **[priority] consequence title**, `path:line` (or a narrow range), then one short
  paragraph of **1–3 sentences, at most 60 words**: trigger → mechanism → impact. Add a fix only if
  non-obvious. Cite the relevant rule/requirement inline with a short source anchor rather than
  repeating a "Context used" or "Spec" quotation block.
- Attach a small, verbatim excerpt from the reviewed diff, usually **3–8 lines**, retaining `+`/`-`
  markers. Show the changed code, not an invented fix. For a missing requirement with no relevant
  hunk, cite its source instead of manufacturing a diff.
- End with compact scope and check metadata: reviewed range/SHAs, spec source if any, checks actually
  run and material checks not run. Keep this to one or two lines, not a narrative summary.
- Aim for **under 400 words of prose**. Preserve all verified P0–P2 findings even if that exceeds the
  target: brevity comes from filtering noise and compressing explanations, not hiding real defects.

### Terminal rendering

Use terminal-friendly Markdown: short headings, numbered findings, bold titles, backticked locations,
and fenced `diff` blocks for the excerpts. Let the terminal renderer supply highlighting; avoid raw
ANSI escapes, image badges, HTML, and wide tables. Show relevant hunks beside the findings, not the
entire branch patch unless requested. Append the posted MR note URL or a one-line publication blocker.
