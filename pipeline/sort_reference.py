"""Sort a mirrored reference site's stills by Dex theme (#589).

Usage: python pipeline/sort_reference.py [host]   (default: www.lcars.org.uk)
Reads the mirrored section pages in data/reference/<host>/, pairs each still with its caption,
and files it under a theme: the section sets the era (Enterprise pages are ENT, the TNG, DS9,
Voyager and TNG-film pages are TNG, The Original Series page is TOS), and on the alien-screens
page the race named in the file name or caption sets the faction. Writes
data/reference/<host>/themes.index.json, which pipeline/sample_palette.py reads alongside the
per-theme folders.
"""
import html
import json
import re
import sys
import urllib.parse
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "data" / "reference"

# Section page → theme for everything on it (None: decide per image from its race).
SECTIONS = {
    "Enterprise_panels.htm": "ent",
    "lcars_TNG_panels.htm": "tng",
    "lcars_DS9_panels.htm": "tng",
    "lcars_Voyager_panels.htm": "tng",
    "lcars_TNG_Films_panels.htm": "tng",
    "The Org Series.htm": "tos",
    "lcars_Alien_panels.htm": None,
}
# Race words → theme, checked in order (first match wins).
RACES = [
    # Races the Dex has no theme for come first, so their screens are left out.
    (r"bajoran|andorian|vulcan|vidiian|krenim|talaxian|son.?a|xindi|kazon|hirogen", None),
    (r"species.?8472|8472|undine", "undine"),
    (r"romulan|warbird|valdore|scimitar|reman|d.?deridex", "romulan"),
    (r"klingon|bird.?of.?prey|k.?vort|vor.?cha|neg.?h.?var|rotarran", "klingon"),
    (r"cardassian|galor|terok|empok|\bops\b", "cardassian"),
    (r"dominion|jem.?hadar|vorta|founder|breen", "dominion"),
    (r"borg|cube|assimilat", "borg"),
    (r"ferengi|ferengie|marauder|d.?kora|quark", "ferengi"),
    (r"terran|mirror", "terran"),
    (r"voth", "voth"),
    (r"gorn", "gorn"),
    (r"tholian", "tholian"),
]
_ENTRY = re.compile(r'<a[^>]+href="([^"]+)"[^>]*>\s*<img[^>]+src="([^"]+)"(.*?)(?=<a[^>]+href=|$)', re.I | re.S)
STILLS = (".jpg", ".jpeg", ".png", ".gif", ".bmp")
SKIP = re.compile(r"winzip|standard\.jpg|divider|anihead|awards/|buttons?/", re.I)


def text(fragment: str) -> str:
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()


def race_theme(words: str) -> str | None:
    low = words.lower()
    for pattern, theme in RACES:
        if re.search(pattern, low):
            return theme  # None for races without a Dex theme
    return None


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "www.lcars.org.uk"
    site = REFERENCE / host
    index: dict[str, list[dict]] = {}
    for page_name, section_theme in SECTIONS.items():
        page = site / page_name
        if not page.exists():
            print(f"missing {page_name}: not downloaded yet")
            continue
        body = page.read_text(encoding="latin-1", errors="replace")
        for link, src, after in _ENTRY.findall(body):
            src_path = urllib.parse.unquote(src)
            if not src_path.lower().endswith(STILLS) or SKIP.search(src_path):
                continue
            caption = text(after)[:160]
            theme = section_theme or race_theme(f"{src_path} {caption}")
            if theme is None:
                continue  # an alien race the Dex has no theme for (Bajoran, Vidiian and so on)
            local = site / Path(src_path)
            index.setdefault(theme, []).append({
                "file": str(local.relative_to(REFERENCE)).replace("\\", "/"),
                "caption": caption,
                "page": page_name,
                "downloaded": local.exists(),
            })
    out = site / "themes.index.json"
    out.write_text(json.dumps(index, indent=1, ensure_ascii=False), encoding="utf-8")
    counts = Counter({k: len(v) for k, v in index.items()})
    have = Counter({k: sum(e["downloaded"] for e in v) for k, v in index.items()})
    for theme, n in counts.most_common():
        print(f"  {theme:11s} {n:4d} stills ({have[theme]} downloaded)")
    print(f"Wrote {out.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
