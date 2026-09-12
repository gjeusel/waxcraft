---
name: brave-tabs-to-notion
description: Triage tab/link dumps, including Brave synced-tabs HTML, into personal Notion. Use when asked to organize or save a batch there.
---

# Brave tabs → personal Notion

Accept synced-tab HTML or URL/title lists. Extract, deduplicate, classify, and propose entries for the
user's **personal** Notion workspace. A pasted link alone is not a request to save it.

## Routing

Read [destinations](references/destinations.md) when classifying links. It contains the six destination
data-source IDs, category distinctions, and property notes. Fetch source content only when needed to
identify or classify an item; titles and paths often suffice.

Remove known tracking parameters (`utm_*`, `fbclid`) when deduplicating, but preserve query parameters,
fragments, and path differences that identify distinct content. Keep the best available title.
Search-result pages represent research intent, not automatic garbage: resolve the subject and use its
canonical link when possible.

## Approval and writes

Show a compact proposal grouped by destination, including proposed discards and reasons for ambiguous
choices. **Wait for the user's corrections or approval before writing anything to Notion.** Confirm
that the connected workspace is personal before accessing the destinations; do not fall back to a work
workspace if it is unavailable.

After approval, fetch the relevant data-source schemas and create one database entry per approved
item, matching live property names and types. WatchList is also a database, not a page to append bullets
to. Use the reference's property notes only where supported by the current schema. If a write result
is uncertain, check whether the entry exists before retrying to avoid duplicates.

Finish with verified counts and links to created entries, the discarded list, and any unsaved items or
failures. "Discard" means omit from this import, not delete existing Notion content or close browser tabs.
