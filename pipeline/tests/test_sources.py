"""Check the hand-kept credit and canon sources (#425, #423)."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.canon import SOURCE as CANON_SOURCE, canon_for  # noqa: E402
from dexpipe.credits import UNKNOWN, credits_for  # noqa: E402


def test_credits_by_hull_and_by_shared_model():
    galaxy = credits_for("fed_TNG_galaxy", "fed_TNG_galaxy")
    # The ReadMe.docx creator is the primary credit; the old Aad Moerman readme describes an earlier model.
    assert galaxy["authors"] == ["Major Stress"]
    # An entry that loads another hull's model takes that model's readme.
    shared = credits_for("not_a_hull", "fed_TNG_galaxy")
    assert shared["authors"] == galaxy["authors"]
    assert shared["note"].startswith("Shares the fed_TNG_galaxy model.")


def test_credits_unknown():
    assert credits_for("not_a_hull", None) == {"authors": [], "note": UNKNOWN}


def test_canon_entries_are_well_formed():
    data = json.loads(CANON_SOURCE.read_text(encoding="utf-8"))
    for hull, c in data.items():
        if hull.startswith("$"):
            continue
        assert c["tier"] in ("A", "B", "G", "none"), hull
        url = c.get("url")
        if c["tier"] == "A":
            assert url and url.startswith("https://memory-alpha.fandom.com/wiki/"), hull
        if url:
            assert url.startswith("https://"), hull
        # A class with no source must say why, so the page isn't just "none".
        if c["tier"] == "none":
            assert c.get("note"), hull


def test_canon_is_by_hull_only():
    assert canon_for("fed_TNG_galaxy")["tier"] == "A"
    assert canon_for("not_a_hull") is None
