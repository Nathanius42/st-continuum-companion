"""Check the Dex-written content overlay (#638, #639)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.content import FIELDS, apply_overlay, overlays, weapon_label  # noqa: E402


def test_weapon_labels_follow_the_mods_wording():
    assert weapon_label("kng_TNG_pulse_Mk11") == "Disruptor Pulses"
    assert weapon_label("fed_TNG_torpedo_quantum_Mk01_SP") == "Quantum Torpedoes"
    assert weapon_label("fed_ENT_torpedo_spatial_Mk08") == "Spatial Torpedoes"
    assert weapon_label("fed_ENT_VUL_phaser_Mk02") == "Vulcan Phasers"
    assert weapon_label("rom_ENT_MAC") == "Mass Accelerator Cannon"
    assert weapon_label("fed_TOS_macquarrie_turret") == "Pulse Phasers"


def _entry(**over):
    e = {"id": "fed_ENT_flagship", "faction": "federation", "subtitle": "Federation Flagship",
         "weapons": {"mounts": [{"weapon": "fed_ENT_phaser_Mk02"}, {"weapon": "fed_ENT_torpedo_spatial_Mk08"}]},
         "abilities": [{"id": "CloakAbility"}], "research": None, "description": None,
         "stats": {"length": None, "width": None}, "_pipeline": {"dexWritten": []}}
    e.update(over)
    return e


def test_overlay_fills_a_missing_description_and_derives_auto_fields():
    e = _entry()
    apply_overlay(e)
    d = e["description"]
    assert d["armament"] == ["Phaser Beams", "Spatial Torpedoes"]
    assert d["defences"] == ["Energy Shields", "Cloaking Device"]
    assert d["prerequisites"] == ["None"]
    assert d["crew"] == 83 and d["summary"]
    assert set(e["_pipeline"]["dexWritten"]) >= {"lead", "crew", "summary"}


def test_every_overlay_entry_is_well_formed():
    for hull, body in overlays().items():
        assert set(body) <= {"subtitle", "description", "dimensions", "source"}, hull
        assert set(body.get("description", {})) <= set(FIELDS), hull
        summary = body.get("description", {}).get("summary")
        if summary:
            assert len(summary) >= 60, hull
            # Australian English in player-facing text.
            for us in ("armor", "color", "center", "defense", "maneuver", "organize"):
                assert us not in summary.lower(), (hull, us)


def test_structures_show_no_crew_and_are_not_counted():
    import json
    sys.path.insert(0, str(ROOT / "pipeline"))
    from content_gaps import is_structure

    ships = {s["id"]: s for s in json.loads((ROOT / "app" / "assets" / "data" / "ships.json").read_text(encoding="utf-8"))["ships"]}
    for hull in ("fed_TNG_starbase", "fed_TMP_regula", "kng_TNG_CIV_tradingstation", "zzz_TNG_crystallineentity"):
        assert is_structure(ships[hull]), hull
    for hull in ("fed_TNG_galaxy", "rom_TNG_flagship"):
        assert not is_structure(ships[hull]), hull
