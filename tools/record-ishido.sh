#!/bin/zsh
# record-ishido.sh OUT.mp4 : the bot plays a whole game of Ishido on the kiosk-pc
#
# usage: tools/record-ishido.sh OUT.mp4 [FRAMES_DIR]
#
#   PC   environment variable: the kiosk-pc folder (default ~/RetroPC/kiosk-pc),
#        with Ishido installed in C:\ISHIDO and `./kpc.sh start ishido`
#
# Starts Windows with Ishido in the standard VGA mode, 640x480 in 16 colours, which
# is what the game was made for (MODE=svga: the 1024x768 256-colour screen), with
# the release's own BWCC.DLL (bin/install-ishido.sh of the kiosk-pc), switches on DOSBox-X's own video capture (Capture > Record video to AVI,
# clicked through System Events: needs the Accessibility permission for the
# terminal), shows the info dialog until the credits line has scrolled past once
# and lets tools/play-ishido.py play. The AVI is cropped to the Ishido window
# and converted to H.264 (2x, pixels not smoothed). Every move's screenshot
# stays in FRAMES_DIR (default: next to OUT).
#
# Notes:
#  - The banner speed is the program's own setting, ScrollSpeed in
#    C:\WINDOWS\ENTPACK.INI (idle passes between two one-pixel steps; the larger,
#    the slower). The emulated PC runs far faster than the wall clock, so it
#    needs a big value: SCROLL=11000 (default) gives about 46 px/s, one pass of
#    the 168 characters in about 25 s; INTRO seconds (default 36; 26 shows
#    exactly one pass in VGA) is how long the info dialog stays open.
#  - In the 256-colour Super VGA mode (MODE=svga) BWCC's dialogs have gaps and the
#    board shines through, with the release's BWCC.DLL more than with the English
#    one of 1995; in the standard VGA mode they are painted completely. Hence VGA
#    and the release's own DLL (kiosk-pc: bin/install-ishido.sh) are the default.
#  - Minimizing the Program Manager while the info dialog is open leaves repaint
#    artifacts in it, and a custom shell= would stop WIN.INI load= (the agent)
#    from running: `kpc.sh start ishido` moves the Program Manager aside instead.
#  - The AVI of the take stays next to OUT as OUT.avi: tools/cut-game.sh cuts the
#    game from it, stills can be taken from it at the native size.
set -e
PC=${PC:-~/RetroPC/kiosk-pc}; PC=${PC:A}; OUT=${1:A}; FRAMES=${2:-${OUT:r}-frames}; K=$PC/kpc.sh
REPO=${0:A:h:h}
if [[ ${MODE:-vga} == vga ]]; then
  export KPC_DISPLAY=vga; CROP=640:462:0:18; SCALE=1280:924
  BOT=(--vga --screen 640x480 --hint 0 45 --pointer 427 421)
  M1="move 400 380"; M2="move 420 412"; OK="click 427 421"; M0="move 300 300"
else
  CROP=640:456:192:156; SCALE=1280:912
  BOT=(--pointer 615 565)
  M1="move 600 520"; M2="move 612 556"; OK="click 615 565"; M0="move 560 450"
fi
rec() { osascript -e 'tell application "System Events" to tell (first process whose name contains "dosbox") to click menu item "Record video to AVI [F12+I]" of menu 1 of menu bar item "Capture" of menu bar 1' >/dev/null; }
$K stop; sleep 1; rm -rf $PC/capture $FRAMES
printf '[Ishido]\r\nScrollSpeed=%s\r\n' ${SCROLL:-11000} > $PC/drive_c/WINDOWS/ENTPACK.INI
$K start ishido
$K send $M0 "wait 300"
rec; t_rec=$(perl -MTime::HiRes=time -e 'print time'); sleep ${INTRO:-36}     # the info dialog with the scrolling credits
$K send $M1 "wait 400" $M2 "wait 400" $OK "wait 1200"                          # then OK
t_ok=$(perl -MTime::HiRes=time -e 'print time')
python3 -I $REPO/tools/play-ishido.py $PC $FRAMES --freeze --glide 2800 --pause 300 --dwell 0.15 $BOT
sleep 2; rec; sleep 2
$K stop
avi=$(ls $PC/capture/*.avi | tail -1)
ffmpeg -loglevel error -y -i $avi -vf "crop=${CROP},scale=${SCALE}:flags=neighbor" -c:v libx264 -crf 18 -preset slow \
  -tune animation -pix_fmt yuv420p -an -movflags +faststart $OUT
ffprobe -v error -show_entries format=duration,size -of compact=p=0 $OUT
MODE=${MODE:-vga} $REPO/tools/cut-game.sh $avi ${OUT:r}-game.mp4
cp $avi ${OUT:r}.avi
