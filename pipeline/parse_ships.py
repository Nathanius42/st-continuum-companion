"""Parse every .ship file in the four eras and report what was found.

Usage: python pipeline/parse_ships.py
Writes pipeline/out/ships.parsed.json (the .ship-derived records) and prints a summary of
anything the later steps or the mod team should look at.
"""
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from dexpipe.ships import CUSTOM_COMMANDS, all_hulls, ship_record, weapon_fire_type  # noqa: E402

OUT = Path(__file__).resolve().parent / "out"


def main():
    records, failures = [], []
    for era, hull_id in all_hulls():
        try:
            records.append(ship_record(era, hull_id))
        except Exception as exc:  # report and carry on; one bad file shouldn't stop the run
            failures.append(f"{era} {hull_id}: {exc}")

    OUT.mkdir(exist_ok=True)
    (OUT / "ships.parsed.json").write_text(json.dumps(records, indent=1, ensure_ascii=False), encoding="utf-8")

    by_era = Counter(r["era"] for r in records)
    by_faction = defaultdict(Counter)
    for r in records:
        by_faction[r["era"]][r["faction"]] += 1
    missing = Counter()
    no_wepn, unknown_custom = set(), Counter()
    for r in records:
        for key, value in r["stats"].items():
            if value is None:
                missing[key] += 1
        if r["subtitle"] is None:
            missing["subtitle"] += 1
        for m in r["weapons"]["mounts"]:
            if weapon_fire_type(m["weapon"], r["era"]) is None:
                no_wepn.add(m["weapon"])
        for a in r["abilities"]:
            if a["name"] == "Special ability":
                unknown_custom[r["id"]] += 1

    print(f"Parsed {len(records)} hulls, {len(failures)} failed.")
    for f in failures:
        print(f"  FAILED {f}")
    print("By era:", dict(by_era))
    for era, counts in by_faction.items():
        print(f"  {era}: {dict(counts.most_common())}")
    print("Missing values:", dict(missing.most_common()))
    print(f"Weapons with no .wepn file (kind guessed from the name): {sorted(no_wepn) or 'none'}")
    print(f"Custom commands without a readable name: {dict(unknown_custom) or 'none'}")
    print(f"Known custom commands: {len(CUSTOM_COMMANDS)}")
    print(f"Wrote {OUT / 'ships.parsed.json'}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
