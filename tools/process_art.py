#!/usr/bin/env python3
"""
Art Processing Tool for Kids Vibe Code Games

Takes a scanned/photographed drawing and:
1. Removes the white/paper background (makes it transparent)
2. Separates individual objects (if spaced apart)
3. Saves processed sprites as PNGs to game/assets/sprites/

Usage:
    python3 tools/process_art.py my-drawings/dragon.jpg
    python3 tools/process_art.py my-drawings/dragon.jpg --name dragon
    python3 tools/process_art.py my-drawings/characters.jpg --separate

Requirements:
    pip install Pillow
"""

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageFilter, ImageOps
except ImportError:
    print("Pillow is not installed. Install it with: pip install Pillow")
    sys.exit(1)


SPRITES_DIR = Path(__file__).parent.parent / "game" / "assets" / "sprites"


def remove_background(img, threshold=220):
    """Remove white/light background and make it transparent."""
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size

    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            # If the pixel is close to white, make it transparent
            if r > threshold and g > threshold and b > threshold:
                pixels[x, y] = (r, g, b, 0)

    return img


def clean_up(img):
    """Remove small noise artifacts from the processed image."""
    # Split alpha channel
    r, g, b, a = img.split()

    # Use median filter on alpha to remove small specks
    a = a.filter(ImageFilter.MedianFilter(size=3))

    # Recombine
    img = Image.merge("RGBA", (r, g, b, a))
    return img


def auto_crop(img):
    """Crop to the bounding box of non-transparent content."""
    bbox = img.getbbox()
    if bbox:
        return img.crop(bbox)
    return img


def add_padding(img, padding=8):
    """Add transparent padding around the sprite."""
    new_size = (img.width + padding * 2, img.height + padding * 2)
    padded = Image.new("RGBA", new_size, (0, 0, 0, 0))
    padded.paste(img, (padding, padding))
    return padded


def find_objects(img, min_size=50):
    """
    Find separate objects in the image using connected component analysis.
    Returns a list of bounding boxes for each distinct object.
    """
    # Create a binary mask from the alpha channel
    alpha = img.split()[3]
    width, height = alpha.size
    pixels = alpha.load()

    visited = [[False] * width for _ in range(height)]
    objects = []

    def flood_fill(start_x, start_y):
        """BFS flood fill to find connected region."""
        stack = [(start_x, start_y)]
        min_x, min_y = start_x, start_y
        max_x, max_y = start_x, start_y
        pixel_count = 0

        while stack:
            x, y = stack.pop()
            if x < 0 or x >= width or y < 0 or y >= height:
                continue
            if visited[y][x]:
                continue
            if pixels[x, y] < 30:  # Nearly transparent = background
                continue

            visited[y][x] = True
            pixel_count += 1
            min_x = min(min_x, x)
            min_y = min(min_y, y)
            max_x = max(max_x, x)
            max_y = max(max_y, y)

            # Check 4-connected neighbors
            stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

        return (min_x, min_y, max_x + 1, max_y + 1), pixel_count

    # Scan for unvisited non-transparent pixels
    for y in range(height):
        for x in range(width):
            if not visited[y][x] and pixels[x, y] >= 30:
                bbox, count = flood_fill(x, y)
                # Only keep objects larger than min_size pixels
                obj_w = bbox[2] - bbox[0]
                obj_h = bbox[3] - bbox[1]
                if obj_w >= min_size and obj_h >= min_size and count >= min_size * 2:
                    objects.append(bbox)

    return objects


def separate_objects(img, min_size=50):
    """Extract individual objects from the image as separate images."""
    bboxes = find_objects(img, min_size)

    if not bboxes:
        return [img]

    # Merge overlapping or very close bounding boxes
    merged = merge_close_boxes(bboxes, margin=20)

    sprites = []
    for bbox in merged:
        sprite = img.crop(bbox)
        sprite = auto_crop(sprite)
        if sprite.width >= min_size and sprite.height >= min_size:
            sprites.append(sprite)

    return sprites if sprites else [img]


def merge_close_boxes(boxes, margin=20):
    """Merge bounding boxes that are close to each other."""
    if not boxes:
        return boxes

    merged = list(boxes)
    changed = True

    while changed:
        changed = False
        new_merged = []
        used = [False] * len(merged)

        for i in range(len(merged)):
            if used[i]:
                continue
            current = merged[i]
            for j in range(i + 1, len(merged)):
                if used[j]:
                    continue
                other = merged[j]
                # Check if boxes overlap or are close
                if (current[0] - margin <= other[2] and
                    current[2] + margin >= other[0] and
                    current[1] - margin <= other[3] and
                    current[3] + margin >= other[1]):
                    # Merge
                    current = (
                        min(current[0], other[0]),
                        min(current[1], other[1]),
                        max(current[2], other[2]),
                        max(current[3], other[3]),
                    )
                    used[j] = True
                    changed = True
            new_merged.append(current)
            used[i] = True

        merged = new_merged

    return merged


def scale_sprite(img, max_size=256):
    """Scale sprite to fit within max_size while preserving aspect ratio."""
    if img.width <= max_size and img.height <= max_size:
        return img

    ratio = min(max_size / img.width, max_size / img.height)
    new_size = (int(img.width * ratio), int(img.height * ratio))
    return img.resize(new_size, Image.LANCZOS)


def process_image(input_path, name=None, separate=False, max_size=256, threshold=220):
    """Main processing pipeline."""
    input_path = Path(input_path)

    if not input_path.exists():
        print(f"File not found: {input_path}")
        sys.exit(1)

    # Default name from filename
    if name is None:
        name = input_path.stem.lower().replace(" ", "_")

    # Ensure output directory exists
    SPRITES_DIR.mkdir(parents=True, exist_ok=True)

    print(f"Processing: {input_path.name}")

    # Load and process
    img = Image.open(input_path)

    # Auto-orient based on EXIF (phone photos are often rotated)
    img = ImageOps.exif_transpose(img)

    print("  Removing background...")
    img = remove_background(img, threshold=threshold)

    print("  Cleaning up artifacts...")
    img = clean_up(img)

    if separate:
        print("  Separating objects...")
        sprites = separate_objects(img)
        print(f"  Found {len(sprites)} object(s)")

        saved_files = []
        for i, sprite in enumerate(sprites):
            sprite = auto_crop(sprite)
            sprite = add_padding(sprite)
            sprite = scale_sprite(sprite, max_size)

            if len(sprites) == 1:
                filename = f"{name}.png"
            else:
                filename = f"{name}_{i + 1}.png"

            output_path = SPRITES_DIR / filename
            sprite.save(output_path, "PNG")
            saved_files.append(output_path)
            print(f"  Saved: {output_path}")
    else:
        img = auto_crop(img)
        img = add_padding(img)
        img = scale_sprite(img, max_size)

        output_path = SPRITES_DIR / f"{name}.png"
        img.save(output_path, "PNG")
        saved_files = [output_path]
        print(f"  Saved: {output_path}")

    print(f"\nDone! {len(saved_files)} sprite(s) ready in game/assets/sprites/")
    return saved_files


def main():
    parser = argparse.ArgumentParser(
        description="Process kid drawings into game sprites"
    )
    parser.add_argument("image", help="Path to the scanned/photographed drawing")
    parser.add_argument("--name", help="Name for the sprite (default: filename)")
    parser.add_argument(
        "--separate",
        action="store_true",
        help="Try to separate multiple objects in the drawing",
    )
    parser.add_argument(
        "--max-size",
        type=int,
        default=256,
        help="Maximum sprite size in pixels (default: 256)",
    )
    parser.add_argument(
        "--threshold",
        type=int,
        default=220,
        help="Background brightness threshold 0-255 (default: 220, lower = more aggressive)",
    )

    args = parser.parse_args()
    process_image(
        args.image,
        name=args.name,
        separate=args.separate,
        max_size=args.max_size,
        threshold=args.threshold,
    )


if __name__ == "__main__":
    main()
