"""Validate a Dex ship data file against the schema and check cross-references.

Usage: python pipeline/validate.py [data-file]   (default: data/samples/ships.sample.json)
Exits non-zero if anything is wrong.
"""
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parent.parent
SCHEMA = ROOT / "data" / "schema" / "ships.schema.json"
WARNINGS = []  # worth knowing, but not errors (e.g. mod naming quirks)


def cross_reference_errors(data):
    """Rules JSON Schema can't express: ids that must exist, be unique or agree."""
    errors = []
    era_ids = {e["id"] for e in data["eras"]}
    factions = {f["id"]: f for f in data["factions"]}
    seen = set()
    for ship in data["ships"]:
        sid = ship["id"]
        if sid in seen:
            errors.append(f"{sid}: duplicate ship id")
        seen.add(sid)
        if ship["era"] not in era_ids:
            errors.append(f"{sid}: era {ship['era']} is not in eras")
        faction = factions.get(ship["faction"])
        if faction is None:
            errors.append(f"{sid}: faction {ship['faction']} is not in factions")
        else:
            if sid[:3] not in faction["prefixes"]:
                errors.append(f"{sid}: prefix {sid[:3]} doesn't belong to faction {faction['id']}")
            if ship["era"] not in faction["eras"]:
                errors.append(f"{sid}: faction {faction['id']} isn't listed for era {ship['era']}")
        if sid.split("_")[1] != ship["era"] and sid.split("_")[1] in era_ids:
            WARNINGS.append(f"{sid}: id says era {sid.split('_')[1]} but it lives in the {ship['era']} mod folder")
        w = ship["weapons"]
        counted = w["beam"] + w["pulse"] + w["torpedo"] + w.get("other", 0)
        if counted != w["total"]:
            errors.append(f"{sid}: weapon kinds add up to {counted}, total says {w['total']}")
        if len(w["mounts"]) != w["total"]:
            errors.append(f"{sid}: {len(w['mounts'])} mounts listed, total says {w['total']}")
        detailed = sum(d["count"] for d in w["details"])
        if detailed != w["total"]:
            errors.append(f"{sid}: weapon details count {detailed} mounts, total says {w['total']}")
        variant_ids = [v["id"] for v in ship["variants"]]
        if len(variant_ids) != len(set(variant_ids)):
            errors.append(f"{sid}: duplicate variant ids")
        if "buildable" in ship["availability"] and ship.get("description") is None:
            errors.append(f"{sid}: buildable but has no build description")
    return errors


def main():
    data_file = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data" / "samples" / "ships.sample.json"
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    data = json.loads(data_file.read_text(encoding="utf-8"))

    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    schema_errors = sorted(validator.iter_errors(data), key=lambda e: list(e.absolute_path))
    for e in schema_errors:
        path = "/".join(str(p) for p in e.absolute_path) or "(root)"
        print(f"schema: {path}: {e.message}")

    ref_errors = cross_reference_errors(data) if not schema_errors else []
    for msg in ref_errors:
        print(f"check: {msg}")

    for msg in WARNINGS:
        print(f"warning: {msg}")
    total = len(schema_errors) + len(ref_errors)
    print(f"{data_file.name}: {len(data['ships'])} ships, {total} problem(s)")
    sys.exit(1 if total else 0)


if __name__ == "__main__":
    main()
