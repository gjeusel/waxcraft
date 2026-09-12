#!/usr/bin/env -S uv run --script
# /// script
# requires-python = "==3.12.*"
# dependencies = [
#   "pytest==8.4.2",
#   "openai==3.13.0",
#   "pillow==12.3.0",
#   "pillow-heif==1.7.0",
# ]
# ///

"""Offline tests; optional real HEIC assembly when wallpapper is installed."""

from __future__ import annotations

import base64
import io
import json
import shutil
import sys
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock

import openai
import pytest
import wallpaper as wall
from PIL import Image, ImageDraw


@pytest.fixture
def project(tmp_path):
    directory = tmp_path / "Hillside Cabin - Gouache"
    wall.init(
        directory,
        "A quiet hillside cabin, fixed camera, windows and lanterns",
        "1024x640",
    )
    return directory


def png_bytes(color):
    buffer = io.BytesIO()
    Image.new("RGB", (1024, 640), color).save(buffer, format="PNG")
    return buffer.getvalue()


def test_generation_resumes_after_failure_and_rejects_stale_images(
    project, monkeypatch
):
    monkeypatch.setenv("OPENAI_API_KEY", "test-placeholder")
    master = png_bytes("coral")
    edited = png_bytes("midnightblue")

    def response(data):
        return SimpleNamespace(
            data=[SimpleNamespace(b64_json=base64.b64encode(data).decode())], usage=None
        )

    def edit(*, image, **params):
        assert image.read() == master
        assert params["model"] == "gpt-image-2.5-sunburst"
        assert params["quality"] == "max"
        return response(edited)

    images = SimpleNamespace(
        generate=Mock(return_value=response(master)),
        edit=Mock(side_effect=RuntimeError("interrupted")),
    )
    factory = Mock(return_value=SimpleNamespace(images=images))
    monkeypatch.setattr(openai, "OpenAI", factory)
    with pytest.raises(RuntimeError, match="interrupted"):
        wall.generate(project, None, False, False)
    images.edit.side_effect = edit
    wall.generate(project, None, False, False)
    assert images.generate.call_count == 1  # Resume retained the paid master.
    assert images.edit.call_count == 9  # One failed attempt, eight successful edits.
    wall.generate(project, None, False, False)
    assert images.edit.call_count == 9
    assert len(list(project.glob("*.generation.json"))) == 9

    plan = wall.load_plan(project)
    plan["scenes"][0]["lighting"] += " A faint lavender horizon."
    wall.write_json(project / "plan.json", plan)
    with pytest.raises(ValueError, match="changed"):
        wall.generate(project, ["00-predawn"], False, False)
    wall.generate(project, ["00-predawn"], True, False)
    assert images.edit.call_count == 10
    plan["scene"] += " With a wider view."
    wall.write_json(project / "plan.json", plan)
    with pytest.raises(ValueError, match="master is stale"):
        wall.generate(project, ["01-sunrise"], True, False)


def test_dry_run_requires_no_credentials_and_plan_preserves_cycle(
    project, monkeypatch, capsys
):
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    monkeypatch.setattr(
        openai, "OpenAI", Mock(side_effect=AssertionError("No network client expected"))
    )
    capsys.readouterr()
    wall.generate(project, None, False, True)
    requests = [json.loads(line) for line in capsys.readouterr().out.splitlines()]
    assert len(requests) == 9
    assert requests[0]["phase"] == "03-midday"
    assert not list(project.glob("*.png"))
    plan = wall.load_plan(project)
    plan["scenes"][0]["time"] = "23:59:00"
    wall.write_json(project / "plan.json", plan)
    with pytest.raises(ValueError, match="daily cycle"):
        wall.load_plan(project)


@pytest.mark.skipif(
    not shutil.which("wallpapper"), reason="macOS wallpapper is required"
)
def test_real_heic_roundtrip_and_swapped_source_detection(project):
    plan = wall.load_plan(project)
    colors = [
        "red",
        "green",
        "blue",
        "gold",
        "purple",
        "orange",
        "cyan",
        "pink",
        "midnightblue",
    ]
    for index, (scene, color) in enumerate(zip(plan["scenes"], colors)):
        image = Image.new("RGB", (1024, 640), color)
        ImageDraw.Draw(image).rectangle(
            (index * 90, 80, index * 90 + 120, 500), fill="white"
        )
        image.save(project / f"{scene['id']}.png")
    wall.preview(project, None)
    with Image.open(project / "contact-sheet.jpg") as sheet:
        assert sheet.width == 1512
    wall.build(project, None, "wallpapper", False)
    wallpaper = project.parent / "Hillside Cabin - Gouache.heic"
    report = wall.inspect(wallpaper, project)
    assert set(project.parent.iterdir()) == {project, wallpaper}
    assert wall.read_json(project / "inspection.json") == report
    assert report["frames"] == 9
    assert report["mapping"]["03-midday"]["index"] == report["h24"]["ap"]["l"]
    assert report["mapping"]["08-deep-night"]["index"] == report["h24"]["ap"]["d"]
    assert next(
        e["t"]
        for e in report["h24"]["ti"]
        if e["i"] == report["mapping"]["00-predawn"]["index"]
    ) == pytest.approx(5.25 / 24)
    shutil.copyfile(project / "01-sunrise.png", project / "00-predawn.png")
    with pytest.raises(ValueError, match="does not visually match"):
        wall.inspect(wallpaper, project)


if __name__ == "__main__":
    raise SystemExit(pytest.main([str(Path(__file__)), "-q", *sys.argv[1:]]))
