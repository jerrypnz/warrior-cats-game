"""Tests for process_art.py. Run with: python3 -m unittest discover tools"""

import tempfile
import unittest
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import process_art


def make_photo(path, table=True):
    """A fake phone photo: warm off-white paper with a lighting falloff, sitting on a table."""
    w, h = 2000, 1500
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    light = 0.8 + 0.2 * (1 - x / w) * (1 - 0.5 * y / h)
    img = np.stack([236 * light, 228 * light, 212 * light], axis=-1)
    if table:
        border = np.ones((h, w), bool)
        border[120:-120, 150:-150] = False
        img[border] = (110, 78, 50)
    img += np.random.default_rng(0).normal(0, 3, img.shape)
    photo = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(photo)
    d.ellipse((350, 350, 750, 750), outline=(25, 25, 30), width=8)  # outlined face...
    d.ellipse((460, 480, 500, 520), fill=(25, 25, 30))  # ...with eyes
    d.ellipse((600, 480, 640, 520), fill=(25, 25, 30))
    d.rectangle((1100, 400, 1500, 900), fill=(200, 40, 40), outline=(20, 20, 20), width=8)
    d.ellipse((800, 1000, 1000, 1200), fill=(250, 225, 110))  # pale yellow crayon
    photo.save(path, quality=90)


class ProcessArtTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        process_art.SPRITES_DIR = self.tmp / "sprites"
        process_art.PREVIEW_DIR = self.tmp / "previews"
        process_art.ROOT = self.tmp
        self.photo = self.tmp / "page.jpg"

    def sprites(self, saved):
        return [np.asarray(Image.open(p)) for p in saved]

    def test_separates_drawings_and_ignores_table(self):
        make_photo(self.photo)
        saved = process_art.process_image(self.photo)
        self.assertEqual([p.name for p in saved], ["page_1.png", "page_2.png", "page_3.png"])
        face, box, sun = self.sprites(saved)
        for sprite in (face, box, sun):
            self.assertEqual(sprite[0, 0, 3], 0, "paper around the drawing should be transparent")
        cy, cx = face.shape[0] // 2, face.shape[1] // 2
        self.assertEqual(face[cy, cx, 3], 255, "inside of a closed outline should be filled")
        self.assertGreater(face[cy, cx, :3].min(), 230, "filled paper should read as white")
        self.assertGreater(box[box.shape[0] // 2, box.shape[1] // 2, 0], 180, "red stays red")
        self.assertTrue((self.tmp / "previews" / "page_preview.png").exists())

    def test_hollow_leaves_outlines_see_through(self):
        make_photo(self.photo)
        face = self.sprites(process_art.process_image(self.photo, hollow=True))[0]
        self.assertEqual(face[face.shape[0] // 2, face.shape[1] // 2, 3], 0)

    def test_whole_keeps_one_sprite(self):
        make_photo(self.photo, table=False)
        saved = process_art.process_image(self.photo, whole=True, max_size=128)
        self.assertEqual([p.name for p in saved], ["page.png"])
        self.assertLessEqual(max(Image.open(saved[0]).size), 128 + 16)

    def test_blank_page_reports_nothing_found(self):
        Image.new("RGB", (800, 600), (230, 225, 210)).save(self.photo)
        with self.assertRaises(SystemExit) as exit_:
            process_art.process_image(self.photo)
        self.assertEqual(exit_.exception.code, 2)


if __name__ == "__main__":
    unittest.main()
