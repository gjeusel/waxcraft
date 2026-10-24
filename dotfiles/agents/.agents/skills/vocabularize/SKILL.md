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

List the concepts the scope names, in identifiers, parameters, fields, docstrings, comments, error
and log messages, and every name each one goes by. Look past the scope for the term the codebase
already uses: models, fields, enums, the function producing the thing, sibling modules, the
project's naming conventions. An established term beats a fresh one.

Hunt for:

- synonyms: one concept, several names (`eligible` and `active`);
- homonyms: one name, several concepts;
- mechanism words standing for a domain concept (`mask`, `temporal`, `control`);
- unqualified generic words (`curve`, `data`, `values`): always say which one;
- abbreviations beside full words (`qty_weights` next to `quantity_weights`);
- names breaking the project's conventions, and leftovers of removed code.

Two names sometimes hide two computations of the same concept. That is a behavior divergence, not
a naming one: give it its own row and never fold the fix into a rename.

## Propose

Answer with one table and nothing around it:

| Used now | Proposed | Why |
| -------- | -------- | --- |

One row per rename, grouped by concept. `Why` is a few words: "codebase term", "same concept as
`eligible`", "says which curve". Flag in `Why` any row that changes behavior or touches a contract
(API field, DB column, enum value, serialized key). An undecided row shows your recommendation
followed by `?`.

## Converge

A row is settled when the codebase already has the term. Every other one gets a decision: a new
concept needs a word, two established terms compete, a unification changes behavior. Put each to
the user through `ask_user_question`, one decision per question: 2 to 4 candidate names, your
recommendation first with ` (Recommended)`, each option's trade-off in its description. Fold the
answers back into the table.

## Apply

Change nothing until the user confirms the table. Then apply exactly the confirmed rows,
everywhere each name appears (callers, tests, docstrings, messages), keep behavior unchanged except
where a row says otherwise, and run the project's lint and the tests the renames reach.
