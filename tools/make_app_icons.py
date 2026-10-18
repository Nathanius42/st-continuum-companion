"""Make the Android launcher icons from the Star Trek Continuum icon (#924).

Usage: pipeline/.venv/Scripts/python.exe tools/make_app_icons.py [source.png]

The source defaults to the mod's 256 px icon (HW2\\Tools\\Logos\\STC_Icon_256.png). Writes:
- mipmap-<density>/ic_launcher.png: the legacy icon, the logo on transparency.
- mipmap-<density>/ic_launcher_foreground.png: the adaptive icon's foreground, 108 dp
  square with the logo inside the 66 dp safe zone, so no launcher mask clips it.
- mipmap-anydpi-v26/ic_launcher.xml and values/ic_launcher_background.xml: the adaptive
  icon, the logo over LCARS black.
The Windows icon is the mod's own STC_icon.ico (16 to 256 px), copied as app_icon.ico.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
SOURCE = Path(sys.argv[1] if len(sys.argv) > 1 else
              r"D:\Modding Tools\HW2TREKMOD\HW2\Tools\Logos\STC_Icon_256.png")
# Launcher icon size in px per density (48 dp), and the adaptive foreground (108 dp).
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
SAFE_ZONE = 66 / 108


def fitted(logo: Image.Image, size: int, fraction: float) -> Image.Image:
    """The logo scaled to fit `fraction` of a size x size square, centred."""
    box = round(size * fraction)
    scale = box / max(logo.size)
    art = logo.resize((max(1, round(logo.width * scale)), max(1, round(logo.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(art, ((size - art.width) // 2, (size - art.height) // 2), art)
    return canvas


def main():
    logo = Image.open(SOURCE).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    for name, factor in DENSITIES.items():
        folder = RES / f"mipmap-{name}"
        folder.mkdir(exist_ok=True)
        fitted(logo, round(48 * factor), 0.92).save(folder / "ic_launcher.png", optimize=True)
        fitted(logo, round(108 * factor), SAFE_ZONE * 0.95).save(folder / "ic_launcher_foreground.png", optimize=True)
    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Adaptive launcher icon (#924); made by tools/make_app_icons.py. -->\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n', encoding="utf-8")
    (RES / "values" / "ic_launcher_background.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<resources>\n'
        '    <!-- LCARS black behind the Star Trek Continuum icon (#924). -->\n'
        '    <color name="ic_launcher_background">#000000</color>\n'
        '</resources>\n', encoding="utf-8")
    print(f"Android icons written from {SOURCE}")


if __name__ == "__main__":
    main()
