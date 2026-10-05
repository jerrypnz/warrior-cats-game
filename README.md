# Warrior Cats: Path of the Apprentice

A fan game based on the *Warriors* books by Erin Hunter, made by two kids who love them,
by describing their ideas to [Claude Code](https://claude.com/claude-code).

Design your own cat, leave your Twoleg garden to join ThunderClan, and live the first book's
story as the main character: hunting, border patrols, play-fights and your warrior ceremony,
or train as a medicine cat and visit the Moonstone. Then keep living in the Clan, or play
**ThunderClan Together** with a friend on the same keyboard.

**Controls:** arrow keys to walk and choose, SPACE to jump, pounce, talk and OK, ESC for the
menu. Player 2 uses WASD and E.

## Play it

- **In your browser:** the web version is published on this repository's GitHub Pages site.
  Saves are kept in your browser.
- **Download:** Windows, macOS and Linux versions are on the
  [Releases](../../releases/latest) page. Unzip and run, nothing else to install.
  - macOS: the app isn't notarized by Apple, so the first time, right-click it → Open
    (or System Settings → Privacy & Security → Open Anyway).
  - Windows: if SmartScreen warns about an unknown publisher, click More info → Run anyway.

*This is an unofficial fan project, not affiliated with Erin Hunter or the Warriors
publishers.*

## Working on the game

You need [Godot 4.6](https://godotengine.org/download) (the `godot` command on your PATH, or
set `GODOT` to it), Python 3.9+ and Claude Code. Open `game/project.godot` in Godot and press
Play to run it.

**Kid mode:** `./kids-vibe-code` (on Windows, `kids-vibe-code.cmd`) opens the game in Godot and
starts Claude as a friendly game-making buddy for kids aged 7–12. It:

- talks in simple words, makes all the technical decisions, and asks only fun questions
- keeps everything kid-friendly and stays in character
- tests the game after every change, writes what's new in `history.md`, and makes a git save
  point so "undo that!" always works
- runs in Claude's safe mode with web access blocked, so a grown-up's own Claude setup on the
  computer (personal instructions, plugins, tools) isn't part of the kid's session
- edits files without asking, but anything beyond the game's own tools and git save points
  still needs approval, so stay nearby

The persona and permissions are in `tools/kids/`.

**Grown-up mode:** just run `claude` in this folder. `CLAUDE.md` tells it how the game works
and how to check changes.

**Tools:**

| Command | What it does |
|---|---|
| `python3 tools/check_game.py` | Runs the game for a few seconds and reports any errors (`--screenshot` to see it) |
| `python3 tools/export_game.py` | Builds the packages below (`web --serve` to play the web build locally) |
| `python3 tools/make_sounds.py` | Regenerates the sound effects in `game/assets/sounds/` |

## Packaging and publishing

`tools/export_game.py` builds a self-contained zip per platform into `dist/`. The first run
downloads the Godot export templates it needs (only those files, not the whole 1.2 GB set).

| Package | What's inside |
|---|---|
| `warrior-cats-web.zip` | HTML5 version for any static web host (itch.io, GitHub Pages) |
| `warrior-cats-windows.zip` | A single 64-bit `.exe` |
| `warrior-cats-macos.zip` | `Warrior Cats.app` for Intel and Apple Silicon Macs (ad-hoc signed) |
| `warrior-cats-linux.zip` | A single x86_64 program |

The web build has to be served over http; opening `index.html` from disk won't work. It's
exported without threads, so no special server headers are needed.

GitHub Actions use the same tool:

- `.github/workflows/pages.yml` checks the game runs, then publishes the web version to GitHub
  Pages on every push. One-time setup: Settings → Pages → Source = **GitHub Actions**.
- `.github/workflows/release.yml` builds every package when a tag like `v1.0` is pushed and
  attaches them to a GitHub Release. The file names never change, so
  `releases/latest/download/warrior-cats-windows.zip` always gets the newest version.

Both pin `GODOT_VERSION`; bump it when you update Godot.
