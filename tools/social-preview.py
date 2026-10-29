"""Make the GitHub social preview: 1280x640 pixels, in the look of Windows 3.1.

usage: python3 tools/social-preview.py [OUT.png]      (default: docs/social-preview.png)

The picture is put together from files of this repository: the logo is bitmap
1200 of source/ISHIDO.RES, the window is docs/screenshots/board.png. Text in
Arial Bold from macOS, navy with a white highlight (the game's own Text3D is
grey on grey, too faint for a thumbnail). Needs Pillow.
"""
import io, struct, sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / 'docs' / 'social-preview.png'
FONT = '/System/Library/Fonts/Supplemental/Arial Bold.ttf'
GRAY, WHITE, DARK, BLUE, BLACK = (192, 192, 192), (255, 255, 255), (128, 128, 128), (0, 0, 170), (0, 0, 0)
NAVY = (0, 0, 128)
W, H = 1280, 640


def res_bitmap(path, wanted):
    """Bitmap resource `wanted` of a Win16 .RES file, as a PIL image."""
    d = path.read_bytes()
    i = 0

    def ident(i):
        if d[i] == 0xFF:
            return struct.unpack_from('<H', d, i + 1)[0], i + 3
        j = d.index(b'\0', i)
        return d[i:j], j + 1
    while i < len(d):
        t, i = ident(i)
        n, i = ident(i)
        _, size = struct.unpack_from('<HI', d, i)
        i += 6
        if t == 2 and n == wanted:
            hdr = d[i:i + size]
            ncol = struct.unpack_from('<I', hdr, 32)[0] or 1 << struct.unpack_from('<H', hdr, 14)[0]
            bm = b'BM' + struct.pack('<IHHI', 14 + size, 0, 0, 14 + 40 + 4 * ncol) + hdr
            return Image.open(io.BytesIO(bm)).convert('RGB')
        i += size
    raise SystemExit(f'bitmap {wanted} not found')


img = Image.new('RGB', (W, H), GRAY)
dr = ImageDraw.Draw(img)


def font(size):
    return ImageFont.truetype(FONT, size)


def fit(text, width, size):
    while font(size).getlength(text) > width:
        size -= 1
    return font(size)


def bevel(box, raised=True, n=2):
    x1, y1, x2, y2 = box
    a, b = (WHITE, DARK) if raised else (DARK, WHITE)
    for k in range(n):
        dr.line([(x1 + k, y2 - k), (x1 + k, y1 + k), (x2 - k, y1 + k)], fill=a)
        dr.line([(x2 - k, y1 + k), (x2 - k, y2 - k), (x1 + k, y2 - k)], fill=b)


def text3d(cx, y, text, f):
    """Text centred on cx, navy with a white highlight below right."""
    x = cx - f.getlength(text) / 2
    for dx, dy, col in ((2, 2, WHITE), (0, 0, NAVY)):
        dr.text((x + dx, y + dy), text, font=f, fill=col)


# the window: title bar, menu, frame
dr.rectangle([0, 0, W - 1, 41], fill=BLUE)
dr.rectangle([6, 6, 36, 35], fill=GRAY)
bevel((6, 6, 36, 35))
dr.rectangle([14, 19, 28, 23], fill=GRAY, outline=BLACK)
t = font(26)
dr.text(((W - t.getlength('Ishido for Windows')) / 2, 6), 'Ishido for Windows', font=t, fill=WHITE)
dr.rectangle([W - 40, 6, W - 6, 35], fill=GRAY)
bevel((W - 40, 6, W - 6, 35))
dr.polygon([(W - 31, 17), (W - 15, 17), (W - 23, 28)], fill=BLACK)
dr.rectangle([0, 42, W - 1, 68], fill=WHITE)
m = font(20)
x = 14
for word in ('Spiel', 'Optionen', 'Hilfe'):
    dr.text((x, 44), word, font=m, fill=BLACK)
    dr.line([(x, 66), (x + m.getlength(word[0]), 66)], fill=BLACK)
    x += m.getlength(word) + 34
dr.line([(0, 69), (W, 69)], fill=BLACK)
bevel((0, 0, W - 1, H - 1), True, 3)

# the game window with a shadow
board = Image.open(REPO / 'docs' / 'screenshots' / 'board.png').convert('RGB')
bx, by = 40, 100
dr.rectangle([bx + 10, by + 10, bx + board.width + 9, by + board.height + 9], fill=DARK)
img.paste(board, (bx, by))

# the logo, from the program's resources, and the words
logo = res_bitmap(REPO / 'source' / 'ISHIDO.RES', 1200)
logo = logo.resize((logo.width * 5 // 4, logo.height * 5 // 4), Image.NEAREST)
cx = 988
img.paste(logo, (cx - logo.width // 2, 84))
text3d(cx, 420, 'A stone game for Windows 3.1', fit('A stone game for Windows 3.1', 520, 34))
text3d(cx, 466, '72 gems, 6 colours, 6 shapes', fit('72 gems, 6 colours, 6 shapes', 520, 30))
text3d(cx, 508, 'Borland Pascal · 1993–1995', fit('Borland Pascal · 1993–1995', 520, 28))
text3d(cx, 546, 'by Olaf Gottschalk', fit('by Olaf Gottschalk', 520, 28))
g = font(22)
dr.text((W - 24 - g.getlength('github.com/Zordid/ishido'), H - 36), 'github.com/Zordid/ishido', font=g, fill=BLACK)

img.save(OUT)
print(OUT, img.size)
