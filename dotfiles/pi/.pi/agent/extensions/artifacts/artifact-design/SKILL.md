---
name: artifact-design
description: Build pages for publish_artifact. Use before writing an artifact's HTML or Markdown, or when revising an existing artifact's design.
---

# Artifact design

An artifact is a capture of work: one self-contained page that shows what terminal text cannot, such
as an annotated diff, a chart, options side by side, or a timeline. Build it, publish it, then keep
revising the same source file.

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
- **Round trip**: when the page is a decision tool (tuning, picking options), add an export control
  that produces text the user can paste back into the session.

## Visual design

- Choose a deliberate palette: one accent colour, neutral surfaces, and semantic colours only for
  status. Support light and dark with `prefers-color-scheme` and CSS variables.
- Set a type scale with at most two families, tabular numerals for figures, and body line length
  around 70 characters.
- Lay out on a consistent spacing scale; lead with the conclusion, then the supporting detail.
- Prefer SVG, or HTML and CSS, for charts and diagrams over raster images; they are sharper and cost
  fewer tokens.
- Add interactivity only where it helps the reader explore: filters, toggles, tabs, tooltips.
