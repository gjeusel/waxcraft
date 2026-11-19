---
name: artifact-design
description: Build pages for publish_artifact. Use before writing an artifact's HTML or Markdown, or when revising an existing artifact's design.
---

# Artifact design

An artifact is a capture of work: one self-contained page that shows what terminal text cannot, such
as an annotated diff, a chart, options side by side, or a timeline. Prefer a page the reader can
work with (select, filter, export) over a static report. Build it, publish it, then keep revising the
same source file.

## Steps

1. **Pick the format.** Use Markdown (`.md`) for prose-first documents; it renders with a readable
   theme and highlighted code. Use HTML (`.html`) for anything visual or interactive. For
   architecture, sequence, or data-flow diagrams, follow the `archify` skill and publish its output.
2. **Find the design system.** Look for design tokens in the project (theme files, Tailwind config,
   CSS variables, `AGENTS.md`). Use them when present: the user's prompt outranks the project's design
   system, and both outrank your own choices.
3. **Write the source** under the scratch directory named in the `publish_artifact` guidelines, with a
   descriptive filename, unless the user names a location.
4. **Publish** with `publish_artifact`, then give the user the URL. The page opens in their browser on
   first publish; `Ctrl+]` reopens it.
5. **Revise in place.** Edit the same file and publish again: open tabs reload and keep their scroll
   position. Long tasks can republish as they progress.

## Page rules

- **Self-contained**: inline CSS and JavaScript; embed images as SVG or data URIs. Load libraries only
  from a CDN (cdnjs, jsDelivr, unpkg) and typefaces from Google Fonts, each with a system fallback
  stack so the page still renders offline.
- **Single page**: nothing is deployed beside the page, so relative links and routes do not resolve.
  Use in-page anchors for sections and tabs.
- **No backend**: capture the data the session gathered into the page. Summarize large datasets
  rather than inlining them in full.
- **Round trip**: whenever the reader can select, filter, or tune something, add an export control
  that copies the current state as text the user can paste back into the session.

## Interactivity

Default to an interactive page whenever the content has more than one view, more rows than fit a
screen, or a choice to make. Keep a page static only when it is a short, linear read.

- **Select**: let the reader pick what they look at (tabs or a segmented control between views, a
  select for the scenario or entity, checkboxes on rows or options they want to keep).
- **Filter**: give lists and tables a search input plus filters on their main dimensions (status,
  type, severity), with a visible count of what matches and a way to reset.
- **Export**: copy the selection or the filtered rows as Markdown or JSON, and confirm with a toast.
- Render from one data array embedded in the page, so every control filters the same source. Open on
  the conclusion with sensible defaults; the page must be useful before any click.

## Components

Build controls with UI SDK web components rather than hand-written widgets: they bring keyboard
navigation, focus handling, and ARIA. Two tags in `<head>` load them, with no build step:

```html
<script type="module" src="https://ui-sdk.dev/web@0.js"></script>
<link rel="stylesheet" href="https://ui-sdk.dev/web@0.css" />
```

- Each component is a set of `ui-*` custom elements wrapped around your own markup, defined the
  first time its tags appear: `<ui-toggle><button>Bold</button></ui-toggle>`.
- Before writing markup, fetch `https://ui-sdk.dev/web.md` (conventions and the component list),
  then `https://ui-sdk.dev/docs/web-components/components/<name>.md` for each component used. These
  files are large: search them for the composition, events, and properties instead of reading them
  in full. The API is in beta, so do not write tags or events from memory.
- State changes are non-bubbling DOM events on the component itself, such as `valuechange` and
  `openchange`, with the new value in `event.detail.value`.
- `web.css` gives the default look in light and dark. Theme it by overriding its `--ui-*` variables
  on `:root` (`--ui-primary`, `--ui-background`, `--ui-foreground`, `--ui-border`, `--ui-radius`,
  `--ui-font-sans`) from the page's palette, and style the rest of the page with the same variables.

## Visual design

- Choose a deliberate palette: one accent colour, neutral surfaces, and semantic colours only for
  status. Support light and dark with `prefers-color-scheme` and CSS variables.
- Set a type scale with at most two families, tabular numerals for figures, and body line length
  around 70 characters.
- Lay out on a consistent spacing scale; lead with the conclusion, then the supporting detail.
- Prefer SVG, or HTML and CSS, for charts and diagrams over raster images; they are sharper and cost
  fewer tokens.
- Keep controls together in one toolbar above the content they act on, and show the active filters.
