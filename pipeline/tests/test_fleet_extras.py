import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dexpipe.terran import terran_fleet  # noqa: E402


def entry(hull, name, era="TOS", faction="federation", **extra):
    return {"id": hull, "era": era, "faction": faction, "name": name, "subtitle": "Heavy Cruiser",
            "media": {"icon": f"assets/icons/{era}/{hull}.webp", "turntable": None},
            "variants": [], "description": {"lead": "x", "summary": "y"}, "canon": None, **extra}


def test_each_tos_federation_ship_gets_a_terran_twin():
    ships = [entry("fed_TOS_constitution", "Constitution"),
             entry("fed_TOS_flagship", "U.S.S. Enterprise", notableShips=[{"name": "U.S.S. Exeter"}]),
             entry("fed_TMP_constitution", "Constitution", era="TMP"),
             entry("kng_TOS_d7", "D7", faction="klingon")]
    twins = {t["id"]: t for t in terran_fleet(ships)}
    assert set(twins) == {"fed_TES_constitution", "fed_TES_iss_flagship"}
    assert all(t["faction"] == "terran" for t in twins.values())
    flagship = twins["fed_TES_iss_flagship"]
    assert flagship["name"] == "I.S.S. Enterprise" and flagship["subtitle"] == "Terran Flagship"
    assert flagship["notableShips"][0]["name"] == "I.S.S. Exeter"
    assert flagship["canon"]["tier"] == "A"
    # The Federation's own entries are left as they were.
    assert ships[1]["name"] == "U.S.S. Enterprise" and ships[1]["faction"] == "federation"


def test_the_borg_outpost_upgrades_in_three_cumulative_stages():
    from dexpipe.subsystems import ship_subsystems
    stages = ship_subsystems("TNG")["brg_TNG_outpost"]
    assert [s["label"] for s in stages] == ["Stage 1", "Stage 2", "Stage 3"]
    assert stages[2]["addons"] == ["brg_TNG_outpost_1", "brg_TNG_outpost_2", "brg_TNG_outpost_3"]
    assert all(s["kind"] == "refit" and s["madstate"] is None for s in stages)
    assert "New units: Cube." in stages[2]["description"]
