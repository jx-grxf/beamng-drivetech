"""Validates the mod files and packs dist/DriveTech.zip.

    python tools/build.py              # validate + build
    python tools/build.py --install    # also install into the BeamNG mods folder (works while the game runs)
"""
import json
import os
import re
import sys
import time
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "mod")
DIST = os.path.join(ROOT, "dist", "DriveTech.zip")
DIST_CORE = os.path.join(ROOT, "dist", "DriveTech_core.zip")
DIST_APPS = os.path.join(ROOT, "dist", "DriveTech_apps.zip")


def strip_comments(text):
    """Removes // and /* */ comments outside of string literals."""
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        ch = text[i]
        if in_str:
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 1
            elif ch == '"':
                in_str = False
        elif ch == '"':
            in_str = True
            out.append(ch)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def jbeam_to_json(text):
    """jbeam is relaxed JSON: comments, optional commas, trailing commas."""
    text = strip_comments(text)
    # missing commas between values: `] [`, `} {`, `" {`, `1 [` ...
    text = re.sub(r'([\]}"0-9eE]|true|false|null)(\s+)(?=["\[{\-0-9tfn])', r"\1,\2", text)
    text = re.sub(r"([\]}])(?=[\[{\"])", r"\1,", text)  # `[]{...}` without whitespace
    text = re.sub(r",(\s*[\]}])", r"\1", text)
    text = re.sub(r",\s*,", ",", text)
    return text


def validate():
    problems = []
    for folder, _, files in os.walk(MOD):
        for name in files:
            path = os.path.join(folder, name)
            rel = os.path.relpath(path, MOD)
            if name.endswith((".jbeam", ".pc")):
                try:
                    json.loads(jbeam_to_json(open(path, encoding="utf-8").read()))
                except json.JSONDecodeError as e:
                    problems.append(f"{rel}: {e}")
            elif name.endswith(".json"):
                try:
                    json.load(open(path, encoding="utf-8"))
                except json.JSONDecodeError as e:
                    problems.append(f"{rel}: {e}")
    return problems


def pack(target, include):
    """Packs every file below mod/ for which include(relative_path) is true."""
    os.makedirs(os.path.dirname(target), exist_ok=True)
    tmp = target + ".tmp"
    count = 0
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, dirs, files in os.walk(MOD):
            dirs.sort()
            for name in sorted(files):
                path = os.path.join(folder, name)
                rel = os.path.relpath(path, MOD).replace("\\", "/")
                if include(rel):
                    # fixed timestamp: identical content gives an identical zip
                    info = zipfile.ZipInfo(rel, date_time=(2026, 1, 1, 0, 0, 0))
                    info.compress_type = zipfile.ZIP_DEFLATED
                    with open(path, "rb") as f:
                        z.writestr(info, f.read())
                    count += 1
    os.replace(tmp, target)
    with zipfile.ZipFile(target) as z:
        assert z.testzip() is None
    return count


def is_ui_app(rel):
    return rel.startswith("ui/")


def build():
    # one zip for releases, plus a core/apps split for hot reloading while the game runs
    full = pack(DIST, lambda rel: True)
    pack(DIST_CORE, lambda rel: not is_ui_app(rel))
    pack(DIST_APPS, is_ui_app)
    return full


def user_mods_folder():
    ini = os.path.join(os.environ.get("LOCALAPPDATA", ""), "BeamNG", "BeamNG.drive.ini")
    if os.path.exists(ini):
        for line in open(ini, encoding="utf-8"):
            if line.strip().startswith("userFolder"):
                return os.path.join(line.split("=", 1)[1].strip(), "current", "mods")
    sys.exit("BeamNG user folder not found, copy dist/DriveTech.zip into <user folder>/current/mods yourself")


def same_file(a, b):
    return os.path.exists(b) and open(a, "rb").read() == open(b, "rb").read()


def hot_swap(src, target):
    """Replaces a mod zip so that a running game picks it up cleanly."""
    if same_file(src, target):
        print("unchanged:", target)
        return
    if os.path.exists(target):
        # let the running game unmount the old zip first
        os.remove(target)
        time.sleep(4)
    # write under a temporary name: the game must never see a half-written zip
    tmp = target + ".part"
    with open(src, "rb") as s, open(tmp, "wb") as d:
        d.write(s.read())
    os.replace(tmp, target)
    print("installed:", target)


def install():
    mods = user_mods_folder()
    # the combined zip would duplicate every file of the split zips
    full = os.path.join(mods, "DriveTech.zip")
    if os.path.exists(full):
        os.remove(full)
        time.sleep(4)
    # BeamNG's UI app list can fail when an app arrives while the game runs,
    # so the apps zip is only touched when the app itself changed
    hot_swap(DIST_APPS, os.path.join(mods, "DriveTech_apps.zip"))
    hot_swap(DIST_CORE, os.path.join(mods, "DriveTech_core.zip"))


if __name__ == "__main__":
    issues = validate()
    if issues:
        print("Validation failed:")
        for p in issues:
            print("  " + p)
        sys.exit(1)
    print("validation ok")
    print(f"built {DIST} ({build()} files)")
    if "--install" in sys.argv:
        install()
