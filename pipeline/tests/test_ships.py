"""Check the .ship parser against the hand-filled samples (data/samples/ships.sample.json)."""
import json
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.lua_ship import parse_ship_text  # noqa: E402
from dexpipe.ships import ship_record  # noqa: E402

SAMPLES = {s["id"]: s for s in json.loads((ROOT / "data/samples/ships.sample.json").read_text(encoding="utf-8"))["ships"]}


@pytest.mark.parametrize("hull_id", sorted(SAMPLES))
def test_matches_sample(hull_id):
    sample = SAMPLES[hull_id]
    got = ship_record(sample["era"], hull_id)

    assert got["name"] == sample["name"]
    assert got["subtitle"] == sample["subtitle"]
    assert got["faction"] == sample["faction"]
    for key in ("displayFamily", "buildFamily", "unitCapsFamily"):
        assert got["classification"][key] == sample["classification"][key], key
    for key in ("maxHealth", "maxSpeed", "buildCost", "buildTime"):
        assert got["stats"][key] == sample["stats"][key], key
    assert got["weapons"] == sample["weapons"]
    assert sorted(a["id"] for a in got["abilities"]) == sorted(a["id"] for a in sample["abilities"])
    assert got["source"]["ship"] == sample["source"]["ship"]


def test_reader_handles_comments_multiline_calls_and_bare_decimals():
    ship = parse_ship_text(
        'NewShipType.displayedName = "Test" -- a comment\n'
        "NewShipType.maxhealth = 100\n"
        '-- StartShipWeaponConfig(NewShipType,"commented","Weapon_1","")\n'
        'addAbility(NewShipType,"RepairCommand",1,440,\n{Flagship=2.0},\n{SuperCap=.5})\n'
    )
    assert ship.scalars == {"displayedName": "Test", "maxhealth": 100}
    assert ship.calls_named("StartShipWeaponConfig") == []
    args = ship.calls_named("addAbility")[0]
    assert args[1] == "RepairCommand"
    assert args[-1].fields == {"SuperCap": 0.5}


def test_icons_read_both_rectangle_forms():
    from dexpipe.icons import icon_sources
    # textureUV_TL / textureUV_WH: a single 512 x 256 image.
    file, box = icon_sources("ENT")["thl_ent_webspinner"]
    assert file.name == "thl_ENT_webspinner.tga" and box == (0, 0, 512, 256)
    # textureUV: a rectangle in an atlas.
    assert icon_sources("TNG")["fed_tng_galaxy"][1][2] - icon_sources("TNG")["fed_tng_galaxy"][1][0] == 512
