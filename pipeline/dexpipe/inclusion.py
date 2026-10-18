"""Decide which hulls appear in the Dex (#602).

The ruling (2026-10-17): every buildable ship and the Keepers are in; obvious tutorial or
internal copies are out; anything unclear goes on a yes/no list for Nathan. Separation parts
aren't entries of their own: they become variants of their parent ship.

Answers to the yes/no list live in data/hull-decisions.json and always win over the rules.
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

from .lua_ship import strip_comments
from .ships import ERA_FOLDERS, HWRM

ROOT = Path(__file__).resolve().parents[2]
DECISIONS_FILE = ROOT / "data" / "hull-decisions.json"

_HULL_TOKEN = re.compile(r"\b[a-z]{3}_[A-Z]{3}_[A-Za-z0-9_]+\b")
_BUILD_ENTRY = re.compile(r'Type\s*=\s*Ship\s*,\s*ThingToBuild\s*=\s*"([^"]+)"')
_FLEET_ENTRY = re.compile(r'\btype\s*=\s*"([^"]+)"')
_KEEPER_TABLE = re.compile(r"KEEP_tArchetypes\s*=\s*\{(.*?)\n\}", re.S)
_KEEPER_ROW = re.compile(r'\{\s*"[^"]*"\s*,\s*"([^"]+)"')

# Effect and helper objects the mod builds as hulls; never ships.
_EFFECT_NAME = re.compile(r"shockwave|blackhole|camera|ticker|instantdead|_wave$|singularity|gravity|^zzz_(?!TNG_|ENT_|TOS_|TMP_)", re.I)


@dataclass
class Verdict:
    hull: str
    era: str
    status: str            # include | exclude | variant | ask
    reason: str
    parent: str | None = None   # for variants: the hull whose page it appears on
    kind: str | None = None     # for variants: separation | escort | loadout | subsystem | refit
    evidence: list = field(default_factory=list)
    show_only_on: dict | None = None  # {month, day}: the app shows the entry only on that date


_DRONE_HOST = re.compile(r'hostClass\s*=\s*"([^"]+)"\s*,.*?dronePrefix\s*=\s*"([^"]+)"', re.S)


def drone_hosts(era: str) -> list[tuple[str, str]]:
    """(drone prefix, carrier) pairs from DRONE_SetupHostClass in the era's ship code."""
    f = HWRM / ERA_FOLDERS[era] / "scripts" / "continuum" / "shipscope" / "EraSpecific" / "EraSpecificShipCode.lua"
    if not f.exists():
        return []
    return [(prefix, host) for host, prefix in _DRONE_HOST.findall(_read(f))]


def _host_for(hull: str, hosts: list[tuple[str, str]]) -> str | None:
    """The carrier whose drone prefix (followed only by a number) matches this hull."""
    for prefix, host in hosts:
        if re.fullmatch(re.escape(prefix) + r"\d+", hull):
            return host
    return None


def _read(path: Path) -> str:
    return strip_comments(path.read_text(encoding="utf-8", errors="replace"))


def build_list_files(era: str) -> list[Path]:
    """Every race's build lists: scripts/build/*.lua for some races, scripts/def_build.lua for others."""
    races = HWRM / ERA_FOLDERS[era] / "scripts" / "races"
    return sorted(races.glob("*/scripts/build/*.lua")) + sorted(races.glob("*/scripts/def_build.lua"))


def buildable(era: str) -> set[str]:
    out = set()
    for f in build_list_files(era):
        out |= set(_BUILD_ENTRY.findall(_read(f)))
    return out


def starting_fleet(era: str, full: bool = False) -> set[str]:
    """Hulls in the era's starting fleets. Each race has four options (<race>00<ERA>0 to 3);
    the last, 3, is the full fleet, with nearly every class, so it's left out of what the
    Dex calls the starting fleet unless `full` is asked for."""
    out = set()
    for f in (HWRM / ERA_FOLDERS[era] / "scripts" / "startingfleets").glob("*.lua"):
        if not full and f.stem.endswith("3"):
            continue
        out |= set(_FLEET_ENTRY.findall(_read(f)))
    return out


def keepers(era: str) -> set[str]:
    f = HWRM / ERA_FOLDERS[era] / "scripts" / "continuum" / "gamescope" / "stc_randomMapGenerator.lua"
    if not f.exists():
        return set()
    m = _KEEPER_TABLE.search(_read(f))
    return set(_KEEPER_ROW.findall(m.group(1))) if m else set()


def reference_index(era: str) -> dict[str, set[str]]:
    """Which script and level files mention each hull, outside its own ship folder."""
    index = defaultdict(set)
    base = HWRM / ERA_FOLDERS[era]
    for sub in ("scripts", "leveldata", "ai"):
        for f in (base / sub).rglob("*"):
            if f.suffix.lower() not in (".lua", ".level") or not f.is_file():
                continue
            rel = f.relative_to(base).as_posix()
            for token in set(_HULL_TOKEN.findall(_read(f))):
                index[token].add(rel)
    return index


def _load_file() -> dict:
    if DECISIONS_FILE.exists():
        return json.loads(DECISIONS_FILE.read_text(encoding="utf-8"))
    return {}


def load_decisions() -> dict:
    """Per-hull answers, keyed "ERA/hull_id". These win over everything."""
    return _load_file().get("decisions", {})


def load_group_rules() -> list[dict]:
    """Answers given for a whole review group: {"group", "pattern", "include", "note"}."""
    return _load_file().get("groups", [])


def _matching_group_rule(hull: str, rules: list[dict]) -> dict | None:
    for rule in rules:
        if re.search(rule["pattern"], hull):
            return rule
    return None


# Review groups for unclear hulls: (group name, pattern, what they are, suggested answer).
REVIEW_GROUPS = [
    ("Construction Bees", r"_constructor\d*b?$", "Small 'Construction Bee' helpers that build stations", "no"),
    ("Carrier drones", r"drone\d*$", "Fighters launched by carriers (e.g. Kilhra'en, Warfang, MoKtal)", "yes, as a variant on the carrier's page"),
    ("Flagships", r"_flagship$", "Each faction's starting flagship (S.S. Enterprise, I.K.S. Qun'Ro…)", "yes"),
    ("Outposts", r"_outpost$", "Each faction's starting base", "yes"),
    ("Tal'Shiar spies", r"_spy$", "The Romulan espionage unit spawned by the Espionage ability", "yes"),
    ("Starbases and civilian stations", r"_starbase$|_CIV_", "Map stations and civilian outposts placed on maps and in Invasion", "yes"),
    ("Brisbane easter egg", r"_brisbane", "The USS Brisbane, the 28 July Keeper easter egg (with its separation parts)", "yes"),
]


def _describe_refs(files: set[str]) -> list[str]:
    """Group reference paths into short, readable evidence."""
    labels = []
    groups = {
        "AI catalog": lambda p: p.startswith("ai/"),
        "starting fleets": lambda p: "startingfleets" in p,
        "campaign / missions": lambda p: "campaign" in p or "singleplayer" in p,
        "invasion waves": lambda p: "invasion" in p,
        "build lists": lambda p: "/build/" in p,
        "research": lambda p: "/research/" in p,
    }
    rest = set(files)
    for label, test in groups.items():
        hits = {p for p in files if test(p)}
        if hits:
            labels.append(label)
            rest -= hits
    labels += sorted(rest)[:4]
    if len(rest) > 4:
        labels.append(f"+{len(rest) - 4} more")
    return labels


def classify(records: list[dict]) -> list[Verdict]:
    """Classify the .ship-derived records from ships.parse (one per era and hull)."""
    decisions = load_decisions()
    rules = load_group_rules()
    by_era = defaultdict(list)
    for r in records:
        by_era[r["era"]].append(r)

    verdicts = []
    merge_candidates = []  # (verdict, record) for groups answered with "merge"
    for era, recs in by_era.items():
        built, fleet, keep = buildable(era), starting_fleet(era, full=True), keepers(era)
        refs = reference_index(era)
        hosts = drone_hosts(era)
        ids = {r["id"] for r in recs}
        for r in recs:
            hull = r["id"]
            key = f"{era}/{hull}"
            evidence = _describe_refs(refs.get(hull, set()))

            if key in decisions:
                d = decisions[key]
                note = d.get("note")
                if d.get("variantOf"):
                    verdicts.append(Verdict(hull, era, "variant", f"Nathan: {note or 'variant'}", parent=d["variantOf"], kind=d.get("kind", "loadout"), evidence=evidence))
                else:
                    status = "include" if d["include"] else "exclude"
                    verdicts.append(Verdict(hull, era, status, f"Nathan: {note or ('yes' if d['include'] else 'no')}",
                                            evidence=evidence, show_only_on=d.get("showOnlyOn")))
                continue
            if r["classification"].get("unitCapsFamily") == "SeparationPart":
                parent = max((i for i in ids if hull.startswith(i + "_")), key=len, default=None)
                verdicts.append(Verdict(hull, era, "variant", "separation part", parent=parent, kind="separation", evidence=evidence))
                continue
            if hull.endswith("_tutorial"):
                verdicts.append(Verdict(hull, era, "exclude", "tutorial copy"))
                continue
            if _EFFECT_NAME.search(hull) or (r["stats"]["buildCost"] is None and hull.startswith("zzz_")):
                verdicts.append(Verdict(hull, era, "exclude", "effect or helper object"))
                continue
            if "researchicon" in hull:
                verdicts.append(Verdict(hull, era, "exclude", "research-tree icon holder"))
                continue
            if hull in built:
                verdicts.append(Verdict(hull, era, "include", "buildable", evidence=evidence))
                continue
            if hull in keep:
                verdicts.append(Verdict(hull, era, "include", "Keeper", evidence=evidence))
                continue
            group_rule = _matching_group_rule(hull, rules)
            if group_rule is not None:
                label = f"Nathan ({group_rule['group']})"
                host = _host_for(hull, hosts) if group_rule.get("escort") else None
                if group_rule["include"] and host:
                    verdicts.append(Verdict(hull, era, "variant", f"{label}: escort of {host}", parent=host, kind="escort", evidence=evidence))
                    continue
                status = "include" if group_rule["include"] else "exclude"
                note = group_rule.get("note") or ("yes" if group_rule["include"] else "no")
                verdict = Verdict(hull, era, status, f"{label}: {note}", evidence=evidence)
                verdicts.append(verdict)
                if group_rule["include"] and group_rule.get("merge"):
                    merge_candidates.append((verdict, r))
                continue
            why = "starting fleet only (not in any build list)" if hull in fleet else "not buildable, not a Keeper, not in a starting fleet"
            verdicts.append(Verdict(hull, era, "ask", why, evidence=evidence))

    # "merge" groups: hulls with the same era, faction and name become one entry plus variants.
    families = defaultdict(list)
    for verdict, r in merge_candidates:
        families[(r["era"], r["faction"], r["name"])].append(verdict)
    for members in families.values():
        members.sort(key=lambda v: v.hull)
        head = members[0]
        for v in members[1:]:
            v.status, v.parent, v.kind = "variant", head.hull, "loadout"
            v.reason += f" (merged into {head.hull})"
    return verdicts
