---
name: dynamic-wallpaper
description: Create native 4K macOS dynamic HEIC wallpapers from an idea, with nine consistent scenes spanning a full day.
---

# Dynamic wallpaper

Create nine lighting variants of one scene and a time-driven macOS `.heic`. Use `gpt-image-2.5-sunburst` with `quality="max"` for every generation and edit. “Max effort” means image quality, not `reasoning_effort`.

## Scene and continuity

Develop the user's idea in their requested style. Compose edge-to-edge artwork with calm areas for desktop icons and legible silhouettes. Establish a fixed viewpoint, framing, geometry, objects, materials, season, and weather. Plan practical lights appropriate to the setting from the outset; interiors also need a plausible path for light from the sky. Those fixtures and openings stay in place throughout the cycle.

The phases are **pre-dawn → sunrise → mid-morning → midday → mid-afternoon → early evening → sunset → early night → deep night**. The CLI initializes their lighting directions and adjustable local times in `plan.json`; refine that file for the idea and requested routine. These are fixed-clock schedules, not calculated astronomical events.

Preserve the important differences: pre-dawn has first diffuse daylight with the sun below the horizon and no direct sunlight; early evening still has sun above the horizon; early night uses warm practical lights; deep night extinguishes those lights and relies on the night sky. Follow a coherent sun trajectory relative to the camera, with corresponding shadows and reflections.

Prefer midday as the master. Inspect and correct it, then derive the other eight scenes as edits anchored to that master. Keep composition and geometry stable while changing illumination and sky. Review the whole cycle, including deep night → pre-dawn → sunrise, and correct affected frames while retaining accepted ones.

## Artifact layout

Choose a descriptive title such as `Rio de Janeiro - Gouache`, usually `<Subject> - <Style>`. Preserve a title the user already likes. Resolution is optional in the name; keep an existing `4K` suffix when retaining that title, but do not add one automatically.

Each wallpaper creates exactly two entries in the destination, which defaults to `~/Pictures/dynamic-wallpapers`: `<Title>.heic` and a folder named exactly `<Title>`.

```text
dynamic-wallpapers/
├── Rio de Janeiro - Gouache.heic
└── Rio de Janeiro - Gouache/
    ├── plan.json
    ├── 03-midday.png
    ├── 03-midday.generation.json
    ├── … other phase PNGs and generation records
    ├── schedule.json
    ├── contact-sheet.jpg
    └── inspection.json
```

Use that matching folder from the first draft onward for all references, generated images, prompts, plans, logs, previews, reports, and scratch files. Copy tool-managed generated images into it before using them in the project. These project paths take precedence over generic imagegen `output/` and `tmp/` conventions. Keep the destination root free of loose sidecars and auxiliary directories such as `output`, `tmp`, or `.ruff_cache`. Disable dispensable caches (`ruff --no-cache`, pytest `-p no:cacheprovider`, `PYTHONDONTWRITEBYTECODE=1`); any necessary task-specific cache or scratch directory belongs inside the matching folder.

## Use the CLI

[scripts/wallpaper.py](scripts/wallpaper.py) implements the deterministic steps. Run it with `uv run`, or directly through its executable shebang. It declares Python 3.12 and pinned dependencies using inline script metadata. The following commands are relative to the skill directory; use the absolute script path from elsewhere.

```sh
wallpaper_project="$HOME/Pictures/dynamic-wallpapers/Hillside Cabin - Gouache"
uv run scripts/wallpaper.py init "$wallpaper_project" --idea "A quiet hillside cabin" --size 3840x2160
```

Refine `plan.json` with a concrete shared scene, lighting, and times before generation. Use the requested display dimensions; `init --size WIDTHxHEIGHT` otherwise defaults to 3840 × 2160 (4K UHD landscape). Use 2160 × 3840 for portrait 4K.

For native 4K, use this skill's CLI: it passes the plan's dimensions as the Image API `size` parameter on every generation and edit. A prompt saying “4K” does not enforce output dimensions. If a built-in image tool returns a smaller image, retain it as a draft and use the explicit-size API workflow once API use is authorized; reuse authorization already given in the session. For API access, resolution mismatches, or parameter issues, read [references/image-api.md](references/image-api.md).

```sh
uv run scripts/wallpaper.py generate "$wallpaper_project" --dry-run
uv run scripts/wallpaper.py generate "$wallpaper_project" --phase 03-midday
```

`--dry-run` shows the exact requests without API calls; check that `size` matches the target. `generate` makes paid Image API calls using `OPENAI_API_KEY` from the local environment and verifies each saved PNG's decoded dimensions against the plan. Inspect the saved master at full resolution and accept its dimensions and detail before generating dependent phases, then continue:

```sh
uv run scripts/wallpaper.py generate "$wallpaper_project"
uv run scripts/wallpaper.py preview "$wallpaper_project"
uv run scripts/wallpaper.py build "$wallpaper_project"
```

Generation resumes from images whose recorded requests and hashes still match. Regenerate a specific phase with `--phase ID --force`. Changing the master makes its dependent variants stale; regenerate them coherently. Successful outputs and provenance are saved immediately, and failed API calls are not automatically retried. Inspect a saved output before retrying an uncertain call.

`build` uses the installed `wallpapper` (`--wallpapper PATH` overrides discovery). By default it writes the sibling `${wallpaper_project}.heic`, keeping `schedule.json` and `inspection.json` inside the project folder. It handles version 1.7.4's full-date input and appearance-index behavior and verifies the resulting HEIC. Times in the plan use `HH:MM:00`, reflecting the assembler's minute precision. The date in the generated schedule is only a local-time carrier. Midday is the primary/light image; deep night is the dark image.

For existing files, or to repeat comparison against the project:

```sh
uv run scripts/wallpaper.py inspect "${wallpaper_project}.heic" --project "$wallpaper_project"
```

The inspector checks decoded frame counts and dimensions, `h24` times, appearance defaults, and thumbnail similarity to the scheduled source images. Its pixel comparison is a heuristic; inspect the contact sheet and full-size frames for visual continuity. Native macOS switching is verified only by observing it.

## Completion

Finish with the named HEIC and its matching artifact folder in the layout above. The folder contains the nine PNGs, editable plan, generated schedule, generation records containing prompts/settings, labeled contact sheet, inspection report, and all retained intermediate work. Check that this run added no other files or directories at the destination root. Continue through visual corrections and packaging validation. Report the verified pixel dimensions of the PNGs and decoded HEIC frames; a 4K delivery requires every frame to match the requested 4K dimensions. Report any unresolved defect or missing dependency precisely. Apply the wallpaper when requested.

When changing the CLI, run `PYTHONDONTWRITEBYTECODE=1 uv run scripts/test_wallpaper.py -p no:cacheprovider`. Tests mock the image API and build a disposable nine-frame HEIC when `wallpapper` is installed; they make no paid image calls. Consult the [wallpapper source](https://github.com/mczachurski/wallpapper) if its interface or metadata behavior changes.
