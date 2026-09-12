# Personal Notion destinations

These are **data-source IDs**, not page IDs. Confirm the personal workspace before using them.

| Category | Destination | Data-source ID |
| --- | --- | --- |
| Repos, dev tools, libraries, infrastructure/programming articles, project ideas | 🛠️ Tech | `027a5700-32fb-4f77-a4ad-dc3ef17dc50c` |
| Movies, series, books, games, long-form articles to read | WatchList (inline in the Watch List page) | `ee520939-bce1-4a72-9fb2-7c71393556e5` |
| Restaurants, villages, hikes, farms, venues, expos, festivals | 📍 Places | `0842b194-db55-4950-8322-3ca98ae10996` |
| Recipes, ingredients, techniques, fish/produce knowledge, food shops | 🍳 Cooking | `02d851d7-dddd-4127-aeee-afb7861e83fc` |
| Furniture, kitchen gear, clothing, gift ideas | 🛒 Lifetime Purchases | `3a520635-3a1d-4569-ada3-607318b85228` |
| Wiki curiosities, animals, concepts, people, remaining knowledge | 🎲 Random | `e2834c77-3d40-41b5-8422-2c0aaf90ee3d` |

## Category distinctions

- Articles explicitly saved **to read** go to WatchList as `Article` for reading-status tracking.
  Technical reference material and project ideas belong in Tech.
- Search queries should resolve to the underlying thing: a game goes to WatchList, a restaurant to
  Places, an animal to Random. Do not save the search URL when a canonical subject link is available.
- Food shops and ingredients belong in Cooking; destinations to visit belong in Places. Explain
  ambiguous choices in the proposal so the user can correct them.
- Login/checkout/session pages, empty tabs, past events, and ephemeral news are discard candidates.
  When in doubt, keep and classify. Discards require the same proposal review as saved items.

## Schema notes

Last verified 2026-07-19. Treat the live schema as authoritative before creating entries.

- Tech, Places, Cooking, Purchases, and Random share `name` (title), `link` (URL), `tags` (multi-select),
  and `description`.
- Places also has `status` (`to-visit`/`visited`), `date` (events/festivals), and `location` (Place).
  Leave `location` empty; geocoding is handled by a separate gmaps-sync pass.
- WatchList uses `Type` (`Film`, `Book`, `TV Series`, `VideoGame`, `Article`, …), `Status: "Not started"`,
  and `Link`, plus `Author`/`genre` when known. Match existing genre options.
- Map the item's title to the actual title property. Leave unspecified properties at their defaults;
  do not invent metadata to fill fields.
