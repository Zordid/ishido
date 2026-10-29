#!/usr/bin/env python3
"""Play Ishido on the kiosk-pc by looking at the screen, like a patient human.

usage: python3 -I tools/play-ishido.py PC_DIR FRAMES_DIR [--max N] [--pause MS] [--glide MS]
                                        [--freeze] [--dwell SEC] [--screen WxH] [--hint X Y] [--vga] [--pointer X Y]

  PC_DIR      the kiosk-pc folder (kpc.sh, started with `./kpc.sh start ishido`,
              the info dialog already closed)
  FRAMES_DIR  every move leaves a screenshot frame_NNN.png here
  --glide MS  move the pointer to each field in eased steps taking MS
              milliseconds (for video), instead of jumping there. The emulated
              PC runs about 8 times faster than the wall clock, so 2800 is
              about a third of a second to look at.
  --freeze    stop DOSBox-X (SIGSTOP) while the bot looks at the screen and
              thinks, and let it run (SIGCONT) only while a move is played:
              a video recording then contains the moves and no waiting
  --dwell SEC real seconds to let a move show before the next freeze (0.15)
  --screen WxH  size of the PC's screen in the screenshots (default 1024x768; the
              standard VGA driver gives 640x480)
  --vga       the screen is in the standard VGA mode: the 14 colours of
              STONES.BMP show up as other values in the screenshots (see VGA_COLORS),
              so the templates are recoloured before they are compared
  --pointer X Y  where the pointer is when the bot starts (the OK button of the
              info dialog; default 615 565, in the 640x480 mode 427 421)
  --hint X Y  where to look for the window's client area (default 190 190, the
              Ishido window of the 1024x768 screen; for 640x480 try 0 45)

The game state is read from the screenshots (no access to the program's
memory): the next stone at the right, the six start stones on the board. The
rules are those of ISHIDO.PAS (CheckPosition): a stone must touch another stone
and every neighbour must share its colour or shape; with 2 or 3 neighbours at
least one must match by colour and one by shape, with 4 neighbours at least two
of each. The 72 stones are known (6 colours x 6 shapes, twice), so the bot knows
what is left in the pouch and picks the move after which the most of the
remaining stones still have a place to go.

After every click it looks at the square it clicked: if the stone it meant to
lay is not there, it stops with "LOST SYNC" and exit code 3 instead of playing on
with a wrong picture of the board (the game it was playing is then discarded). In
the standard VGA mode use --vga, or the colours do not match and it loses track.

Needs ffmpeg; no other dependencies. Sprites are cut from source/STONES.BMP.
"""
import os, signal, subprocess, sys, time, itertools
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
XSIZE, YSIZE = 12, 8
XFIELD, YFIELD = 40, 46
XBOARD, YBOARD = 16, 16          # client coordinates, as in ISHIDO.PAS
XTOUCH, YTOUCH = 540, 190
SW, SH = 33, 40                  # sprite size
SW_STEP, SH_STEP = 34, 41        # sprite sheet grid (shape = column, colour = row)
W, H = 1024, 768                 # kpc.sh shot: Windows screen pixels
COLORS = ['red', 'blue', 'green', 'gray', 'magenta', 'yellow']
SHAPES = ['square', 'triangle', 'octagon', 'drop', 'round', 'diamond']


def rgb(path, w, h):
    out = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', str(path), '-f', 'rawvideo',
                          '-pix_fmt', 'rgb24', '-'], capture_output=True, check=True).stdout
    assert len(out) == w * h * 3, (path, len(out))
    return out


class Img:
    def __init__(self, data, w):
        self.d, self.w = data, w

    def crop(self, x, y, w, h, step=2):
        return [self.d[((y + j) * self.w + x + i) * 3 + k]
                for j in range(0, h, step) for i in range(0, w, step) for k in range(3)]


# What the 14 colours of STONES.BMP look like in a screenshot of the standard VGA
# mode on this Mac (the display profile and the VGA palette change them; the dark
# colours get lighter). Measured on the screenshots, matched by hue.
VGA_COLORS = {
    (0, 0, 0): (0, 0, 0), (255, 255, 255): (255, 255, 255),
    (192, 192, 192): (187, 192, 196), (128, 128, 128): (123, 127, 131),
    (128, 0, 0): (159, 11, 74), (0, 128, 0): (17, 160, 81), (128, 128, 0): (160, 160, 82),
    (128, 0, 128): (159, 76, 157), (0, 128, 128): (76, 160, 160),
    (255, 0, 0): (254, 16, 22), (0, 255, 0): (28, 254, 54), (255, 255, 0): (255, 255, 59),
    (0, 0, 255): (0, 9, 248), (255, 0, 255): (253, 19, 249),
}


def load_templates(recolour=None):
    data = rgb(REPO / 'source' / 'STONES.BMP', 205, 266)
    if recolour:
        out = bytearray(len(data))
        for i in range(0, len(data), 3):
            out[i:i + 3] = bytes(recolour.get(tuple(data[i:i + 3]), tuple(data[i:i + 3])))
        data = bytes(out)
    sheet = Img(data, 205)
    return {(s, c): sheet.crop((s - 1) * SW_STEP, (c - 1) * SH_STEP, SW, SH)
            for s in range(1, 7) for c in range(1, 7)}


def dist(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def classify(img, x, y, tpl):
    c = img.crop(x, y, SW, SH)
    best = min(tpl, key=lambda k: dist(c, tpl[k]))
    return best, dist(c, tpl[best]), dist(c, [128] * len(c))


# ---- the rules (ISHIDO.PAS: CheckPosition / ScoreFunc) --------------------
def matches(board, x, y, st):
    """Number of matching neighbours, 0 if the stone does not fit here."""
    n = sh = co = 0
    for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        p = board.get((x + dx, y + dy))
        if not p:
            continue
        if p[0] != st[0] and p[1] != st[1]:
            return 0
        n += 1
        sh += p[0] == st[0]
        co += p[1] == st[1]
    if n in (2, 3) and (sh == 0 or co == 0):
        return 0
    if n == 4 and (sh < 2 or co < 2):
        return 0
    return n


def legal(board, st):
    return [(x, y) for x in range(1, XSIZE + 1) for y in range(1, YSIZE + 1)
            if (x, y) not in board and matches(board, x, y, st)]


def choose(board, st, rest):
    """Pick the move that keeps most of the remaining stones playable."""
    best, best_key = None, None
    types = {}
    for t in rest:
        types[t] = types.get(t, 0) + 1
    for (x, y) in legal(board, st):
        m = matches(board, x, y, st)
        board[(x, y)] = st
        playable = mobility = 0
        for t, n in types.items():
            k = len(legal(board, t))
            playable += n * (k > 0)
            mobility += n * k
        del board[(x, y)]
        # four-way matches are worth a lot (factor doubles), prefer them
        key = (playable, m == 4, mobility)
        if best_key is None or key > best_key:
            best, best_key = (x, y), key
    return best, best_key


# ---- driving the PC -------------------------------------------------------
class PC:
    def __init__(self, pc, frames):
        self.pc, self.frames, self.n = Path(pc), Path(frames), 0
        self.frames.mkdir(parents=True, exist_ok=True)

    def send(self, *cmds):
        subprocess.run([str(self.pc / 'kpc.sh'), 'send', *cmds], check=True, cwd=self.pc)

    # --freeze: kpc.sh send waits 0.7 s after every call; here the commands go to the
    # agent directly (C:\AUTO\IN.TXT, answered by DONE.TXT) and DOSBox-X is stopped
    # and continued around them
    def pid(self):
        return int((self.pc / '.kpc.pid').read_text())

    def freeze(self):
        os.kill(self.pid(), signal.SIGSTOP)

    def thaw(self):
        os.kill(self.pid(), signal.SIGCONT)

    def send_fast(self, *cmds, dwell=0.15):
        auto = self.pc / 'drive_c' / 'AUTO'
        (auto / 'DONE.TXT').unlink(missing_ok=True)
        (auto / 'IN.TMP').write_bytes(''.join(c + '\r\n' for c in cmds).encode())
        os.replace(auto / 'IN.TMP', auto / 'IN.TXT')
        for _ in range(3000):                      # up to 30 s
            if (auto / 'DONE.TXT').exists():
                break
            time.sleep(0.01)
        time.sleep(dwell)                          # the result is drawn and recorded

    def shot(self, name=None):
        out = self.frames / (name or f'frame_{self.n:03d}.png')
        subprocess.run([str(self.pc / 'kpc.sh'), 'shot', str(out)], check=True, cwd=self.pc)
        self.n += 1
        return out


def glide(frm, to, ms, steps=20):
    """Agent commands that move the pointer from frm to to like a hand (ease in/out)."""
    cmds = []
    for i in range(1, steps + 1):
        t = i / steps
        e = 2 * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 2 / 2
        cmds += [f'move {int(frm[0] + (to[0] - frm[0]) * e)} {int(frm[1] + (to[1] - frm[1]) * e)}',
                 f'wait {ms // steps}']
    return cmds


def find_origin(img, tpl, x0=190, y0=190):
    """Client-area origin on the screen: where the top-left start stone matches best."""
    best = None
    for oy in range(y0, y0 + 24):
        for ox in range(x0, x0 + 24):
            c = img.crop(ox + XBOARD + 3, oy + YBOARD + 3, SW, SH)
            d = min(dist(c, t) for t in tpl.values())
            if best is None or d < best[0]:
                best = (d, ox, oy)
    return best[1], best[2]


def main():
    args = sys.argv[1:]
    pc, frames = PC(args[0], args[1]), None
    limit = int(args[args.index('--max') + 1]) if '--max' in args else 99
    pause = int(args[args.index('--pause') + 1]) if '--pause' in args else 600
    glide_ms = int(args[args.index('--glide') + 1]) if '--glide' in args else 0
    freeze = '--freeze' in args
    dwell = float(args[args.index('--dwell') + 1]) if '--dwell' in args else 0.15
    global W, H
    if '--screen' in args:
        W, H = map(int, args[args.index('--screen') + 1].split('x'))
    hint = tuple(int(v) for v in args[args.index('--hint') + 1:args.index('--hint') + 3]) if '--hint' in args else (190, 190)
    pointer = tuple(int(v) for v in args[args.index('--pointer') + 1:args.index('--pointer') + 3]) if '--pointer' in args else (615, 565)
    tpl = load_templates(VGA_COLORS if '--vga' in args else None)

    if freeze:
        pc.freeze()
    try:
        play(pc, tpl, limit, pause, glide_ms, freeze, dwell, pointer, hint)
    finally:
        if freeze:
            pc.thaw()


def play(pc, tpl, limit, pause, glide_ms, freeze, dwell, pointer, hint):
    shot = pc.shot()
    img = Img(rgb(shot, W, H), W)
    ox, oy = find_origin(img, tpl, *hint)
    print('client origin', ox, oy)

    def read_cell(img, x, y):
        return classify(img, ox + XBOARD + 3 + (x - 1) * XFIELD, oy + YBOARD + 3 + (y - 1) * YFIELD, tpl)

    def read_next(img):
        return classify(img, ox + XTOUCH + 4, oy + YTOUCH + 4, tpl)

    board = {}
    for pos in ((1, 1), (12, 1), (12, 8), (1, 8), (6, 4), (7, 5)):
        k, d, bg = read_cell(img, *pos)
        board[pos] = k
        print('start', pos, SHAPES[k[0] - 1], COLORS[k[1] - 1], 'dist', d)
    pool = {(s, c): 2 for s in range(1, 7) for c in range(1, 7)}
    for k in board.values():
        pool[k] -= 1

    def cell_ok(img, pos, stone):
        k, d, bg = read_cell(img, *pos)
        return k == stone

    last = None
    placed, score_log = 6, []
    while placed < 72 and len(score_log) < limit:
        st, d, bg = read_next(img)
        pool[st] -= 1
        rest = [k for k, n in pool.items() for _ in range(n)]
        moves = legal(board, st)
        print(f'#{len(score_log)+1:2d} next: {SHAPES[st[0]-1]:8s} {COLORS[st[1]-1]:8s} '
              f'(dist {d}) legal {len(moves)}, pouch {len(rest)}')
        if last and moves and not cell_ok(img, *last):     # no dialog covers it, so the click failed
            print(f'LOST SYNC: {SHAPES[last[1][0]-1]} {COLORS[last[1][1]-1]} is not at {last[0]}')
            sys.exit(3)
        if not moves:
            print('no legal move: game over')
            break
        (x, y), key = choose(board, st, rest)
        print(f'     -> field {x},{y}  playable {key[0]}/{len(rest)}  4-way {key[1]}  mobility {key[2]}')
        board[(x, y)] = st
        placed += 1
        score_log.append(((x, y), st))
        target = (ox + XBOARD + (x - 1) * XFIELD + XFIELD // 2, oy + YBOARD + (y - 1) * YFIELD + YFIELD // 2)
        moving = glide(pointer, target, glide_ms) + ['wait 150'] if glide_ms else []
        cmds = [*moving, f'click {target[0]} {target[1]}', f'wait {pause}']
        if freeze:
            pc.thaw()
            pc.send_fast(*cmds, dwell=dwell)
            pc.freeze()
        else:
            pc.send(*cmds)
        pointer = target
        last = ((x, y), st)
        shot = pc.shot()
        img = Img(rgb(shot, W, H), W)
        # a modal "game over" box would hide the next stone: placed==72 or no moves left
        if placed == 72:
            break
    print(f'moves played: {len(score_log)}, stones on the board: {placed}')
    if freeze:                      # let the final dialog be recorded for a moment
        pc.thaw()
        time.sleep(3)


if __name__ == '__main__':
    main()
