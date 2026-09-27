#!/usr/bin/env python3
"""
Generate the starter sound-effect library (retro, chiptune-style) with no downloads.

Writes game/assets/sounds/<name>.wav for every sound in SOUNDS. Existing files are left
alone unless --force is given, so hand-picked replacements are never overwritten.

Usage:
    python3 tools/make_sounds.py            # create any missing sounds
    python3 tools/make_sounds.py --force    # regenerate all of them
"""

import argparse
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
SOUNDS_DIR = Path(__file__).resolve().parent.parent / "game" / "assets" / "sounds"


def tone(freq_start, freq_end, seconds, wave_type="square", volume=1.0, vibrato=0.0, attack=0.005,
         release=0.05, duty=0.5, curve=1.0):
    """A single note whose pitch slides from freq_start to freq_end."""
    n = int(RATE * seconds)
    out, phase = [], 0.0
    for i in range(n):
        t = i / n
        freq = freq_start + (freq_end - freq_start) * (t ** curve)
        if vibrato:
            freq *= 1 + 0.03 * math.sin(2 * math.pi * vibrato * i / RATE)
        phase = (phase + freq / RATE) % 1.0
        if wave_type == "square":
            s = 1.0 if phase < duty else -1.0
        elif wave_type == "triangle":
            s = 4 * abs(phase - 0.5) - 1
        elif wave_type == "noise":
            s = random.uniform(-1, 1)
        else:
            s = math.sin(2 * math.pi * phase)
        out.append(s * volume * envelope(i, n, attack, release))
    return out


def envelope(i, n, attack, release):
    """Fade in/out so notes never click, with a gentle decay in between."""
    t = i / RATE
    end = (n - i) / RATE
    level = min(1.0, t / attack) if attack else 1.0
    level *= min(1.0, end / release) if release else 1.0
    return level * (1 - 0.35 * i / n)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(*tracks):
    length = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(length)]


def notes(*specs, gap=0.0, **kwargs):
    """Play (freq, seconds) notes one after another."""
    out = []
    for freq, seconds in specs:
        out += tone(freq, freq, seconds, **kwargs) + silence(gap)
    return out


def jump():
    return tone(260, 720, 0.16, duty=0.25, volume=0.6, curve=0.7)


def land():
    return mix(tone(140, 60, 0.09, "triangle", volume=0.9), tone(0, 0, 0.05, "noise", volume=0.25, release=0.04))


def collect():
    return notes((988, 0.06), (1319, 0.22), duty=0.25, volume=0.5, release=0.12)


def hurt():
    return tone(520, 180, 0.3, duty=0.5, volume=0.5, vibrato=18, release=0.1)


def enemy_bonk():
    return mix(tone(700, 160, 0.14, "triangle", volume=0.9, curve=0.5), tone(0, 0, 0.04, "noise", volume=0.3))


def win():
    melody = notes((523, 0.1), (659, 0.1), (784, 0.1), (1047, 0.12), duty=0.25, volume=0.45, gap=0.015)
    melody += tone(784, 784, 0.1, duty=0.25, volume=0.45) + tone(1047, 1047, 0.45, duty=0.25, volume=0.45,
                                                                 vibrato=6, release=0.25)
    bass = notes((262, 0.46), (392, 0.2), (523, 0.45), wave_type="triangle", volume=0.35)
    return mix(melody, bass)


def lose():
    # A silly "wah wah wah waaah", not a sad one
    return notes((392, 0.2), (370, 0.2), (349, 0.2), wave_type="triangle", volume=0.7, gap=0.05) + tone(
        330, 300, 0.6, "triangle", volume=0.7, vibrato=7, release=0.3)


def click():
    return tone(1500, 1100, 0.035, "sine", volume=0.6, release=0.02)


def select():
    return notes((880, 0.05), (1320, 0.09), wave_type="sine", volume=0.5, release=0.04)


def powerup():
    out = []
    for step in range(8):
        base = 330 * 2 ** (step / 8)
        out += tone(base, base * 1.5, 0.05, duty=0.25, volume=0.45, release=0.01)
    return out + tone(660, 990, 0.2, duty=0.25, volume=0.45, vibrato=10, release=0.15)


SOUNDS = {
    "jump": jump, "land": land, "collect": collect, "hurt": hurt, "enemy_bonk": enemy_bonk,
    "win": win, "lose": lose, "click": click, "select": select, "powerup": powerup,
}


def save(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.7 / peak * 32767  # normalize to about -3 dB
    with wave.open(str(path), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s * scale)) for s in samples))


def main():
    parser = argparse.ArgumentParser(description="Generate the starter sound-effect library")
    parser.add_argument("--force", action="store_true", help="Overwrite sounds that already exist")
    args = parser.parse_args()

    random.seed(7)  # same noise every time, so regenerating doesn't churn git
    SOUNDS_DIR.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        path = SOUNDS_DIR / f"{name}.wav"
        if path.exists() and not args.force:
            print(f"  kept     {name}.wav")
            continue
        save(path, make())
        print(f"  created  {name}.wav")


if __name__ == "__main__":
    main()
