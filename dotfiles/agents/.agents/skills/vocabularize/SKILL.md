---
name: vocabularize
description: Review the vocabulary of a code scope and converge on one name per concept, reusing the codebase's own terms. Use for "vocabularize", or when asked to review naming coherence.
---

Lower the complexity of the code by homogenizing its vocabulary: one concept, one name; one name,
one concept. A reader who meets two words assumes two concepts, and one word used for two things
makes them conflate. Build the scope's ubiquitous language out of the words the codebase already
speaks, and rename only what earns it.

## Scope

The scope named in the prompt: a module, a class, a function, a concept. Without one, the
uncommitted changes (`git diff HEAD` plus untracked files); when there are none, the branch
against its base (`git diff $(git merge-base HEAD main)`, or `master`).

## Survey

List the concepts the scope names and every name each one goes by. Look past the scope for the
term the codebase already uses: models, fields, enums, the function producing the thing, sibling
modules, the project's naming conventions. An established term beats a fresh one.

Hunt for:

- synonyms: one concept, several names (`eligible` and `active`);
- homonyms: one name, several concepts;
- mechanism words standing for a domain concept (`mask`, `temporal`, `control`);
- unqualified generic words (`curve`, `data`, `values`): always say which one;
- abbreviations beside full words (`qty_weights` next to `quantity_weights`);
- names breaking the project's conventions, and leftovers of removed code.

Two names sometimes hide two computations of the same concept. That is a behavior divergence, not
a naming one: give it its own Risky row and keep the fix out of every rename.

### Strictness

The survey runs at a strictness level, starting at 0. Each level adds to the ones below it:

- **0**: names crossing a function boundary: functions, classes, parameters, fields, modules.
- **1**: locals, test names, fixtures.
- **2**: prose: docstrings, comments, log and error messages.
- **3**: form: word order (`site_eligible` vs `eligible_site`), singular and plural, verb
  families (`get`, `fetch`, `load`), unit suffixes, tense.

Count what the levels above the current one would report, without listing it: that count is the
`Held back` line of the proposal.

## Propose

Answer with the proposal and nothing around it: one row per concept, numbered across the whole
proposal, in three tiers. Omit an empty tier.

```markdown
### Settled

| #   | Concept        | Now                 | Canonical  | Sites        | Evidence              |
| --- | -------------- | ------------------- | ---------- | ------------ | --------------------- |
| 1   | site may trade | `active`, `enabled` | `eligible` | 14 / 3 files | `Site.eligible` field |

### Decide

| #   | Concept            | Now                | Canonical | Sites       | Evidence       |
| --- | ------------------ | ------------------ | --------- | ----------- | -------------- |
| 2   | eligibility window | `mask`, `temporal` | `window`? | 6 / 2 files | mechanism word |

### Risky

| #   | Concept       | Now     | Canonical       | Sites       | Evidence          |
| --- | ------------- | ------- | --------------- | ----------- | ----------------- |
| 3   | forward curve | `curve` | `forward_curve` | 9 / 4 files | API field `curve` |

Held back: 6 nits at levels 1 to 3.
Reply: `ok` · `ok but 2` · `only 1` · `+3` · `2: span` · `alt 2` · `why 2` · `more` · `more 1`
```

- **Settled**: the codebase already has the term. `Evidence` names where. On by default.
- **Decide**: a new concept needs a word, or two established terms compete. `Canonical` is your
  pick followed by `?`, `Evidence` the reason in a few words. On by default.
- **Risky**: the row changes behavior or touches a contract (API field, DB column, enum value,
  serialized key). `Evidence` names what breaks. Off by default.

`Now` lists every name to retire, `Canonical` the single name that survives. A homonym gives one
row per concept it splits into. `Sites` counts the occurrences to change and the files holding
them, so the user sees each row's cost.

## Converge

The row numbers are the user's handles. Read the reply against this grammar; several commands
combine in one reply (`ok but 2, 4: span`):

| Reply        | Effect                                                                |
| ------------ | --------------------------------------------------------------------- |
| `ok`         | Select every row that is on by default                                |
| `ok but 2 5` | The same, minus those rows                                            |
| `only 1 4`   | Select exactly those rows                                             |
| `+3`         | Add a row that is off by default; combines with the three above       |
| `2: span`    | Set the row's canonical name                                          |
| `alt 2`      | Put the row's name to `ask_user_question`, as described below         |
| `why 2`      | List every site of the row as `path:line` with its line of code       |
| `more`       | Raise the strictness one level and survey again                       |
| `more 2`     | Dig into one concept: every name it goes by across the whole codebase |

For `alt`, offer 2 to 4 candidate names, your pick first with ` (Recommended)`, each option's
trade-off in its description.

A reply holding `ok` or `only` is the confirmation: apply. Any other reply amends the proposal:
print the rows it changed or added, numbered on from the last row so existing numbers stay
stable, then the `Held back` and `Reply` lines again. When `more` finds nothing, say the level is
dry, and at level 3 drop `more` from the `Reply` line.

## Apply

Apply exactly the selected rows, each one whole: every name in `Now` becomes `Canonical`
everywhere it appears (callers, tests, docstrings, messages). Behavior stays unchanged except
where a selected Risky row says otherwise. Run the project's lint and the tests the renames
reach.

A row is done when a search of its retired names returns no hit for that concept. Report the
rows applied, the rows left out, and any site kept on purpose with its reason.
