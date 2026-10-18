"""Check the .def and build-list readers (#415, #417)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.buildlists import build_entries, research_options, split_description  # noqa: E402
from dexpipe.defs import def_fields  # noqa: E402
from dexpipe.lua_ship import read_assigned_table  # noqa: E402
from dexpipe.research import resolve, starting_tree  # noqa: E402

SAMPLES = {s["id"]: s for s in json.loads((ROOT / "data/samples/ships.sample.json").read_text(encoding="utf-8"))["ships"]}


def test_descriptions_match_samples():
    for hull, sample in SAMPLES.items():
        entry = build_entries(sample["era"]).get(hull)
        if sample["description"] is None:
            assert entry is None, hull
            continue
        got = split_description(entry["description"])
        for key in ("lead", "crew", "armament", "defences", "prerequisites", "summary"):
            assert got[key] == sample["description"][key], (hull, key)
        assert resolve(research_options(entry["requiredResearch"]), sample["era"])[0] == sample["research"], hull


def test_def_fields_match_samples():
    for hull, sample in SAMPLES.items():
        d = def_fields(sample["era"], hull)
        assert d["sizeCategory"] == sample["classification"]["sizeCategory"], hull
        assert (d["length"], d["width"]) == (sample["stats"]["length"], sample["stats"]["width"]), hull
        assert d["roles"] == sample["roles"], hull


def test_unmanned_crew_and_extra_sections():
    d = split_description("Unmanned Probe\n\n<b>Crew Complement</b>\nN/A\n\n<b>Air Wing</b>\n8 Attack Drones\n\n<b>Summary</b>\nWatches.")
    assert d["crew"] == 0
    assert d["other"] == [{"title": "Air Wing", "items": ["8 Attack Drones"]}]
    assert d["summary"] == "Watches."


def test_crew_is_the_first_figure_and_the_rest_is_kept():
    d = split_description("Boarding Cruiser\n\n<b>Crew Complement</b>\n125 + 375 Marines\n\n<b>Summary</b>\nBoards ships.")
    assert d["crew"] == 125
    assert {"title": "Also aboard", "items": ["375 Marines"]} in d["other"]
    assert split_description("X\n\n<b>Crew Complement</b>\n1,200\n")["crew"] == 1200


def test_string_joins_and_empty_research():
    table = read_assigned_table('build = { { Type = Ship, Description = "Part one, " .. "part two" } }')
    assert table.items[0].fields["Description"] == "Part one, part two"
    assert research_options("") is None


def test_starting_trees_are_marked_not_named():
    research, missing = resolve(research_options("BRG_TNG_Research_Tree | BRG_TNG_Flagship_Tree"), "TNG")
    assert [(o["name"], o["startingTree"]) for o in research["anyOf"]] == [(None, "standard"), (None, "flagship")]
    assert missing == [] and starting_tree("Fed_TNG_CapitalTech") is None


def test_factions_come_from_entries_and_race_folders():
    from dexpipe.catalogue import factions
    entries = [
        {"id": "brn_TNG_chelgrett", "era": "TNG", "faction": "breen", "availability": ["buildable"]},
        {"id": "fed_TES_flagship", "era": "TOS", "faction": "terran", "availability": ["special"]},
        {"id": "fed_TNG_galaxy", "era": "TNG", "faction": "federation", "availability": ["buildable"]},
    ]
    got = {f["id"]: f for f in factions(entries)}
    assert got["breen"]["playable"] is False  # built by the Dominion, but no Breen race
    assert got["terran"] == {"id": "terran", "name": "Terran Empire", "prefixes": ["fed"], "playable": True, "eras": ["TOS"],
                             "logos": {"TOS": "assets/logos/TOS/terran.webp"}}
    assert got["federation"]["eras"] == ["TNG"]
