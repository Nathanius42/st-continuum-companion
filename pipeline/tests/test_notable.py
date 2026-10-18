"""Notable ships from era_ship_names.lua, with hand-kept registries (#934)."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "pipeline"))

from dexpipe.notable import _table, notable_ships  # noqa: E402


def test_table_reads_nested_lists_and_skips_comments():
    lua = 'x = 1\nstc_shipnames = {\n\t-- Cardassian --\n\tcar_a = {"C.D.S. One","C.D.S. Two"},\n\tcar_b = {"Solo"}\n}\nstc_mirrornames = { car_a = {"I.S.S. One"} }'
    assert _table(lua, "stc_shipnames") == {"car_a": ["C.D.S. One", "C.D.S. Two"], "car_b": ["Solo"]}
    assert _table(lua, "stc_mirrornames") == {"car_a": ["I.S.S. One"]}


def test_names_pair_with_registries_in_order():
    ships = notable_ships("TMP", "fed_TMP_excelsior")
    assert ships[0] == {"name": "U.S.S. Excelsior", "registry": "NCC-2000"}
    assert {"name": "U.S.S. Lamisa", "registry": "NCC-14700"} in ships


def test_placeholder_lists_and_unnamed_classes_are_empty():
    assert notable_ships("TNG", "fed_TNG_brisbane_alpha") == []
    assert notable_ships("TNG", "not_a_hull") == []


def test_names_match_the_hull_lettering():
    ships = notable_ships("TOS", "fed_TOS_mcquarrie")
    assert ships[13] == {"name": "U.S.S. Gourard", "registry": "NCC-1030"}
    assert notable_ships("TOS", "fed_TOS_DY750")[0] == {"name": "S.S. Leif Ericson", "registry": "NAR-1007"}
