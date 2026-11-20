---
name: vocabularize
description: Review the vocabulary and converge on one name per concept, by asking the user to choose between candidates. Use for "vocabularize", or when asked to review naming coherence.
---

A codebase is a small world, and its names are all a reader ever sees of it. This skill questions
the names that exist, and the user decides which ones the world keeps.

## Aims

- **Converge.** Lower the complexity of the code by homogenizing its vocabulary: one concept, one
  name; one name, one concept. A reader who meets two words assumes two concepts, and one word
  used for two things makes them conflate.
- **Distinguish.** Convergence is owed to a concept, never to the words around it. Where the
  concepts are distinct, the names must differ as much as the concepts do. A vocabulary is rich
  when it has a word for every distinction the domain makes: a generic word (`data`, `scope`), a
  mechanism word (`mask`, `stage`) or a boolean standing where a concept should be all erase a
  distinction the reader then has to rebuild alone.
- **Imagine.** A name is a claim about the domain, and the names together form a universe the
  reader lives in. A word chosen from the right universe is generative: it brings its relatives
  with it and names what is not written yet. In a tender-file parser, `Finder` became `Probe`;
  the probe then called for the `rod` it pulls out, the `anchor` it holds on to, the `loot` it
  hands over, and the `miner` that extracts from it. One word chosen, four concepts named.
  Prefer the word that opens such a universe to the flat one that only describes.

> Mal nommer les choses, c'est ajouter au malheur du monde.
>
> Albert Camus

## Scope

The names the prompt points at, each with its **family**: the names that must share its word (a
start and its end, a thing and the function producing it, a type and its instances). Without a
name in the prompt, the uncommitted changes (`git diff HEAD` plus untracked files); when there
are none, the branch against its base.

Read past the scope for the words the codebase and its sibling projects already speak, but rename
inside the scope only.

## Hunt for

- synonyms: one concept, several names (`eligible` and `active`);
- homonyms: one name, several concepts;
- mechanism words standing for a domain concept (`mask`, `temporal`, `control`);
- unqualified generic words (`curve`, `data`, `values`): which curve?
- a concept flattened into a boolean or a bare string;
- abbreviations beside full words (`qty_weights` next to `quantity_weights`);
- a family whose members come from different universes;
- names breaking the project's conventions, and leftovers of removed code.

Each finding the three aims condemn is a **decision**: one concept, its family, and the names
they go by today. Drop the findings that cost a reader nothing, without mentioning them.

## Ask

Open with the first question: no table, no survey, no preamble. Put each decision to the user as
one `ask_user_question`, the word the others depend on first.

- **Question**: the concept in plain words, with the names it goes by today.
  `What should the range of dates accepted as user input be called (now DOCGEN_MIN_YEAR / DOCGEN_MAX_YEAR)?`
- **Options**: 3 or 4 candidates, each built on a different word and coming from a different
  aim: the word the codebase already speaks (converge), the precise word of the domain
  (distinguish), the word that opens or extends a universe (imagine). The user's own candidate,
  when the prompt holds one, is always among them. The current name is a candidate only when it
  can be defended. Your pick comes first with ` (Recommended)`.
- **Label**: the candidate's word, or the name itself when the family holds a single name.
- **Description**: the why, in one line of at most 12 words.
  `Horizon is already the codebase's (start, end) pair.`
- **Preview**: the candidate at work, 5 to 12 lines of the scope's real code rewritten with the
  whole family: the definition, one usage, the user-facing message when there is one. Every
  candidate rewrites the same lines, so the previews differ by the vocabulary alone.

```python
# preview of the candidate `horizon`
PLAUSIBLE_HORIZON_START = pd.Timestamp("1990-01-01")
PLAUSIBLE_HORIZON_END = pd.Timestamp("2101-01-01")

if not PLAUSIBLE_HORIZON_START <= value < PLAUSIBLE_HORIZON_END:
    raise ValueError(f"{value} is outside the plausible horizon")
```

Chain the questions: each answer narrows the next. Before each call, rewrite the remaining
decisions with the words already chosen and drop the candidates they rule out. Decisions
independent of each other share a call, up to 4.

A typed answer is a candidate of its own: derive the whole family from the user's word.

A chosen name that renames a contract (API field, DB column, enum value, serialized key,
dataclass field) earns one more question: keep the contract's name, rename it behind a
deprecated alias, or rename it outright.

The asking is done when every decision has an answer. Ask only what is a choice of words: what
the code can tell you, read.

## Apply

Apply the answers without asking for confirmation, each family whole: the retired names become
the chosen ones everywhere they appear (callers, tests, locals, docstrings, comments, messages).
Behavior stays unchanged. Run the project's lint and the tests the renames reach.

A decision is done when a search of its retired names returns no hit for that concept.

## Report

The renames as one table, and nothing before it:

```markdown
| Before                                | After                                                | Why                       |
| ------------------------------------- | ---------------------------------------------------- | ------------------------- |
| `DOCGEN_MIN_YEAR`, `DOCGEN_MAX_YEAR`  | `PLAUSIBLE_HORIZON_START`, `PLAUSIBLE_HORIZON_END`   | not only docgen           |
```

`Why` holds at most 6 words. Below the table, one line for the checks run and their result, then
one line per site kept on purpose, and one sentence for any two names that turned out to hide two
different computations: a behavior divergence is reported, never renamed away.
