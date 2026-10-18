"""Mirror a reference website into data/reference/<site>/ for local theme research (#589).

Usage:
  python pipeline/mirror_reference.py inventory http://www.lcars.org.uk/
  python pipeline/mirror_reference.py fetch http://www.lcars.org.uk/ [stills|rest]

`inventory` crawls the site's pages (same host only) and lists the images and other files they
link to, writing data/reference/<host>/inventory.json. `fetch` downloads everything in the
inventory that isn't already on disk, keeping the site's folder layout; `stills` limits it to the
pages and still images, `rest` to everything else (videos, Flash, zips). Both go gently: one
request at a time with a pause between, so a small fan site isn't hammered.

The mirror stays on this machine (data/reference/ is git-ignored): the images belong to their
creators and to the studio.
"""
import http.client
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html import unescape
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REFERENCE = ROOT / "data" / "reference"
PAGE_TYPES = (".htm", ".html", "/")
ASSET_TYPES = (".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".tga", ".zip", ".swf", ".mp4", ".avi", ".wmv", ".mov", ".pdf")
USER_AGENT = "ContinuumDex-reference/1.0 (personal theme research; one request at a time)"
PAUSE = 0.4  # seconds between requests
MAX_PAGES = 3000

_LINK = re.compile(r"""(?:href|src|background)\s*=\s*["']([^"'#]+)["']""", re.I)


def get(url: str, timeout=60) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def classify(url: str) -> str | None:
    path = urllib.parse.urlparse(url).path.lower()
    if path.endswith(ASSET_TYPES):
        return "asset"
    if path.endswith(PAGE_TYPES) or "." not in path.rsplit("/", 1)[-1]:
        return "page"
    return None


def inventory(start: str) -> dict:
    host = urllib.parse.urlparse(start).netloc
    queue, seen_pages, assets, failed = [start], set(), set(), []
    while queue and len(seen_pages) < MAX_PAGES:
        url = queue.pop(0)
        if url in seen_pages:
            continue
        seen_pages.add(url)
        try:
            body = get(url).decode("latin-1", errors="replace")
        except (urllib.error.URLError, TimeoutError, ConnectionError, ValueError, http.client.HTTPException) as exc:
            failed.append((url, str(exc)))
            continue
        for raw in _LINK.findall(body):
            link = urllib.parse.urljoin(url, unescape(raw.strip()))
            parsed = urllib.parse.urlparse(link)
            # Template pages carry the real page in the query, e.g. lcarstemplate.htm?Page=Voyager.htm.
            page = urllib.parse.parse_qs(parsed.query).get("Page")
            if page:
                link = urllib.parse.urljoin(link, urllib.parse.quote(page[0]))
                parsed = urllib.parse.urlparse(link)
            if parsed.netloc != host or parsed.scheme not in ("http", "https"):
                continue
            # Encode spaces and the like consistently, so each page is fetched once.
            path = urllib.parse.quote(urllib.parse.unquote(parsed.path), safe="/%")
            link = parsed._replace(path=path, fragment="", query="").geturl()
            kind = classify(link)
            if kind == "asset":
                assets.add(link)
            elif kind == "page" and link not in seen_pages:
                queue.append(link)
        if len(seen_pages) % 25 == 0:
            print(f"  {len(seen_pages)} pages, {len(assets)} files so far", flush=True)
            checkpoint = REFERENCE / host / "inventory.partial.json"
            checkpoint.parent.mkdir(parents=True, exist_ok=True)
            checkpoint.write_text(json.dumps({"pages": sorted(seen_pages), "assets": sorted(assets)}), encoding="utf-8")
        time.sleep(PAUSE)
    return {"start": start, "host": host, "pages": sorted(seen_pages), "assets": sorted(assets), "failed": failed}


def local_path(host: str, url: str) -> Path:
    path = urllib.parse.unquote(urllib.parse.urlparse(url).path).lstrip("/") or "index.htm"
    if path.endswith("/"):
        path += "index.htm"
    safe = Path(*[re.sub(r'[<>:"|?*]', "_", part) for part in Path(path).parts])
    return REFERENCE / host / safe


def fetch(inv: dict, part: str = "all") -> None:
    host = inv["host"]
    # Pages and images first (small, and all the palette work needs); videos and the rest last.
    def order(u: str) -> int:
        ext = Path(urllib.parse.urlparse(u).path).suffix.lower()
        return 0 if ext in (".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".tga") else 1
    todo = [u for u in inv["pages"] + sorted(inv["assets"], key=order) if not local_path(host, u).exists()]
    if part == "stills":
        todo = [u for u in todo if u in inv["pages"] or order(u) == 0]
    elif part == "rest":
        todo = [u for u in todo if u not in inv["pages"] and order(u) == 1]
    total, failed = 0, []
    print(f"{len(todo)} to download ({len(inv['pages'])} pages, {len(inv['assets'])} files in the inventory)")
    for i, url in enumerate(todo, 1):
        out = local_path(host, url)
        try:
            data = get(url, timeout=120)
        except (urllib.error.URLError, TimeoutError, ConnectionError, ValueError, http.client.HTTPException) as exc:
            failed.append((url, str(exc)))
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(data)
        total += len(data)
        if i % 50 == 0:
            print(f"  {i}/{len(todo)}  {total / 1e6:.0f} MB", flush=True)
        time.sleep(PAUSE)
    print(f"Done: {total / 1e6:.0f} MB downloaded, {len(failed)} failed")
    if failed:
        (REFERENCE / host / "failed.json").write_text(json.dumps(failed, indent=1), encoding="utf-8")


def main():
    if len(sys.argv) not in (3, 4) or sys.argv[1] not in ("inventory", "fetch"):
        raise SystemExit(__doc__)
    mode, start = sys.argv[1], sys.argv[2]
    part = sys.argv[3] if len(sys.argv) == 4 else "all"
    host = urllib.parse.urlparse(start).netloc
    inv_file = REFERENCE / host / "inventory.json"
    if mode == "inventory":
        inv = inventory(start)
        inv_file.parent.mkdir(parents=True, exist_ok=True)
        inv_file.write_text(json.dumps(inv, indent=1), encoding="utf-8")
        kinds = {}
        for a in inv["assets"]:
            ext = Path(urllib.parse.urlparse(a).path).suffix.lower()
            kinds[ext] = kinds.get(ext, 0) + 1
        print(f"{len(inv['pages'])} pages, {len(inv['assets'])} files {kinds}, {len(inv['failed'])} failed")
    else:
        fetch(json.loads(inv_file.read_text(encoding="utf-8")), part)


if __name__ == "__main__":
    main()
