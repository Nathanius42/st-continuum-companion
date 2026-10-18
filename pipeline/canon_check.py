"""Look up each Dex entry's class on Memory Alpha, then Memory Beta (#423).

Usage: python pipeline/canon_check.py
Reads app/assets/data/ships.json and writes pipeline/out/canon.candidates.json:
for each entry, the first wiki page that exists for its name (as "<name> class",
"<faction> <name>", "<name> type" or plain "<name>"), with that page's categories.

The wikis' HTML pages refuse scripted requests, but their MediaWiki APIs answer,
so this only asks the API whether titles exist; it never downloads articles.
The STO wiki sits behind a bot check, so tier G comes only from the reviewed
decisions in data/canon.source.json. The candidates are a starting point:
a page with the right title can still be the wrong thing (a person, a planet),
so every row is reviewed before it goes into canon.source.json.
"""
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHIPS = ROOT / "app" / "assets" / "data" / "ships.json"
OUT = ROOT / "pipeline" / "out" / "canon.candidates.json"

WIKIS = [
    ("A", "https://memory-alpha.fandom.com"),
    ("B", "https://memory-beta.fandom.com"),
]
AGENT = "ContinuumDex/1.0 (ship library for a Homeworld mod)"
ADJECTIVE = {
    "federation": ["Federation", "Starfleet", "Vulcan", "Andorian", "Tellarite", "Earth"],
    "klingon": ["Klingon"], "romulan": ["Romulan", "Remus"], "cardassian": ["Cardassian"],
    "dominion": ["Dominion", "Jem'Hadar", "Breen"], "borg": ["Borg"], "gorn": ["Gorn"],
    "voth": ["Voth"], "tholian": ["Tholian"], "breen": ["Breen"], "ferengi": ["Ferengi"],
    "terran": ["Terran"], "undine": ["Species 8472", "Undine"], "unaligned": [],
}
# Categories that mean the page is about a ship or a class, not a person or a place.
SHIPLIKE = ("starship", "class", "vessel", "ship", "spacecraft", "shuttle", "craft", "station")


def api(base: str, params: dict) -> dict:
    q = urllib.parse.urlencode({**params, "format": "json"})
    req = urllib.request.Request(f"{base}/api.php?{q}", headers={"User-Agent": AGENT})
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.load(r)
        except Exception:
            time.sleep(2 * (attempt + 1))
    return {}


def candidates(name: str, faction: str) -> list[str]:
    n = name.replace("I.R.W. ", "").replace("I.K.S. ", "").replace("U.S.S. ", "").strip()
    out = [f"{n} class", f"{n}-class"]
    out += [f"{adj} {n}" for adj in ADJECTIVE.get(faction, [])]
    out += [f"{n} type", n]
    return list(dict.fromkeys(out))


def lookup(base: str, titles: list[str]) -> dict[str, dict]:
    """title -> {page, categories} for those that exist (following redirects)."""
    found = {}
    for i in range(0, len(titles), 40):
        chunk = titles[i:i + 40]
        data = api(base, {"action": "query", "titles": "|".join(chunk), "redirects": 1,
                          "prop": "categories", "cllimit": "max", "clshow": "!hidden"})
        q = data.get("query", {})
        alias = {}
        for kind in ("normalized", "redirects"):
            for m in q.get(kind, []):
                alias[m["from"]] = m["to"]
        pages = {p["title"]: p for p in q.get("pages", {}).values() if "missing" not in p and "invalid" not in p}
        for t in chunk:
            target = t
            while target in alias:
                target = alias[target]
            if target in pages:
                cats = [c["title"].split(":", 1)[1] for c in pages[target].get("categories", [])]
                found[t] = {"page": target, "categories": cats}
        time.sleep(0.5)
    return found


def main():
    ships = json.loads(SHIPS.read_text(encoding="utf-8"))["ships"]
    wanted = {s["id"]: candidates(s["name"], s["faction"]) for s in ships}
    all_titles = sorted({t for ts in wanted.values() for t in ts})
    results = {}
    for tier, base in WIKIS:
        print(f"Asking {base} about {len(all_titles)} titles")
        results[tier] = lookup(base, all_titles)
    out = []
    for s in ships:
        row = {"id": s["id"], "name": s["name"], "faction": s["faction"], "era": s["era"],
               "subtitle": s["subtitle"], "match": None}
        for tier, base in WIKIS:
            for t in wanted[s["id"]]:
                hit = results[tier].get(t)
                if not hit:
                    continue
                shiplike = any(k in c.lower() for c in hit["categories"] for k in SHIPLIKE)
                if t == s["name"] and not shiplike:
                    continue  # a bare name that's a person or a planet
                row["match"] = {"tier": tier, "title": hit["page"], "asked": t, "shiplike": shiplike,
                                "url": f"{base}/wiki/{urllib.parse.quote(hit['page'].replace(' ', '_'))}",
                                "categories": hit["categories"][:8]}
                break
            if row["match"]:
                break
        out.append(row)
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
    hits = sum(1 for r in out if r["match"])
    print(f"{hits} of {len(out)} entries have a candidate page; wrote {OUT}")


if __name__ == "__main__":
    main()
