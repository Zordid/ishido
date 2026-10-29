#!/bin/zsh
# cut-video.sh IN.mp4 OUT.mp4 START [END]: re-encode a piece of a recording
# (seconds; no END = to the end of the file), same H.264 settings as record-ishido.sh.
# The full takes of record-ishido.sh have the info dialog with the credits for
# the first 32 s (the last sentence is fully visible at 22 s) and the game after.
set -e
to=(); [[ -n $4 ]] && to=(-to $4)
ffmpeg -loglevel error -y -ss $3 $to -i ${1:A} -c:v libx264 -crf 18 -preset slow -tune animation \
  -pix_fmt yuv420p -an -movflags +faststart ${2:A}
ffprobe -v error -show_entries format=duration,size -of compact=p=0 ${2:A}
