"""Check the inclusion rules (#602) on known hulls."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe import inclusion  # noqa: E402
from dexpipe.inclusion import classify  # noqa: E402
from dexpipe.ships import ship_record  # noqa: E402

CASES = {
    ("TNG", "fed_TNG_galaxy"): ("include", None),
    ("TOS", "kng_TOS_d7"): ("include", None),
    ("TNG", "car_TNG_galor"): ("include", None),          # from def_build.lua, not build/*.lua
    ("TNG", "zzz_TNG_crystallineentity"): ("include", None),  # Keeper
    ("TNG", "fed_TNG_galaxy_saucer"): ("variant", "fed_TNG_galaxy"),
    ("TOS", "kng_TOS_d7_tutorial"): ("exclude", None),
    ("TNG", "zzz_shockwave_1000"): ("exclude", None),
    ("TNG", "fed_TNG_premonition"): ("ask", None),
}


def _verdicts(monkeypatch, groups=None, decisions=None):
    monkeypatch.setattr(inclusion, "load_group_rules", lambda: groups or [])
    monkeypatch.setattr(inclusion, "load_decisions", lambda: decisions or {})
    records = [ship_record(era, hull) for era, hull in CASES]
    return {(v.era, v.hull): v for v in classify(records)}


def test_rules(monkeypatch):
    got = _verdicts(monkeypatch)
    for key, (status, parent) in CASES.items():
        assert got[key].status == status, key
        assert got[key].parent == parent, key


def test_answers_win(monkeypatch):
    got = _verdicts(
        monkeypatch,
        decisions={"TNG/fed_TNG_premonition": {"include": True, "note": "yes"}},
        groups=[{"group": "Tutorials", "pattern": "_tutorial$", "include": True}],
    )
    assert got[("TNG", "fed_TNG_premonition")].status == "include"
    # group answers only apply to hulls that would otherwise be asked about
    assert got[("TOS", "kng_TOS_d7_tutorial")].status == "exclude"


def test_escorts_merges_and_variant_answers(monkeypatch):
    monkeypatch.setattr(inclusion, "load_group_rules", lambda: [
        {"group": "Construction Bees", "pattern": r"_constructor\d*b?$", "include": True, "merge": True},
        {"group": "Carrier drones", "pattern": r"drone\d*$", "include": True, "escort": True},
    ])
    monkeypatch.setattr(inclusion, "load_decisions", lambda: {
        "ENT/fed_ENT_VUL_dkyr_shuttle": {"variantOf": "fed_ENT_VUL_dkyr", "kind": "separation"},
    })
    hulls = [("TNG", "car_TNG_brinok_drone1"), ("TNG", "fed_TNG_constructor1"), ("TNG", "fed_TNG_constructor2b"),
             ("ENT", "fed_ENT_VUL_dkyr_shuttle"), ("TNG", "car_TNG_norin1")]
    got = {(v.era, v.hull): v for v in classify([ship_record(e, h) for e, h in hulls])}
    assert (got[("TNG", "car_TNG_brinok_drone1")].status, got[("TNG", "car_TNG_brinok_drone1")].parent) == ("variant", "car_TNG_brinok")
    assert got[("TNG", "car_TNG_brinok_drone1")].kind == "escort"
    assert got[("TNG", "fed_TNG_constructor1")].status == "include"
    assert (got[("TNG", "fed_TNG_constructor2b")].status, got[("TNG", "fed_TNG_constructor2b")].parent) == ("variant", "fed_TNG_constructor1")
    assert (got[("ENT", "fed_ENT_VUL_dkyr_shuttle")].parent, got[("ENT", "fed_ENT_VUL_dkyr_shuttle")].kind) == ("fed_ENT_VUL_dkyr", "separation")
    # the Hutet's Norin escorts don't end in "drone", so the drone group doesn't touch them
    assert got[("TNG", "car_TNG_norin1")].status == "ask"
