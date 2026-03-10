# Setup Guide (For Parents & Teachers)

This guide helps you set up the environment so kids can start creating games!

## What You Need

1. **Godot 4.3+** (free, open-source game engine)
   - Download from https://godotengine.org/download
   - Install for your platform (macOS, Windows, or Linux)
   - No account required

2. **Python 3.8+** (for processing kid drawings)
   - macOS: Usually pre-installed. Check with `python3 --version`
   - Windows: Download from https://python.org/downloads

3. **Pillow** (Python image processing library)
   ```
   pip install Pillow
   ```

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
```

You should see the usage instructions for the art processing tool.

### 3. Set Up for Drawing Import

- Have white paper and dark markers/crayons ready
- Use a phone camera or scanner to capture drawings
- Save images to the `my-drawings/` folder (JPG or PNG)

## How Kids Use This

### Option A: Use the launcher script (recommended)

Install the launcher once:
```bash
cp tools/kids-vibe-code /usr/local/bin/
chmod +x /usr/local/bin/kids-vibe-code
```

Then kids just run:
```bash
cd /path/to/kids-vibe-code-games
kids-vibe-code
```

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

## Setting Up HTML5 Export (Optional, for Sharing)

To let kids share their games in a web browser:

1. In Godot, go to Editor > Manage Export Templates
2. Click "Download and Install" to get the export templates
3. Claude will handle creating the export preset configuration

The exported game will be a set of HTML files that can be opened in any browser
or hosted on a simple web server.

## Tips for Supervising

- **Read history.md** to see what the kid has been building
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
- Try: `python3 tools/process_art.py my-drawings/file.jpg --threshold 200`
  (lower threshold = more aggressive background removal)

**"Claude said something weird"**
- Check history.md for context on what happened
- Start a new Claude conversation — it will read history.md to catch up
