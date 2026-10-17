"""Renders the F31 cluster with headless Edge/Chrome.

    python tools/render_cluster.py            # textures + previews
    python tools/render_cluster.py --preview  # previews only

Textures (2048 x 1024) go to mod/vehicles/etk800/drivetech_cluster/textures,
previews to docs/. The textures are the static daylight layers; the glowing
layer with needles and lamps is drawn live in game by cluster.js.
"""
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLUSTER = ROOT / "mod" / "vehicles" / "etk800" / "drivetech_cluster"
TEXTURES = CLUSTER / "textures"
DOCS = ROOT / "docs"

BROWSERS = [
    r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    "/usr/bin/chromium", "/usr/bin/google-chrome",
]


def browser():
    for b in BROWSERS:
        if os.path.exists(b):
            return b
    found = shutil.which("msedge") or shutil.which("chrome") or shutil.which("chromium")
    if not found:
        sys.exit("No Edge/Chrome found for headless rendering")
    return found


def render(query, target, profile):
    url = (CLUSTER / "cluster.html").as_uri() + "?" + query
    subprocess.run([
        browser(), "--headless=new", "--disable-gpu", "--hide-scrollbars",
        "--force-device-scale-factor=1", "--window-size=2048,1024",
        f"--user-data-dir={profile}", f"--screenshot={target}", url,
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    if not Path(target).exists():
        sys.exit(f"render failed: {query}")
    print("rendered", Path(target).relative_to(ROOT))


def crop(path):
    """Cuts the preview down to the instruments (the texture also holds unrelated UV islands)."""
    try:
        from PIL import Image
    except ImportError:
        return
    Image.open(path).crop((40, 190, 2008, 950)).save(path)


def main():
    TEXTURES.mkdir(parents=True, exist_ok=True)
    DOCS.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory() as profile:
        for theme in ("orange", "white"):
            render(f"render=preview&clean=1&theme={theme}", DOCS / f"cluster_{theme}.png", profile)
        render("render=preview&clean=1&theme=orange&lamptest=1&kmh=0&rpm=0&oil=40", DOCS / "cluster_lamptest.png", profile)
        for name in ("cluster_orange", "cluster_white", "cluster_lamptest"):
            crop(DOCS / f"{name}.png")
        if "--preview" not in sys.argv:
            for layer in ("base", "metal", "rough"):
                render(f"render={layer}", TEXTURES / f"drivetech_f31_{layer}.png", profile)
            for theme in ("orange", "white"):
                render(f"render=lit&theme={theme}", TEXTURES / f"drivetech_f31_lit_{theme}.png", profile)


if __name__ == "__main__":
    main()
