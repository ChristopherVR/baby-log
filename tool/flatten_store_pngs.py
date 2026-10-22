"""Play wants the feature graphic and screenshots as opaque 24-bit PNGs.
flutter_test can only write RGBA, so drop the (fully opaque) alpha channel.

    python tool/flatten_store_pngs.py
"""
from pathlib import Path

from PIL import Image

store = Path(__file__).resolve().parent.parent / "store"
for path in [store / "feature-graphic.png", *sorted((store / "screenshots").glob("*.png"))]:
    image = Image.open(path)
    if image.mode != "RGB":
        assert image.mode != "RGBA" or image.getchannel("A").getextrema() == (255, 255), path
        image.convert("RGB").save(path, optimize=True)
    print(path.name, Image.open(path).size, Image.open(path).mode)
