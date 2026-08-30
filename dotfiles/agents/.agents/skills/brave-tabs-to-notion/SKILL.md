---
name: brave-tabs-to-notion
description: Dispatch open/synced Brave tabs (pasted as HTML or a raw list of links) into the right spots of the user's PERSONAL Notion workspace — tech projects, watch list, or knowledge base — discarding garbage. Use when the user pastes a dump of tabs/links or asks to triage/dispatch their tabs into Notion.
---

# Brave tabs → personal Notion

The user hoards iPhone Brave tabs as ersatz notes. Input is a paste of `brave://history/syncedTabs` HTML, or any messy list of URLs/titles. The job: extract, dedup, classify, confirm, dispatch.

## Critical: which Notion

Ensure to be connected (whether MCP or app/plugin) to my "personal" notion workspace.

## Destinations

| Category                                                                               | Target                                               | Data source ID                         |
| -------------------------------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------- |
| Tech projects (repos, dev tools, libraries, infra/programming articles, project ideas) | 🛠️ Tech database                                     | `027a5700-32fb-4f77-a4ad-dc3ef17dc50c` |
| Watch/read/play list (movies, series, books, video games, long-form articles to read)  | WatchList database (inline in the "Watch List" page) | `ee520939-bce1-4a72-9fb2-7c71393556e5` |
| Geographical spots (restaurants, villages, hikes, farms, venues, expos, festivals)     | 📍 Places database                                   | `0842b194-db55-4950-8322-3ca98ae10996` |
| Cooking (recipes, ingredients, techniques, fish/produce knowledge, food shops)         | 🍳 Cooking database                                  | `02d851d7-dddd-4127-aeee-afb7861e83fc` |
| Lifetime purchases (furniture, kitchen gear, clothing, gift ideas)                     | 🛒 Lifetime Purchases database                       | `3a520635-3a1d-4569-ada3-607318b85228` |
| Random knowledge (wiki curiosities, animals, concepts, people, anything left)          | 🎲 Random database                                   | `e2834c77-3d40-41b5-8422-2c0aaf90ee3d` |
| Garbage                                                                                | discarded                                            | —                                      |

Schema notes (verified 2026-07-19; re-fetch if a create fails):

- All of Tech / Places / Cooking / Purchases / Random share `name` (title), `link` (url), `tags` (multi-select), `description`.
- 📍 Places also has `status` (to-visit/visited), `date` (for events/festivals), and a `location` Place property — leave `location` empty (geocoding happens in a separate gmaps-sync pass).
- WatchList entries: set `Type` (Film/Book/TV Series/VideoGame/Article/…), `Status: "Not started"`, `Link`, plus `Author`/`genre` when known (genre values must match existing options).
- Long-form articles the user wants to READ go to WatchList as `Type: Article` (it has read-status tracking) — not to Random.

Garbage = login/checkout/session pages, empty tabs, past events, ephemeral news. When in doubt, keep (classify, don't trash).

Search-result pages (DuckDuckGo/Google) are NOT automatically garbage: the query reveals what was being researched. Resolve the subject (WebSearch if it's not obvious), then dispatch the underlying thing — e.g. a game query becomes a WatchList VideoGame entry, a restaurant/place/animal query becomes a Random entry with its canonical link.

## Workflow

1. **Extract** URL + title pairs from the paste. Handle HTML anchors or plain text lines.
2. **Dedup**: normalize URLs (drop tracking params like `utm_*`, `fbclid`, trailing slashes, fragments) and merge duplicates, keeping the best title.
3. **Classify** each link into one of the four categories. Titles are often truncated — infer from the domain/path when needed; only WebFetch a URL if genuinely ambiguous.
4. **Confirm**: show one compact table per category (title, URL, one-line reason if non-obvious) including the garbage pile, and wait for the user's corrections before writing anything to Notion.
5. **Dispatch** with the Notion app/plugin:
   - For the two databases: fetch the database first to learn its data-source schema, then create one entry per link mapping title → title property and URL → the URL property (match whatever the schema actually has; leave other properties at defaults).
   - For the Watch List page: fetch it first to see its structure, then append links in the same style the page already uses (fallback: a bulleted list of `[title](url)` under today's date).
6. **Report**: counts per destination with Notion links to what was created, plus the discarded garbage list so the user can safely close all tabs.
