#!/bin/zsh
# cut-game.sh RAW.avi OUT.mp4 : the game alone, at a lively pace
#
# RAW.avi is the capture of record-ishido.sh (DOSBox-X's own video recording): the
# info dialog with the scrolling credits, then the game. The cut starts when the
# info dialog has closed (found by looking at its title bar), drops the identical
# frames of the pauses in which the bot was thinking (the emulator was frozen, see
# play-ishido.py --freeze), plays the rest at GAME_FPS (default 24) and keeps the
# last 4 s as they are, so the final dialog is shown for a moment.
#
#   MODE=vga (default): 640x480 screen, the dialog's title bar (blue part) is at 120,76
#   MODE=svga:          1024x768 screen, title bar at 300,221
set -e
AVI=${1:A}; OUT=${2:A}; FPS=${GAME_FPS:-24}
if [[ ${MODE:-vga} == vga ]]; then CROP=640:462:0:18; SCALE=1280:924; TX=120; TY=76
else CROP=640:456:192:156; SCALE=1280:912; TX=300; TY=221; fi
start=$(ffmpeg -loglevel error -i $AVI -t 120 -vf "fps=10,crop=2:2:$TX:$TY,format=rgb24" -f rawvideo - | python3 -I -c '
import sys
d = sys.stdin.buffer.read(); n = len(d) // 12; was_blue = False
for i in range(n):
    r, g, b = d[i*12:i*12+3]
    blue = b > 120 and r < 70 and g < 70
    if blue: was_blue = True
    elif was_blue:
        print(i / 10 + 0.3); break
else:
    sys.exit("the info dialog never closed")')
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 $AVI)
end=$(( D - 4 ))
echo "info dialog closed at ${start} s, game until ${end} s of ${D} s"
ffmpeg -loglevel error -y -i $AVI -filter_complex \
  "[0:v]crop=${CROP},split[a][b];[a]trim=${start}:${end},setpts=PTS-STARTPTS,mpdecimate,setpts=N/(${FPS}*TB)[ha];[b]trim=${end},setpts=PTS-STARTPTS[hb];[ha][hb]concat=n=2:v=1,scale=${SCALE}:flags=neighbor[v]" \
  -map '[v]' -c:v libx264 -crf 18 -preset slow -tune animation -pix_fmt yuv420p -an -movflags +faststart $OUT
ffprobe -v error -show_entries format=duration,size -of compact=p=0 $OUT
