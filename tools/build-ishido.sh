#!/bin/zsh
# Build ISHIDO.EXE from source with Borland Pascal 7.0 in DOSBox-X.
#
# usage: tools/build-ishido.sh SRCDIR OUTDIR
#
#   SRCDIR     folder with ISHIDO.PAS and ISHIDO.RES (the source/ folder)
#   BP7_DISKS  environment variable: directory with the eleven Borland
#              Pascal 7.0 install disk images BP7_1.img ... BP7_11.img
#
# Takes BPC.EXE, the DPMI runtime, the Windows runtime library and the
# ObjectWindows and Windows 3.1 units from the disk images and compiles
# ISHIDO.EXE with BPC /CW, as the Borland Pascal 7.01 IDE did in 1995.
# The repository has the source as UTF-8; it is converted back to Windows-1252.
set -e
SRC=${1:A}; OUT=${2:A}; REPO=${0:A:h:h}; D=${BP7_DISKS:?set BP7_DISKS to the BP7 disk images}
rm -rf $OUT; mkdir -p $OUT/disks $OUT/BP/BIN $OUT/BP/UNITS $OUT/SRC
for i in {1..11}; do python3 -I $REPO/tools/fat12.py $D/BP7_$i.img $OUT/disks/$i >/dev/null; done
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/1/BPC.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/6/DPMISYS.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/BIN $OUT/disks/6/WTPL.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/UNITS $OUT/disks/7/OWL.ZIP >/dev/null
unar -q -f -D -o $OUT/BP/UNITS $OUT/disks/11/WIN31.ZIP >/dev/null
iconv -f UTF-8 -t CP1252 $SRC/ISHIDO.PAS > $OUT/SRC/ISHIDO.PAS
cp $SRC/ISHIDO.RES $OUT/SRC/
printf '@echo off\r\ncd \\src\r\nc:\\bp\\bin\\bpc /CW /M /Q /Uc:\\bp\\units /Rc:\\bp\\units ISHIDO.PAS > c:\\build.log\r\n' > $OUT/BUILD.BAT
dosbox-x -silent -nogui -set "dosbox quit warning=false" -set "sdl output=surface" -set "cpu cycles=max" -set "dosbox memsize=32" \
  -c "mount c $OUT" -c "c:" -c "build.bat" -c "exit" -time-limit 120 >/dev/null 2>&1 || true
tr -d '\r' < $OUT/BUILD.LOG | iconv -f CP437 -t UTF-8
ls -l $OUT/SRC/ISHIDO.EXE
