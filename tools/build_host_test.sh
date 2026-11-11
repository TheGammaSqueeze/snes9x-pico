#!/bin/bash
# Copyright (c) 2026 TheGammaSqueeze. Distributed under the Snes9x licence (LICENSE).
# Build the headless core check (tools/host_test.cpp) natively (x86-64, hosted) from the same
# patched sources the blob is built from (out/src, made by ./build.sh):
#
#   ./build.sh && tools/build_host_test.sh && out/host_test <rom.sfc> [frames]
#
# It loads the ROM, runs frames, checks the picture changes, and checks that a save state and a
# run ahead snapshot taken and loaded reproduce the same frame. Exit status 0 means PASS.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")/.."
ROOT=$PWD
SRC=$ROOT/out/src
OBJ=$ROOT/out/host_obj
[ -f "$SRC/snes9x.h" ] || { echo "out/src missing: run ./build.sh first" >&2; exit 1; }
HOST_CC=${HOST_CC:-gcc}
HOST_CXX=${HOST_CXX:-g++}

INC="-I$SRC -I$SRC/apu -I$SRC/apu/bapu -I$SRC/libretro -I$SRC/libretro/libretro-common/include"
F="-D__LIBRETRO__ -DVIDEO_RGB565 -O2 -w -fno-strict-aliasing $INC"
rm -rf "$OBJ"; mkdir -p "$OBJ"

# the same source list as build.sh
C_SRCS="c4emu msu1 srtc obc1 bsflash tile bsx spc7110 fxemu sdd1 seta sa1hw dsp filter/snes_ntsc"
CXX_SRCS="apu/apu apu/bapu/dsp/sdsp apu/bapu/smp/smp apu/bapu/smp/smp_state \
	cheats2 clip controls cpu cpuexec cpuops crosshairs dma gfx globals \
	memmap ppu sa1 sa1cpu snapshot sha256 bml fscompat libretro/libretro"
for f in $C_SRCS; do $HOST_CC $F -std=gnu99 -c "$SRC/$f.c" -o "$OBJ/$(echo "$f" | tr '/' '_').o"; done
for f in $CXX_SRCS; do $HOST_CXX $F -c "$SRC/$f.cpp" -o "$OBJ/$(echo "$f" | tr '/' '_').o"; done
$HOST_CXX $F -c "$ROOT/tools/host_stubs.cpp" -o "$OBJ/host_stubs.o"

$HOST_CXX $F "$ROOT/tools/host_test.cpp" "$OBJ"/*.o -o "$ROOT/out/host_test" -lm
echo "built out/host_test - run: out/host_test <rom.sfc> [frames]"
