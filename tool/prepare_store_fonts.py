"""Store screenshots render in the flutter_test engine, which has no system
font fallback. Nunito lacks a few symbols the app uses (for example the arrow
in the growth chart summary), which a phone draws from its system font. This
adds those glyphs (an arrow drawn here, the minus sign from Roboto) to
temporary copies of Nunito so the screenshots match what a phone shows. Output: .dart_tool/store_fonts/.

    python tool/prepare_store_fonts.py [path to material_fonts/roboto-regular.ttf]
"""
import sys
from pathlib import Path

from fontTools.pens.transformPen import TransformPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
ROBOTO = Path(
    sys.argv[1]
    if len(sys.argv) > 1
    else r"D:\Development\tools\flutter\bin\cache\artifacts\material_fonts\roboto-regular.ttf"
)
SYMBOLS = [0x2212]  # minus sign, copied from Roboto
ARROW = 0x2192  # right arrow (Roboto's Flutter subset has none): drawn below


def draw_arrow(upm):
    """A plain right arrow, as two clockwise contours on a 1000-unit em."""
    k = upm / 1000
    pen = TTGlyphPen(None)
    for contour in (
        [(90, 275), (90, 335), (560, 335), (560, 275)],
        [(500, 140), (500, 470), (740, 305)],
    ):
        pts = [(x * k, y * k) for x, y in contour]
        pen.moveTo(pts[0])
        for pt in pts[1:]:
            pen.lineTo(pt)
        pen.closePath()
    return pen.glyph(), round(820 * k)

out = ROOT / ".dart_tool" / "store_fonts"
out.mkdir(parents=True, exist_ok=True)
roboto = TTFont(ROBOTO)
rglyphs = roboto.getGlyphSet()
rcmap = roboto.getBestCmap()

for src in sorted((ROOT / "assets" / "fonts").glob("Nunito-*.ttf")):
    font = TTFont(src)
    scale = font["head"].unitsPerEm / roboto["head"].unitsPerEm
    cmap = font.getBestCmap()
    glyf, hmtx = font["glyf"], font["hmtx"]
    order = font.getGlyphOrder()
    for cp in SYMBOLS:
        if cp in cmap or cp not in rcmap:
            continue
        name = f"uni{cp:04X}_fb"
        pen = TTGlyphPen(None)
        rglyphs[rcmap[cp]].draw(TransformPen(pen, (scale, 0, 0, scale, 0, 0)))
        glyf[name] = pen.glyph()
        hmtx[name] = (round(rglyphs[rcmap[cp]].width * scale), 0)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[cp] = name
    if ARROW not in cmap:
        name = "arrowright_fb"
        glyf[name], width = draw_arrow(font["head"].unitsPerEm)
        hmtx[name] = (width, 0)
        for table in font["cmap"].tables:
            if table.isUnicode():
                table.cmap[ARROW] = name
    order = list(glyf.glyphOrder)
    font.setGlyphOrder(order)
    if "post" in font:
        font["post"].formatType = 3.0  # no glyph names needed
    font["maxp"].numGlyphs = len(order)
    font.save(out / src.name)
    print("wrote", out / src.name)
