#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.*"
# dependencies = [
#   "openai==3.13.0",
#   "pillow==12.3.0",
#   "pillow-heif==1.7.0",
# ]
# ///

"""Prepare, generate, preview, package, and inspect a nine-phase dynamic wallpaper."""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import math
import os
import plistlib
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET
from datetime import datetime
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageStat
from pillow_heif import register_heif_opener

MODEL = "gpt-image-2.5-sunburst"
MASTER = "03-midday"
PHASES = [
    (
        "00-predawn",
        "05:15:00",
        "First daylight returning: pale horizon, cool diffuse sky light. Sun entirely below the horizon; no solar disk, direct sunbeams, or sun-cast shadows. Practical lights off.",
    ),
    (
        "01-sunrise",
        "06:00:00",
        "Sun reaching the horizon: first warm direct light, long shadows, cool ambient sky.",
    ),
    (
        "02-mid-morning",
        "09:00:00",
        "Fresh daylight, higher sun, shorter shadows, balanced warmth.",
    ),
    (
        "03-midday",
        "12:00:00",
        "Highest sun of the sequence, bright neutral daylight, shortest shadows, retained highlight detail.",
    ),
    (
        "04-mid-afternoon",
        "15:00:00",
        "Descending sun, gently warmer light, lengthening shadows.",
    ),
    (
        "05-early-evening",
        "18:00:00",
        "Sun still above the horizon, warm low-angle light, long shadows; visibly earlier than sunset.",
    ),
    (
        "06-sunset",
        "20:00:00",
        "Sun at the horizon, amber/rose sky, cooler foreground shadows, warm reflected light.",
    ),
    (
        "07-early-night",
        "21:30:00",
        "Warm bulbs, windows, lanterns, or fire provide main local illumination against a darkening sky, with believable light pools and reflections.",
    ),
    (
        "08-deep-night",
        "00:00:00",
        "Practical lights extinguished. Moonlight, starlight, and diffuse night-sky light reveal subdued detail and silhouettes. Clearly dark while legible.",
    ),
]
INVARIANTS = (
    "Preserve the camera, perspective, framing, horizon, geometry, object placement, "
    "materials, season, weather, and rendering style. Change illumination, sky, shadows, "
    "and reflections for the requested phase. Follow one coherent sun trajectory. "
    "Light fixtures remain in place. Produce one edge-to-edge desktop wallpaper, "
    "with calm areas for icons, legible silhouettes, and no captions, panels, or watermarks."
)


def write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dimensions(size: str) -> tuple[int, int]:
    if not re.fullmatch(r"\d+x\d+", size):
        raise ValueError("size must be WIDTHxHEIGHT")
    width, height = map(int, size.split("x"))
    if (
        min(width, height) <= 0
        or width % 16
        or height % 16
        or max(width, height) > 3840
        or not 1 / 3 <= width / height <= 3
        or not 655_360 <= width * height <= 8_294_400
    ):
        raise ValueError("size is outside Sunburst's supported dimensions")
    return width, height


def fraction(time: str) -> float:
    if not re.fullmatch(r"(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d", time):
        raise ValueError(f"Invalid local time: {time}")
    hour, minute, second = map(int, time.split(":"))
    if second != 0:
        raise ValueError("wallpapper schedules have minute precision; use seconds 00")
    return (3600 * hour + 60 * minute + second) / 86400


def load_plan(directory: Path) -> dict:
    plan = read_json(directory / "plan.json")
    if plan["model"] != MODEL or plan["quality"] != "max":
        raise ValueError(f"This skill requires {MODEL} with quality=max")
    dimensions(plan["size"])
    scenes = plan["scenes"]
    if len(scenes) != 9 or {s["id"] for s in scenes} != {s[0] for s in PHASES}:
        raise ValueError(
            "The plan must contain each of the nine phase IDs exactly once"
        )
    times = [fraction(s["time"]) for s in scenes]
    if len(set(times)) != 9:
        raise ValueError("The nine phase times must be distinct")
    ordered = sorted(scenes, key=lambda s: fraction(s["time"]))
    ids = [s["id"] for s in ordered]
    start = ids.index(PHASES[0][0])
    if ids[start:] + ids[:start] != [s[0] for s in PHASES]:
        raise ValueError(
            "Scheduled phases must preserve the daily cycle, including midnight wrap"
        )
    if not plan["scene"].strip() or any(not s["lighting"].strip() for s in scenes):
        raise ValueError("Scene and lighting descriptions must be nonempty")
    return plan


def init(directory: Path, idea: str, size: str) -> None:
    dimensions(size)
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "plan.json"
    if path.exists():
        raise ValueError(
            f"Plan already exists: {path}; edit it or choose a new directory"
        )
    write_json(
        path,
        {
            "model": MODEL,
            "quality": "max",
            "size": size,
            "scene": idea,
            "scenes": [
                {"id": name, "time": time, "lighting": light}
                for name, time, light in PHASES
            ],
        },
    )
    print(
        f"Created {path}. Refine its shared scene, lighting, and times before generation."
    )


def request_spec(plan: dict, scene: dict, master_hash: str | None) -> dict:
    action = (
        "Generate the master scene"
        if scene["id"] == MASTER
        else "Edit Image 1, the master scene"
    )
    return {
        "model": plan["model"],
        "quality": plan["quality"],
        "size": plan["size"],
        "output_format": "png",
        "n": 1,
        "prompt": f"{action} for {scene['id']}.\nScene: {plan['scene']}\nLighting: {scene['lighting']}\n{INVARIANTS}",
        "master_sha256": master_hash,
    }


def validate_generated(path: Path, size: str) -> None:
    with Image.open(path) as image:
        image.load()
        if image.format != "PNG" or image.size != dimensions(size):
            raise ValueError(
                f"{path} saved, but format or dimensions differ from the plan; inspect it"
            )


def matches_record(path: Path, spec: dict) -> bool:
    record_path = path.with_suffix(".generation.json")
    record = read_json(record_path) if record_path.exists() else {}
    return record.get("request") == spec and record.get("image_sha256") == digest(
        path.read_bytes()
    )


def generate(
    directory: Path, selected: list[str] | None, force: bool, dry_run: bool
) -> None:
    plan = load_plan(directory)
    wanted = set(selected or [s[0] for s in PHASES])
    scenes = sorted(plan["scenes"], key=lambda s: (s["id"] != MASTER, s["id"]))
    client = None
    for scene in scenes:
        name = scene["id"]
        if name not in wanted:
            continue
        master_path = directory / f"{MASTER}.png"
        master_hash = None
        if name != MASTER:
            if not master_path.exists() and not dry_run:
                raise ValueError("Generate and inspect 03-midday first")
            master_hash = (
                digest(master_path.read_bytes())
                if master_path.exists()
                else "pending-master"
            )
            if not dry_run:
                master_scene = next(s for s in scenes if s["id"] == MASTER)
                if not matches_record(
                    master_path, request_spec(plan, master_scene, None)
                ):
                    raise ValueError(
                        "The master is stale or lacks provenance; regenerate 03-midday first"
                    )
                validate_generated(master_path, plan["size"])
        spec = request_spec(plan, scene, master_hash)
        if dry_run:
            print(json.dumps({"phase": name, **spec}, ensure_ascii=False))
            continue
        target = directory / f"{name}.png"
        record_path = directory / f"{name}.generation.json"
        if target.exists() and not force:
            if not matches_record(target, spec):
                raise ValueError(
                    f"{name} has changed or lacks provenance; use --phase {name} --force to regenerate"
                )
            validate_generated(target, plan["size"])
            print(f"Keeping {name}", flush=True)
            continue
        if client is None:
            if not os.environ.get("OPENAI_API_KEY"):
                raise ValueError(
                    "Set OPENAI_API_KEY locally before generating; --dry-run needs no key"
                )
            from openai import OpenAI

            client = OpenAI(timeout=1200, max_retries=0)
        print(f"Generating {name} ({MODEL}, max)...", flush=True)
        params = {k: v for k, v in spec.items() if k != "master_sha256"}
        if name == MASTER:
            result = client.images.generate(**params)
        else:
            with master_path.open("rb") as image:
                result = client.images.edit(image=image, **params)
        if not result.data or not result.data[0].b64_json:
            raise ValueError(f"No image returned for {name}")
        data = base64.b64decode(result.data[0].b64_json, validate=True)
        # Save paid output before validation so a size mismatch remains recoverable.
        target.write_bytes(data)
        write_json(
            record_path,
            {
                "request": spec,
                "image_sha256": digest(data),
                "request_id": getattr(result, "_request_id", None),
                "usage": result.usage.model_dump()
                if getattr(result, "usage", None)
                else None,
            },
        )
        validate_generated(target, plan["size"])
        print(f"Saved {target}", flush=True)


def source_images(directory: Path, plan: dict) -> list[dict]:
    profiles = set()
    for scene in plan["scenes"]:
        path = directory / f"{scene['id']}.png"
        with Image.open(path) as image:
            image.load()
            if image.format != "PNG" or image.size != dimensions(plan["size"]):
                raise ValueError(f"Unexpected format or dimensions: {path}")
            profiles.add((image.mode, image.info.get("icc_profile")))
    if len(profiles) != 1:
        raise ValueError(
            "Source images have inconsistent modes or embedded color profiles"
        )
    return sorted(plan["scenes"], key=lambda s: s["id"])


def preview(directory: Path, output: Path | None) -> None:
    plan = load_plan(directory)
    scenes = source_images(directory, plan)
    width, height = dimensions(plan["size"])
    thumb_height = round(480 * height / width)
    sheet = Image.new("RGB", (3 * 504, 3 * (thumb_height + 56)), "#15191f")
    draw = ImageDraw.Draw(sheet)
    for index, scene in enumerate(scenes):
        x, y = (index % 3) * 504 + 12, (index // 3) * (thumb_height + 56) + 12
        with Image.open(directory / f"{scene['id']}.png") as image:
            thumb = image.convert("RGB")
            thumb.thumbnail((480, thumb_height))
            sheet.paste(thumb, (x, y))
        draw.text(
            (x, y + thumb_height + 8),
            f"{scene['id']}  {scene['time']}",
            fill="white",
            font_size=18,
        )
    output = output or directory / "contact-sheet.jpg"
    sheet.save(output, quality=90)
    print(output)


def h24_from_xmp(xmp: bytes) -> dict | None:
    try:
        root = ET.fromstring(xmp.rstrip(b"\x00"))
    except ET.ParseError as exc:
        raise ValueError(f"Invalid XMP metadata: {exc}") from exc
    for node in root.iter():
        for name, value in [*node.attrib.items(), (node.tag, node.text or "")]:
            if name.rsplit("}", 1)[-1] == "h24":
                return plistlib.loads(base64.b64decode(value))
    return None


def inspect(path: Path, directory: Path | None = None) -> dict:
    register_heif_opener(thumbnails=False)
    thumbs, sizes, metadata = [], set(), None
    with Image.open(path) as image:
        for index in range(image.n_frames):
            image.seek(index)
            image.load()
            sizes.add(image.size)
            thumb = image.convert("RGB").resize((96, 64))
            thumbs.append(thumb)
            if image.info.get("xmp"):
                metadata = h24_from_xmp(image.info["xmp"]) or metadata
    if len(sizes) != 1 or metadata is None:
        raise ValueError("HEIC must have equal-sized frames and Apple h24 metadata")
    entries = metadata["ti"]
    times, indices = [e["t"] for e in entries], [e["i"] for e in entries]
    count = len(thumbs)
    if (
        len(entries) != count
        or set(indices) != set(range(count))
        or len(set(times)) != count
        or any(
            not isinstance(t, (int, float)) or not math.isfinite(t) or not 0 <= t < 1
            for t in times
        )
        or any(type(i) is not int for i in indices)
        or any(
            type(metadata["ap"][k]) is not int or not 0 <= metadata["ap"][k] < count
            for k in ("l", "d")
        )
    ):
        raise ValueError("Invalid h24 times, frame indices, or appearance defaults")
    report = {
        "file": str(path),
        "frames": count,
        "size": list(next(iter(sizes))),
        "h24": metadata,
    }
    if directory:
        plan = load_plan(directory)
        scenes = source_images(directory, plan)
        if count != 9 or sizes != {dimensions(plan["size"])}:
            raise ValueError("HEIC does not match the nine-frame plan dimensions")
        mapping = {}
        for scene in scenes:
            matches = [
                e["i"]
                for e in entries
                if abs(e["t"] - fraction(scene["time"])) < 1 / 864000
            ]
            if len(matches) != 1:
                raise ValueError(f"Missing scheduled time for {scene['id']}")
            index = matches[0]
            with Image.open(directory / f"{scene['id']}.png") as original:
                source = original.convert("RGB").resize((96, 64))
            error = (
                sum(ImageStat.Stat(ImageChops.difference(source, thumbs[index])).mean)
                / 3
            )
            if error > 12:
                raise ValueError(
                    f"Frame {index} does not visually match {scene['id']} (mean pixel error {error:.1f})"
                )
            mapping[scene["id"]] = {"index": index, "mean_pixel_error": round(error, 3)}
        if metadata["ap"] != {
            "l": mapping[MASTER]["index"],
            "d": mapping["08-deep-night"]["index"],
        }:
            raise ValueError("HEIC light/dark defaults do not match the plan")
        report["mapping"] = mapping
        report["comparison"] = (
            "Thumbnail pixel comparison; visual continuity and native macOS switching require observation."
        )
    return report


def build(directory: Path, output: Path | None, executable: str, force: bool) -> None:
    directory = directory.resolve()
    plan = load_plan(directory)
    scenes = source_images(directory, plan)
    binary = shutil.which(executable)
    if not binary:
        raise ValueError(f"HEIC assembler not found: {executable}")
    schedule = []
    # v1.7.4 needs full dates, and appearance indices use the input order.
    # Put the primary first so input and encoded appearance indices agree.
    for scene in sorted(scenes, key=lambda s: (s["id"] != MASTER, s["id"])):
        local = datetime.fromisoformat(f"2001-01-15T{scene['time']}").astimezone()
        row = {
            "fileName": f"{scene['id']}.png",
            "time": local.strftime("%Y-%m-%dT%H:%M:%S%z"),
        }
        if scene["id"] == MASTER:
            row.update(isPrimary=True, isForLight=True)
        if scene["id"] == "08-deep-night":
            row["isForDark"] = True
        schedule.append(row)
    output = (output or directory.parent / f"{directory.name}.heic").resolve()
    if output.exists() and not force:
        raise ValueError(f"Output already exists: {output}; use --force to replace")
    write_json(directory / "schedule.json", schedule)
    subprocess.run(
        [binary, "-i", "schedule.json", "-o", str(output)], cwd=directory, check=True
    )
    report = inspect(output, directory)
    write_json(directory / "inspection.json", report)
    print(json.dumps(report, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    start = commands.add_parser(
        "init", help="Create an editable nine-phase plan; no API calls"
    )
    start.add_argument(
        "directory", type=Path, help="Artifact folder named for the wallpaper"
    )
    start.add_argument("--idea", required=True)
    start.add_argument("--size", default="3840x2160")
    gen = commands.add_parser(
        "generate",
        help="Generate or resume images; makes paid API calls unless --dry-run",
    )
    gen.add_argument("directory", type=Path)
    gen.add_argument("--phase", action="append", choices=[s[0] for s in PHASES])
    gen.add_argument(
        "--force",
        action="store_true",
        help="Regenerate selected phases, replacing their PNGs",
    )
    gen.add_argument(
        "--dry-run",
        action="store_true",
        help="Print exact prompts/settings without API calls",
    )
    contact = commands.add_parser("preview", help="Create a labeled 3x3 contact sheet")
    contact.add_argument("directory", type=Path)
    contact.add_argument("--output", type=Path)
    pack = commands.add_parser(
        "build", help="Assemble with wallpapper and validate all nine mappings"
    )
    pack.add_argument("directory", type=Path)
    pack.add_argument(
        "--output", type=Path, help="HEIC destination (default: sibling <folder name>.heic)"
    )
    pack.add_argument(
        "--wallpapper", default="wallpapper", help="Assembler executable name or path"
    )
    pack.add_argument("--force", action="store_true")
    check = commands.add_parser(
        "inspect", help="Decode and inspect an existing time-based HEIC"
    )
    check.add_argument("heic", type=Path)
    check.add_argument(
        "--project",
        type=Path,
        help="Also compare frames and schedule against a project",
    )
    args = parser.parse_args()
    try:
        if args.command == "init":
            init(args.directory, args.idea, args.size)
        elif args.command == "generate":
            generate(args.directory, args.phase, args.force, args.dry_run)
        elif args.command == "preview":
            preview(args.directory, args.output)
        elif args.command == "build":
            build(args.directory.resolve(), args.output, args.wallpapper, args.force)
        else:
            print(json.dumps(inspect(args.heic, args.project), indent=2))
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as exc:
        parser.exit(1, f"Error: {exc}\n")


if __name__ == "__main__":
    main()
