"""Validates the mod files and packs dist/DriveTech.zip.

    python tools/build.py              # validate + build
    python tools/build.py --install    # also copy the zip into the BeamNG mods folder
"""
import json
import os
import re
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "mod")
DIST = os.path.join(ROOT, "dist", "DriveTech.zip")


def jbeam_to_json(text):
    """jbeam is relaxed JSON: comments, optional commas, trailing commas."""
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
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


def build():
    os.makedirs(os.path.dirname(DIST), exist_ok=True)
    tmp = DIST + ".tmp"
    with zipfile.ZipFile(tmp, "w", zipfile.ZIP_DEFLATED) as z:
        for folder, dirs, files in os.walk(MOD):
            dirs.sort()
            rel = os.path.relpath(folder, MOD).replace("\\", "/")
            if rel != ".":
                z.write(folder, rel + "/")
            for name in sorted(files):
                path = os.path.join(folder, name)
                z.write(path, os.path.relpath(path, MOD).replace("\\", "/"))
    os.replace(tmp, DIST)
    with zipfile.ZipFile(DIST) as z:
        assert z.testzip() is None
        return len([i for i in z.infolist() if not i.is_dir()])


def install():
    ini = os.path.join(os.environ.get("LOCALAPPDATA", ""), "BeamNG", "BeamNG.drive.ini")
    user = None
    if os.path.exists(ini):
        for line in open(ini, encoding="utf-8"):
            if line.strip().startswith("userFolder"):
                user = line.split("=", 1)[1].strip()
    if not user:
        sys.exit("BeamNG user folder not found, copy dist/DriveTech.zip into <user folder>/current/mods yourself")
    target = os.path.join(user, "current", "mods", "DriveTech.zip")
    # write under a temporary name first: a running game must never see a half-written zip
    tmp = target + ".part"
    with open(DIST, "rb") as src, open(tmp, "wb") as dst:
        dst.write(src.read())
    os.replace(tmp, target)
    print("installed:", target)


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
