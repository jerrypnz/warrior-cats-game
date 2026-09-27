#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["Pillow", "numpy"]
# ///
"""
Art Processing Tool for Kids Vibe Code Games

Takes a scanned or photographed drawing and:
1. Works out what the paper looks like (including shadows and uneven lighting)
   and makes it transparent
2. Fills in closed outlines so characters aren't see-through
3. Separates individual drawings on the page into their own sprites
4. Saves transparent PNGs to game/assets/sprites/ plus a preview sheet in .previews/

Usage:
    python3 tools/process_art.py my-drawings/dragon.jpg
    python3 tools/process_art.py my-drawings/dragon.jpg --name dragon
    python3 tools/process_art.py my-drawings/page.jpg --whole        # keep as one sprite
    python3 tools/process_art.py my-drawings/faint.jpg --sensitivity 1.5

Requirements:
    pip install Pillow numpy      (or run with: uv run tools/process_art.py ...)
"""

import argparse
import sys
from collections import deque
from pathlib import Path

try:
    import numpy as np
    from PIL import Image, ImageFilter, ImageOps
except ImportError:
    print("Missing libraries. Install them with: pip install Pillow numpy")
    sys.exit(1)


ROOT = Path(__file__).resolve().parent.parent
SPRITES_DIR = ROOT / "game" / "assets" / "sprites"
PREVIEW_DIR = ROOT / ".previews"

WORK_SIZE = 1600  # long side used for processing; sprites are much smaller anyway
FIT_SIZE = 128  # long side used to fit the paper lighting model
LABEL_SIZE = 400  # long side used to find separate objects


def load_image(path):
    img = Image.open(path)
    img = ImageOps.exif_transpose(img)  # phone photos are often rotated
    img = img.convert("RGB")
    scale = WORK_SIZE / max(img.size)
    if scale < 1:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.Resampling.LANCZOS)
    return img


def _design_matrix(h, w):
    """Cubic surface terms over a normalized [-1, 1] grid."""
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    x = x / max(w - 1, 1) * 2 - 1
    y = y / max(h - 1, 1) * 2 - 1
    return [np.ones_like(x), x, y, x * x, x * y, y * y, x * x * x, x * x * y, x * y * y, y * y * y]


def estimate_paper(img):
    """
    Model the paper colour at every pixel as a smooth cubic surface per channel.

    Fits to the brightest, least colourful pixels and iteratively throws out anything
    darker than the fit (ink is always darker than paper), so shadows and warm lamp
    light are absorbed into the model instead of being mistaken for drawing.
    Returns (paper HxWx3 in 0..1, boolean paper mask at fit resolution).
    """
    scale = FIT_SIZE / max(img.size)
    small = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.Resampling.BOX)
    s = np.asarray(small, dtype=np.float32) / 255
    h, w, _ = s.shape
    terms = _design_matrix(h, w)
    design = np.stack([t.ravel() for t in terms], axis=1)
    lum = s.mean(axis=2).ravel()
    sat = (s.max(axis=2) - s.min(axis=2)).ravel()

    # Paper is the bright, dull stuff. Seeding with only those pixels keeps a table or
    # carpet around the page from dragging the fit down.
    mask = (sat < 0.25) & (lum > 0.7 * np.percentile(lum, 95))
    if mask.sum() < design.shape[1] * 4:
        mask = np.ones_like(mask)
    for _ in range(10):
        coef, *_ = np.linalg.lstsq(design[mask], lum[mask], rcond=None)
        resid = lum - design @ coef
        r = resid[mask]
        sigma = max(1.4826 * np.median(np.abs(r - np.median(r))), 0.01)
        new_mask = (resid > -max(2.5 * sigma, 0.04)) & (sat < 0.25)
        if new_mask.sum() < design.shape[1] * 4 or np.array_equal(new_mask, mask):
            break
        mask = new_mask

    full_terms = _design_matrix(img.height, img.width)
    paper = np.empty((img.height, img.width, 3), dtype=np.float32)
    for c in range(3):
        coef, *_ = np.linalg.lstsq(design[mask], s[..., c].ravel()[mask], rcond=None)
        paper[..., c] = sum(k * t for k, t in zip(coef, full_terms))
    return np.clip(paper, 0.05, 1.0), mask.reshape(h, w)


def remove_background(img, sensitivity=1.0):
    """
    Return (rgb, alpha) float arrays. Paper becomes alpha 0, ink alpha 1, with a soft ramp
    between. Colours are normalized so the paper reads as pure white, and edge pixels are
    un-mixed from the paper so sprites don't get a white halo.
    """
    arr = np.asarray(img, dtype=np.float32) / 255
    paper, fit_mask = estimate_paper(img)
    norm = np.clip(arr / paper, 0, 1)
    ink = (1 - norm).max(axis=2)  # how much darker than paper, in the strongest channel

    paper_px = _resize_mask(fit_mask, img.height, img.width)
    d = ink[paper_px] if paper_px.any() else ink.ravel()
    noise = np.median(d) + 5 * 1.4826 * np.median(np.abs(d - np.median(d)))
    lo = float(np.clip(noise, 0.05, 0.25)) / sensitivity
    hi = lo + 0.1
    alpha = np.clip((ink - lo) / (hi - lo), 0, 1)

    # Median filter knocks out single-pixel specks of paper texture and JPEG noise
    alpha_img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.MedianFilter(3))
    alpha = np.asarray(alpha_img, dtype=np.float32) / 255

    safe = np.maximum(alpha, 1e-3)[..., None]
    rgb = np.where(alpha[..., None] > 0.02, np.clip((norm - (1 - alpha[..., None])) / safe, 0, 1), 1.0)
    return rgb, alpha, norm


def _resize_mask(mask, h, w):
    return np.asarray(Image.fromarray(mask.astype(np.uint8) * 255).resize((w, h), Image.Resampling.NEAREST)) > 127


def _pool(mask, factor, mode):
    """Downsample a boolean mask by an integer factor using any/all pooling."""
    h, w = mask.shape
    ph, pw = -h % factor, -w % factor
    padded = np.pad(mask, ((0, ph), (0, pw)), constant_values=(mode == "all"))
    blocks = padded.reshape(padded.shape[0] // factor, factor, padded.shape[1] // factor, factor)
    return blocks.any(axis=(1, 3)) if mode == "any" else blocks.all(axis=(1, 3))


def _upsample(mask, factor, h, w):
    return np.repeat(np.repeat(mask, factor, axis=0), factor, axis=1)[:h, :w]


def _dilate(mask, steps):
    out = mask.copy()
    for _ in range(steps):
        grown = out.copy()
        grown[1:, :] |= out[:-1, :]
        grown[:-1, :] |= out[1:, :]
        grown[:, 1:] |= out[:, :-1]
        grown[:, :-1] |= out[:, 1:]
        out = grown
    return out


def label(mask):
    """4-connected component labelling. Returns (labels, count); background is 0."""
    h, w = mask.shape
    flat = mask.ravel()
    labels = np.zeros(h * w, dtype=np.int32)
    count = 0
    for start in np.flatnonzero(flat):
        if labels[start]:
            continue
        count += 1
        labels[start] = count
        queue = deque([start])
        while queue:
            i = queue.popleft()
            y, x = divmod(i, w)
            for j, ok in ((i - w, y > 0), (i + w, y < h - 1), (i - 1, x > 0), (i + 1, x < w - 1)):
                if ok and flat[j] and not labels[j]:
                    labels[j] = count
                    queue.append(j)
    return labels.reshape(h, w), count


def _touches_border(component):
    return component[0].any() or component[-1].any() or component[:, 0].any() or component[:, -1].any()


def _enclosed(open_mask):
    """Cells of open_mask that can't reach the edge of the grid without crossing a line."""
    labels, _ = label(open_mask)
    edge_labels = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    return open_mask & ~np.isin(labels, edge_labels)


def fill_closed_shapes(rgb, alpha, norm):
    """
    Make paper that is completely enclosed by a drawing opaque (e.g. the inside of an
    outlined character), so the game background doesn't show through it. Run this on one
    object at a time: a table around the page would otherwise "enclose" the whole page.
    """
    h, w = alpha.shape
    factor = 2
    # A half-res cell counts as open paper if ANY pixel in it is see-through, so we only
    # ever under-fill (a gap in a thin line leaks) and never fill paper outside the drawing.
    enclosed = _enclosed(_pool(alpha < 0.5, factor, "any"))
    enclosed = _upsample(enclosed, factor, h, w) & (alpha < 1)
    alpha = np.where(enclosed, 1.0, alpha)
    rgb = np.where(enclosed[..., None], norm, rgb)
    return rgb, alpha


def find_objects(alpha, keep_edges=False):
    """
    Group the drawing into separate objects. Strokes that are close together are joined
    (so a stick figure's arms stay attached), anything inside an outline belongs to it
    (eyes inside a face), tiny specks are dropped, and by default anything touching the
    photo's edge (the table, a finger, the paper's edge) is ignored.
    Returns (list of full-res masks in reading order, number of edge objects ignored).
    """
    h, w = alpha.shape
    factor = max(1, round(max(h, w) / LABEL_SIZE))
    ink = _pool(alpha >= 0.5, factor, "any")
    min_area = ink.size * 0.0005
    gap = max(2, round(max(ink.shape) * 0.015))
    labels, count = label(_dilate(ink, gap))

    # Drop edge things first: a table around the page would otherwise enclose everything
    kept = np.zeros_like(ink)
    ignored_edges = 0
    for k in range(1, count + 1):
        region = labels == k
        if not keep_edges and _touches_border(region):
            ignored_edges += int((ink & region).sum() >= min_area)
        else:
            kept |= region
    kept |= _enclosed(~kept)

    labels, count = label(kept)
    found = []
    for k in range(1, count + 1):
        region = labels == k
        if (ink & region).sum() >= min_area:
            ys, xs = np.nonzero(region)
            found.append(((ys.mean(), xs.mean()), _upsample(region, factor, h, w)))

    # Reading order: bands of rows, then left to right
    band = ink.shape[0] / 3
    found.sort(key=lambda item: (int(item[0][0] // band), item[0][1]))
    return [m for _, m in found], ignored_edges


def to_sprite(rgb, alpha, max_size, padding=8):
    rgba = np.dstack([rgb, alpha])
    img = Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA")
    ys, xs = np.nonzero(alpha > 8 / 255)
    if len(xs):
        img = img.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    scale = max_size / max(img.size)
    if scale < 1:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.Resampling.LANCZOS)
    padded = Image.new("RGBA", (img.width + padding * 2, img.height + padding * 2), (0, 0, 0, 0))
    padded.paste(img, (padding, padding))
    return padded


def make_preview(sprites, labels):
    """Lay sprites out on a checkerboard so it's easy to see what is transparent."""
    gap = 16
    width = sum(s.width for s in sprites) + gap * (len(sprites) + 1)
    height = max(s.height for s in sprites) + gap * 2 + 24
    sheet = Image.new("RGBA", (width, height), (255, 255, 255, 255))
    tile = 12
    checker = Image.new("RGBA", (width, height))
    for y in range(0, height, tile):
        for x in range(0, width, tile):
            shade = 205 if (x // tile + y // tile) % 2 else 235
            checker.paste((shade, shade, shade, 255), (x, y, x + tile, y + tile))
    sheet.alpha_composite(checker)
    from PIL import ImageDraw

    draw = ImageDraw.Draw(sheet)
    x = gap
    for sprite, text in zip(sprites, labels):
        sheet.alpha_composite(sprite, (x, gap))
        draw.text((x, height - 20), text, fill=(0, 0, 0, 255))
        x += sprite.width + gap
    return sheet


def process_image(input_path, name=None, whole=False, max_size=256, sensitivity=1.0,
                  keep_edges=False, hollow=False):
    input_path = Path(input_path)
    if not input_path.exists():
        print(f"File not found: {input_path}")
        sys.exit(1)

    name = name or input_path.stem.lower().replace(" ", "_").replace("-", "_")
    print(f"Processing: {input_path.name}")

    img = load_image(input_path)
    rgb, alpha, norm = remove_background(img, sensitivity)
    objects, ignored_edges = find_objects(alpha, keep_edges)

    if not objects:
        print("  No drawing found! Try a darker marker, better lighting, or --sensitivity 1.5")
        if ignored_edges:
            print(f"  ({ignored_edges} thing(s) touching the photo's edge were ignored; try --keep-edges)")
        sys.exit(2)

    if whole:
        objects = [np.logical_or.reduce(objects)]
    print(f"  Found {len(objects)} drawing(s)")
    if ignored_edges:
        print(f"  Ignored {ignored_edges} thing(s) touching the edge of the photo, like the table, a shadow or fingers (use --keep-edges to keep them)")

    SPRITES_DIR.mkdir(parents=True, exist_ok=True)
    sprites, saved = [], []
    for i, region in enumerate(objects):
        ys, xs = np.nonzero(region)
        crop = (slice(ys.min(), ys.max() + 1), slice(xs.min(), xs.max() + 1))
        obj_rgb, obj_alpha = rgb[crop], np.where(region[crop], alpha[crop], 0)
        if not hollow:
            obj_rgb, obj_alpha = fill_closed_shapes(obj_rgb, obj_alpha, norm[crop])
        sprite = to_sprite(obj_rgb, obj_alpha, max_size)
        filename = f"{name}.png" if len(objects) == 1 else f"{name}_{i + 1}.png"
        out = SPRITES_DIR / filename
        existed = out.exists()
        sprite.save(out, "PNG")
        sprites.append(sprite)
        saved.append(out)
        print(f"  {'Replaced' if existed else 'Saved'}: {out.relative_to(ROOT)} ({sprite.width}x{sprite.height})")

    PREVIEW_DIR.mkdir(exist_ok=True)
    preview = PREVIEW_DIR / f"{name}_preview.png"
    make_preview(sprites, [p.stem for p in saved]).save(preview)
    print(f"  Preview (check the cut-outs look right): {preview.relative_to(ROOT)}")
    return saved


def main():
    parser = argparse.ArgumentParser(description="Turn a photo of a kid's drawing into game sprites")
    parser.add_argument("image", help="Path to the scanned/photographed drawing")
    parser.add_argument("--name", help="Name for the sprite (default: the file name)")
    parser.add_argument("--whole", action="store_true",
                        help="Keep everything on the page as ONE sprite instead of separating drawings")
    parser.add_argument("--max-size", type=int, default=256, help="Maximum sprite size in pixels (default: 256)")
    parser.add_argument("--sensitivity", type=float, default=1.0,
                        help="Higher keeps fainter marks (e.g. 1.5 for pencil); lower removes more (e.g. 0.7 for "
                             "grubby paper). Default: 1.0")
    parser.add_argument("--keep-edges", action="store_true",
                        help="Keep drawings that touch the edge of the photo (normally ignored as table/fingers)")
    parser.add_argument("--hollow", action="store_true",
                        help="Leave the inside of closed outlines see-through instead of filling it with paper white")
    args = parser.parse_args()
    process_image(args.image, name=args.name, whole=args.whole, max_size=args.max_size,
                  sensitivity=args.sensitivity, keep_edges=args.keep_edges, hollow=args.hollow)


if __name__ == "__main__":
    main()
