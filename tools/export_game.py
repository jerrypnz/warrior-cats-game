#!/usr/bin/env python3
"""
Package the game so it runs without Godot: in a browser, on Windows, macOS and Linux.

Every package is self-contained (the game data is built in), one zip per platform:

    dist/warrior-cats-web.zip       HTML5 version, for itch.io or any static web host
    dist/warrior-cats-windows.zip   one .exe (64-bit)
    dist/warrior-cats-macos.zip     a universal .app (Intel + Apple Silicon), ad-hoc signed
    dist/warrior-cats-linux.zip     one x86_64 program

Usage:
    python3 tools/export_game.py                  # every platform
    python3 tools/export_game.py web linux        # just these
    python3 tools/export_game.py web --serve      # ...then play it at http://localhost:8000

The unpacked builds stay in game/export/<platform>/ (game/export/web/ is what GitHub Pages
publishes). Godot needs export templates matching its exact version; any that are missing
are downloaded automatically, fetching only the files the chosen platforms need.

Exit code 0 = all packages built, 1 = an export failed, 2 = could not run Godot at all.
"""

import argparse
import functools
import http.server
import io
import os
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile
from pathlib import Path

from check_game import GAME_DIR, ROOT, find_godot

EXPORT_DIR = GAME_DIR / "export"
DIST_DIR = ROOT / "dist"
PACKAGE = "warrior-cats"
MAC_APP = "Warrior Cats.app"  # Godot names it after the project, turning ":" into "-"

# platform: (preset name in export_presets.cfg, exported file name, templates it needs)
PLATFORMS = {
    "web": ("Web", "index.html", ["web_nothreads_release.zip"]),
    "windows": ("Windows", "WarriorCats.exe", ["windows_release_x86_64.exe"]),
    "macos": ("macOS", "WarriorCats.zip", ["macos.zip"]),
    "linux": ("Linux", "WarriorCats.x86_64", ["linux_release.x86_64"]),
}

TEMPLATES_URL = ("https://github.com/godotengine/godot-builds/releases/download/"
                 "{tag}/Godot_v{tag}_export_templates.tpz")


def godot_version(godot):
    """'4.6.3.stable.official.7d41c59c4' -> ('4.6.3.stable', '4.6.3-stable')."""
    out = subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.strip()
    m = re.match(r"(\d+(?:\.\d+)+)\.([a-z]+\d*)\.", out)
    if not m:
        sys.exit(f"Could not understand the Godot version {out!r}.")
    if ".official." not in out:
        print(f"Note: {out} is not an official Godot build; official templates may not fit.")
    return f"{m[1]}.{m[2]}", f"{m[1]}-{m[2]}"


def templates_dir(version):
    if sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot"
    elif sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
    return base / "export_templates" / version


class HttpRangeFile(io.RawIOBase):
    """A read-only, seekable view of a remote file, so zipfile can pull out single members
    of the 1.2 GB template archive without downloading all of it."""

    def __init__(self, url):
        with urllib.request.urlopen(urllib.request.Request(url, method="HEAD")) as r:
            self.url, self.size = r.geturl(), int(r.headers["Content-Length"])
        self.pos = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def tell(self):
        return self.pos

    def seek(self, offset, whence=io.SEEK_SET):
        self.pos = {io.SEEK_SET: 0, io.SEEK_CUR: self.pos, io.SEEK_END: self.size}[whence] + offset
        return self.pos

    def readinto(self, buffer):
        if self.pos >= self.size:
            return 0
        end = min(self.pos + len(buffer), self.size) - 1
        req = urllib.request.Request(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req) as r:
            if r.status != 206:
                raise OSError("the download server does not support partial downloads")
            data = r.read()
        buffer[:len(data)] = data
        self.pos += len(data)
        return len(data)


def ensure_templates(godot, platforms):
    version, tag = godot_version(godot)
    dest = templates_dir(version)
    needed = ["version.txt"] + [t for p in platforms for t in PLATFORMS[p][2]]
    missing = [t for t in needed if not (dest / t).exists()]
    if not missing:
        return
    url = TEMPLATES_URL.format(tag=tag)
    print(f"Downloading Godot {tag} export templates: {', '.join(missing)}")
    dest.mkdir(parents=True, exist_ok=True)
    remote = io.BufferedReader(HttpRangeFile(url), buffer_size=4 << 20)
    with zipfile.ZipFile(remote) as tpz:
        for name in missing:
            info = tpz.getinfo(f"templates/{name}")
            print(f"  {name} ({info.compress_size / 1e6:.0f} MB)")
            tmp = dest / f"{name}.part"
            with tpz.open(info) as src, open(tmp, "wb") as out:
                shutil.copyfileobj(src, out, 4 << 20)
            tmp.replace(dest / name)


def run_godot(godot, *args):
    proc = subprocess.run([godot, "--headless", "--path", str(GAME_DIR), *args],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout + proc.stderr


def export(godot, platform):
    preset, filename, _ = PLATFORMS[platform]
    out_dir = EXPORT_DIR / platform
    shutil.rmtree(out_dir, ignore_errors=True)
    out_dir.mkdir(parents=True)
    target = out_dir / filename
    code, log = run_godot(godot, "--export-release", preset, str(target))
    if code != 0 or not target.exists():
        print(f"  {platform}: export FAILED\n{log}")
        return None
    return package(platform, out_dir, target)


def package(platform, out_dir, target):
    DIST_DIR.mkdir(exist_ok=True)
    zip_path = DIST_DIR / f"{PACKAGE}-{platform}.zip"
    if platform == "macos":
        # Godot already zips and signs the .app; only give the bundle folder a tidier name
        # (the signature doesn't cover it). Copying each ZipInfo keeps permissions and symlinks.
        with zipfile.ZipFile(target) as src, zipfile.ZipFile(zip_path, "w") as dst:
            for info in src.infolist():
                data = src.read(info)
                info.filename = re.sub(r"^[^/]+\.app/", MAC_APP + "/", info.filename)
                dst.writestr(info, data)
        return zip_path
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in sorted(out_dir.rglob("*")):
            if path.is_file():
                info = zipfile.ZipInfo.from_file(path, path.relative_to(out_dir).as_posix())
                info.compress_type = zipfile.ZIP_DEFLATED
                with open(path, "rb") as f:
                    zf.writestr(info, f.read())  # from_file keeps the executable bit
    return zip_path


def serve(port):
    web_dir = EXPORT_DIR / "web"
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(web_dir))
    try:
        server = http.server.ThreadingHTTPServer(("localhost", port), handler)
    except OSError as e:
        print(f"Could not serve on port {port} ({e.strerror}); try --port with another number.")
        return 1
    with server:
        print(f"\nPlay the web version at http://localhost:{port}  (Ctrl+C to stop)")
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("platforms", nargs="*", metavar="platform",
                        help=f"{', '.join(PLATFORMS)} (default: all)")
    parser.add_argument("--serve", action="store_true",
                        help="serve the web build on localhost afterwards")
    parser.add_argument("--port", type=int, default=8000)
    args = parser.parse_args()
    sys.stdout.reconfigure(line_buffering=True)  # show progress promptly when piped (CI logs)
    platforms = args.platforms or list(PLATFORMS)
    unknown = set(platforms) - set(PLATFORMS)
    if unknown:
        parser.error(f"unknown platform {', '.join(sorted(unknown))}; pick from {', '.join(PLATFORMS)}")
    if args.serve and "web" not in platforms:
        platforms.append("web")

    godot = find_godot()
    if not godot:
        print("Godot not found. Install Godot 4 or set the GODOT environment variable.")
        return 2
    ensure_templates(godot, platforms)

    # game/export/ sits inside the project: keep Godot from importing the builds as game assets
    EXPORT_DIR.mkdir(exist_ok=True)
    (EXPORT_DIR / ".gdignore").touch()
    # A fresh checkout has no .godot/ import cache yet, and exports need it
    code, log = run_godot(godot, "--import")
    if code != 0:
        print(f"Importing the project's assets failed:\n{log}")
        return 1

    failed = False
    for platform in platforms:
        print(f"Exporting {platform}...")
        zip_path = export(godot, platform)
        if zip_path:
            print(f"  {zip_path.relative_to(ROOT)} ({zip_path.stat().st_size / 1e6:.1f} MB)")
        failed |= zip_path is None

    if failed:
        return 1
    return serve(args.port) if args.serve else 0


if __name__ == "__main__":
    sys.exit(main())
