# Setup Guide (For Parents & Teachers)

This guide helps you set up the environment so kids can start creating games!

## What You Need

1. **Godot 4.3+** (free, open-source game engine)
   - Download from https://godotengine.org/download
   - Install for your platform (macOS, Windows, or Linux)
   - No account required

2. **Python 3.9+** (for processing drawings and checking the game)
   - macOS: Usually pre-installed. Check with `python3 --version`
   - Windows: Download from https://python.org/downloads

3. **Pillow and numpy** (Python image processing libraries)
   ```
   pip install Pillow numpy
   ```

   The `godot` command must also work from a terminal so Claude can test the game.
   On macOS: `brew install --cask godot`, or set `GODOT=/Applications/Godot.app/Contents/MacOS/Godot`.

4. **Claude Code** (the AI assistant)
   - Should already be installed if you're reading this!

## First-Time Setup

### 1. Open the Project in Godot

- Launch Godot
- Click "Import" and navigate to the `game/` folder in this project
- Select `project.godot` and click "Import & Edit"
- The Godot editor will open — this is where the kid will see their game

### 2. Test That Everything Works

In a terminal, run:
```
cd /path/to/kids-vibe-code-games
python3 tools/process_art.py --help
python3 -m unittest discover tools
python3 tools/check_game.py
```

You should see the art tool's usage, the tests passing, and (until the first game exists)
a message that no main scene is set yet — that means Godot was found and works.

### 3. What Claude Is Allowed to Do Without Asking

`.claude/settings.json` sets this project up so a kid isn't faced with permission prompts
for normal game-making:

- File edits inside this folder are auto-approved
- The project's own tools (`tools/*.py`) and git save points (add/commit/revert/tag) are allowed
- Web search and web fetching are **blocked**

Anything else (installing software, other commands) still asks first — so a parent should
be nearby, at least for the first few sessions. Edit that file to tighten or loosen this.

### 4. Set Up for Drawing Import

- Have white paper and dark markers/crayons ready
- Use a phone camera or scanner to capture drawings: straight from above, in a bright
  room, without the phone's shadow on the page
- Save images to the `my-drawings/` folder (JPG or PNG). These originals are git-ignored,
  because phone photos can include GPS location and kids often write their name on the page.

## How Kids Use This

### Option A: Use the launcher script (recommended)

Install the launcher once:
```bash
mkdir -p ~/.local/bin
ln -sf "$PWD/tools/kids-vibe-code" ~/.local/bin/kids-vibe-code
```
(`~/.local/bin` must be on your `PATH`.)

Then kids run it from inside their game's project folder:
```bash
cd /path/to/their-game
kids-vibe-code
```
The launcher always uses the current folder as the project, so one install works for
every copy — give each game its own copy of this project and launch from there.

This launches Claude in a kid-friendly "game-making buddy" persona that:
- Only helps with game creation (won't do homework, web searches, etc.)
- Uses simple, encouraging language
- Makes all technical decisions automatically
- Stays in character even if asked to "act normal"

### Option B: Use regular Claude Code

If you prefer, kids can also just run `claude` in the project folder.
The `CLAUDE.md` file will guide Claude's behavior, though the persona
won't be as locked-in as with the launcher script.

### Either way, the workflow is:

1. Kid describes what they want: *"Make a game where I'm a ninja jumping on clouds!"*
2. Claude creates/updates the Godot project
3. The kid presses Play in the Godot editor to test
4. Repeat!

## Packaging the Game for Sharing (Web, Windows, macOS, Linux)

`tools/export_game.py` turns the game into packages that run without Godot, one zip
per platform in `dist/`:

| Package | What's inside |
|---|---|
| `warrior-cats-web.zip` | HTML5 version — upload to itch.io or any static web host |
| `warrior-cats-windows.zip` | A single 64-bit `.exe` |
| `warrior-cats-macos.zip` | `Warrior Cats.app`, runs on Intel and Apple Silicon Macs |
| `warrior-cats-linux.zip` | A single x86_64 program |

```
python3 tools/export_game.py              # every platform
python3 tools/export_game.py web windows  # just some
python3 tools/export_game.py web --serve  # build, then play at http://localhost:8000
```

The first run downloads the Godot export templates it needs (only those files, not the
whole 1.2 GB bundle). The unpacked builds stay in `game/export/<platform>/`.

Things players should know:
- **Web**: it has to be served over http, so double-clicking `index.html` won't work.
  The preset has threads turned off, so no special server configuration is needed.
  Saves live in the browser.
- **macOS**: the app isn't notarized by Apple, so the first launch is blocked. Right-click
  the app → Open (or System Settings → Privacy & Security → Open Anyway).
- **Windows**: SmartScreen may warn about an unknown publisher → "More info" → "Run anyway".

### Publishing on GitHub

Two workflows in `.github/workflows/` use the same tool:
- `pages.yml` checks the game runs, then publishes the web version to GitHub Pages on
  every push. One-time setup: Settings → Pages → Source = **GitHub Actions**.
- `release.yml` builds all four packages when you push a tag (`git tag v1.0 && git push
  origin v1.0`) and attaches them to a GitHub Release. Stable file names mean links like
  `https://github.com/<you>/<repo>/releases/latest/download/warrior-cats-windows.zip`
  always point at the newest version.

Both pin the Godot version (`GODOT_VERSION`); bump it when you update the Godot editor.

## Tips for Supervising

- **Read history.md** to see what the kid has been building, and `git log` for every save point
- The CLAUDE.md file contains safety rules — Claude will refuse inappropriate content
- If something breaks, just tell Claude "the game is broken, can you fix it?"
- Kids can draw multiple characters on one page — just tell them to leave space between drawings
- Phone photos work fine for drawings — no scanner needed

## Troubleshooting

**"The game won't run"**
- Make sure Godot is open with the game/ project loaded
- Click the Play button (or press F5) in Godot

**"My drawing looks weird in the game"**
- Draw with darker lines (thick markers work best)
- Make sure the photo is well-lit and not blurry
- Keep the phone's shadow off the page, and take the photo from straight above
- Look at the preview in `.previews/` to see what the tool cut out
- Try: `python3 tools/process_art.py my-drawings/file.jpg --sensitivity 1.5` for faint
  drawings, or `--sensitivity 0.7` if smudges are showing up

**"There's no sound"**
- Run `python3 tools/make_sounds.py` to (re)create the starter sounds

**"Claude said something weird"**
- Check history.md for context on what happened
- Start a new Claude conversation — it will read history.md to catch up
