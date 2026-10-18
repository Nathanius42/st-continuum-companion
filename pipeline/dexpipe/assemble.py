"""Assemble full Dex ship entries from every source the pipeline reads so far.

Combines the .ship record, the .def fields, the build-list entry, the inclusion verdicts and the
variants into the shape defined by data/schema/ships.schema.json. Canon, credits and media are
filled in by later steps; until then they're null or empty.
"""
from __future__ import annotations

import re
from collections import defaultdict

from .buildlists import build_entries, research_options, split_description
from .defs import def_fields
from .canon import canon_for
from .content import apply_overlay
from .credits import credits_for
from .icons import icon_path
from .inclusion import classify, keepers, starting_fleet
from .notable import notable_ships
from .research import resolve
from .subsystems import ship_subsystems
from .turntables import turntable_for

STAT_KEYS = ("maxHealth", "maxSpeed", "buildCost", "buildTime", "length", "width")


def _full_stats(record: dict, d: dict) -> dict:
    return {**record["stats"], "length": d["length"], "width": d["width"]}


def _variant_label(hull: str, parent: str, record: dict, kind: str, parent_record: dict | None = None) -> str:
    if kind == "separation" and parent_record and record["name"] == parent_record["name"]:
        # Multi-vector sections (Prometheus, Brisbane) carry their parent's name in
        # game; the toggle names them by vector, as the mod's name lists do.
        m = re.search(r"_(alpha|beta|gamma|delta)$", hull, re.I)
        if m:
            return f"Vector {m.group(1).title()}"
        return record.get("subtitle") or record["name"]
    if kind in ("escort", "separation"):
        return record["name"]
    if kind == "refit":
        if parent_record and record["name"] != parent_record["name"]:
            return record["name"]
        m = re.search(r"\(([^)]+)\)", record.get("subtitle") or "")  # e.g. "Heavy Explorer (Refit)"
        return m.group(1) if m else "Refit"
    suffix = hull[len(parent):].strip("_") if hull.startswith(parent) else hull
    m = re.search(r"(\d+b?)$", hull)
    return f"Type {m.group(1)}" if m else suffix.replace("_", " ").title()


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "variant"


def assemble(records: list[dict]) -> tuple[list[dict], list]:
    """Return (entries, verdicts). Entries are top-level Dex ships with variants attached."""
    verdicts = classify(records)
    rec = {(r["era"], r["id"]): r for r in records}
    by_parent = defaultdict(list)
    for v in verdicts:
        if v.status == "variant" and v.parent:
            by_parent[(v.era, v.parent)].append(v)

    entries = []
    for v in verdicts:
        if v.status != "include":
            continue
        r = rec[(v.era, v.hull)]
        d = def_fields(v.era, v.hull)
        build = build_entries(v.era).get(v.hull)
        availability = []
        if build:
            availability.append("buildable")
        if v.hull in starting_fleet(v.era):
            availability.append("starting-fleet")
        if v.hull in keepers(v.era):
            availability.append("keeper")
        if not availability:
            availability.append("special")  # included on Nathan's answer: missions, Invasion, map stations
        name = r["name"]
        if (not name or name.startswith("$")) and build and build.get("displayedName"):
            name = build["displayedName"]  # .ship holds a stock localisation code; the build list has the text
        entry = {
            "id": v.hull,
            "era": v.era,
            "faction": r["faction"],
            "name": name,
            "subtitle": r["subtitle"],
            "availability": availability,
            "classification": {**r["classification"], "sizeCategory": d["sizeCategory"]},
            "stats": _full_stats(r, d),
            "roles": d["roles"],
            "weapons": r["weapons"],
            "abilities": r["abilities"],
            "description": split_description(build["description"]) if build else None,
            "research": resolve(research_options(build["requiredResearch"]), v.era)[0] if build else None,
            "canon": canon_for(v.hull),
            "credits": credits_for(v.hull, r["model"]),
            "media": {"icon": icon_path(v.era, v.hull), "turntable": turntable_for(r["model"])},
            "variants": _variants(v, by_parent.get((v.era, v.hull), []), rec),
            "source": {"ship": r["source"]["ship"], "def": d["defPath"], "build": build["file"] if build else None},
            # Pipeline-only facts, stripped before the app's data file is written.
            "_pipeline": {
                "model": r["model"],
                "researchFieldPresent": bool(build) and build["requiredResearch"] is not None,
                "buildFields": build["unknownFields"] if build else [],
                "dexWritten": [],
            },
        }
        notable = notable_ships(v.era, v.hull)
        if notable:
            entry["notableShips"] = notable
        if v.show_only_on:
            entry["showOnlyOn"] = v.show_only_on
        apply_overlay(entry)
        entries.append(entry)
    return entries, verdicts


def _variants(parent_verdict, members, rec) -> list[dict]:
    """Variants for one parent. Escorts that share a model collapse into one variant with a count."""
    era, parent = parent_verdict.era, parent_verdict.hull
    parent_stats = _full_stats(rec[(era, parent)], def_fields(era, parent))
    groups = defaultdict(list)
    for v in sorted(members, key=lambda m: m.hull):
        r = rec[(era, v.hull)]
        key = (v.kind, r["model"], r["name"]) if v.kind == "escort" else (v.kind, v.hull, None)
        groups[key].append(v)

    out, used = [], set()
    for (kind, _model, _name), vs in groups.items():
        first = vs[0]
        r = rec[(era, first.hull)]
        d = def_fields(era, first.hull)
        stats = _full_stats(r, d)
        override = {k: stats[k] for k in STAT_KEYS if stats[k] is not None and stats[k] != parent_stats[k]}
        parent_record = rec[(era, parent)]
        label = _variant_label(first.hull, parent, r, kind, parent_record)
        own_subtitle = r["subtitle"] if r["subtitle"] and r["subtitle"] != parent_record["subtitle"] else None
        own_icon = icon_path(era, first.hull)
        vid = _slug(label)
        while vid in used:
            vid += "-2"
        used.add(vid)
        variant = {
            "id": vid,
            "label": label,
            "kind": kind,
            "hullId": first.hull,
            "subsystemId": None,
            "description": own_subtitle,
            "stats": override or None,
            "media": _variant_media(own_icon, icon_path(era, parent), r["model"], rec[(era, parent)]["model"]),
        }
        if kind == "escort":
            variant["count"] = len(vs)
            variant["hullIds"] = [x.hull for x in vs]
        out.append(variant)

    for toggle in ship_subsystems(era).get(parent, []):
        vid = _slug(toggle["label"])
        while vid in used:
            vid += "-2"
        used.add(vid)
        out.append({
            "id": vid,
            "label": toggle["label"],
            "kind": toggle["kind"],
            "hullId": None,
            "subsystemId": toggle["subsystemId"],
            "description": toggle["description"],
            **({"baseLabel": toggle["baseLabel"]} if toggle.get("baseLabel") else {}),
            "stats": _subsystem_stats(parent_stats, toggle) or None,
            # The ship rendered with this module fitted (pipeline/render/batch.py).
            "media": _subsystem_media(rec[(era, parent)]["model"], toggle["key"]),
        })
    return out


def _variant_media(icon, parent_icon, model, parent_model) -> dict | None:
    """A variant's own icon and turntable, where they differ from its parent's."""
    own_icon = icon if icon and icon != parent_icon else None
    own_turntable = turntable_for(model) if model != parent_model else None
    if not own_icon and not own_turntable:
        return None
    return {"icon": own_icon, "turntable": own_turntable}


def _subsystem_media(model: str, key: str) -> dict | None:
    """The ship rendered in the toggle's model state, keyed <model>@<subsystem, research or state>."""
    turntable = turntable_for(f"{model}@{key}")
    return {"icon": None, "turntable": turntable} if turntable else None


def _subsystem_stats(parent_stats: dict, refit: dict) -> dict:
    """The fitted ship's stats: multipliers applied, and cost and time to field one (hull plus subsystem)."""
    stats = {}
    for key, factor in refit["multipliers"].items():
        if parent_stats.get(key) is not None and factor != 1:
            value = parent_stats[key] * factor
            stats[key] = round(value) if key == "maxHealth" else round(value, 2)
    for key in ("buildCost", "buildTime"):
        if parent_stats.get(key) is not None and refit[key]:
            total = parent_stats[key] + refit[key]
            stats[key] = round(total) if key == "buildCost" else total
    return stats
