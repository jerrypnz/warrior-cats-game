@echo off
rem Kids Vibe Code for Windows: opens the game in Godot and starts Claude as a friendly
rem game-making buddy. Double-click it, or run kids-vibe-code from this folder.
rem Grown-ups: just run `claude` here for a normal session. See kids-vibe-code (no .cmd)
rem for why kid mode uses safe mode and passes CLAUDE.md in itself.

cd /d "%~dp0"

where claude >nul 2>nul || (
    echo Claude Code isn't installed ^(the "claude" command wasn't found^).
    pause
    exit /b 1
)

rem Open the game in the Godot editor so the Play button is ready
if not defined GODOT for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT set "GODOT=%%G"
if defined GODOT start "" "%GODOT%" --path "%~dp0game" --editor

set "PROMPT_FILE=%TEMP%\kids-vibe-code-prompt.md"
(type CLAUDE.md & echo. & type tools\kids\persona.md) > "%PROMPT_FILE%"

claude --safe-mode --settings tools\kids\settings.json --append-system-prompt-file "%PROMPT_FILE%" "Hi! Let's work on the game."
