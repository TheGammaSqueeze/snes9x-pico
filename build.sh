#!/bin/bash
# snes9x-pico: build the snes9x core blob for the GammaOS LK (lk-mt6785, Konkr Pocket Advance).
# Copyright (c) 2026 TheGammaSqueeze. Distributed under the Snes9x licence (LICENSE).
#
#   ./build.sh            -> out/snes9x-pico.blob (copy it to the SD card as /cores/snes9x-pico.blob)
#   ./build.sh clean
#
# The upstream tree (submodule upstream/, libretro/snes9x) is never modified: it is copied to
# out/src, the patches in patches/ are applied there, and that copy is compiled together with the
# glue in pico/. Only the emulator core and the libretro entry points are built; file, zip and
# VFS I/O are left out and stubbed (pico/pico_stubs.c): the LK hands the core the ROM as a buffer.
#
# Target: the LK runs the core in 32 bit state on the MT6785 with the LK's own calling convention
# (soft float, no NEON or VFP registers touched), so the flags below keep -mfloat-abi=soft and only
# pick ARMv8-A instruction selection (hardware divide) tuned for the Cortex-A76. The blob must fit
# its slot, so optimisation is chosen per file: the code that runs every frame (65816 CPU, DMA,
# PPU and renderer entry, memory map, SPC700 and DSP) at -O2, everything else at -Os, all with
# link time optimisation (-O2 at the link). These are the flags, sources and link order the LK
# used when the core was built in its tree (emu/snes9x/build_core.sh + build_core_blob.sh): the
# blob is byte for byte the one that tree produced plus the 12 bytes of padding that file lacked
# (see pico/blob.ld). Keep it that way unless a change is meant to alter the core.
set -euo pipefail
export LC_ALL=C
cd "$(dirname "$0")"
ROOT=$PWD
OUT=$ROOT/out
SRC=$OUT/src
OBJ=$OUT/obj
CC=${CC:-arm-none-eabi-gcc}
CXX=${CXX:-arm-none-eabi-g++}
AR=${AR:-arm-none-eabi-ar}
OBJCOPY=${OBJCOPY:-arm-none-eabi-objcopy}

if [ "${1:-}" = clean ]; then rm -rf "$OUT"; exit 0; fi

if [ ! -f upstream/snes9x.h ]; then
	git submodule update --init upstream
fi

UPSTREAM_REV=$(git -C upstream rev-parse --short=12 HEAD 2>/dev/null || echo unknown)
PICO_REV=$(git describe --always --dirty 2>/dev/null || echo unknown)
VERSION="snes9x ${UPSTREAM_REV} (pico ${PICO_REV})"

rm -rf "$SRC" "$OBJ"
mkdir -p "$OBJ/core" "$OBJ/pico"
cp -a upstream "$SRC"
rm -rf "$SRC/.git"
# EXTRA_PATCHES: more patches for experiments, applied after these; releases use none
for p in patches/*.patch ${EXTRA_PATCHES:-}; do
	[ -e "$p" ] || continue
	echo ">> patch $(basename "$p")"
	case "$p" in /*) pp=$p;; *) pp=$ROOT/$p;; esac
	(cd "$SRC" && patch -p1 --quiet --forward < "$pp")
done

INC="-I$SRC -I$SRC/apu -I$SRC/apu/bapu -I$SRC/libretro -I$SRC/libretro/libretro-common/include"
# No optimisation level here: it is chosen per file (opt_for) and, for the final link, after it.
# -fno-ipa-icf: GCC 10.3's LTO identical code folding pass crashes on this core for armv8-a.
# -fno-strict-aliasing: the core is not written for type based aliasing (black screen without).
COMMON="-march=armv8-a -mtune=cortex-a76 -mfloat-abi=soft -mthumb-interwork -ffreestanding \
	-fno-exceptions -fno-rtti -fno-threadsafe-statics -fno-use-cxa-atexit \
	-fno-short-enums -mno-unaligned-access -fno-strict-aliasing -fno-common \
	-flto -ffat-lto-objects -fno-ipa-icf \
	-ffunction-sections -fdata-sections -D__LIBRETRO__ $INC"
CFLAGS="$COMMON -std=gnu99"
CXXFLAGS="$COMMON"

# Files run every frame by a typical game get -O2. tile.c (the inlined renderer variants, 1.2 MB
# at -O2) and the SA-1 files (SA-1 carts only) stay -Os so the blob fits its slot.
HOT_SET=" cpu cpuexec cpuops dma gfx ppu memmap apu/apu apu/bapu/dsp/sdsp apu/bapu/smp/smp apu/bapu/smp/smp_state "
opt_for() { case "$HOT_SET" in *" $1 "*) echo "-O2";; *) echo "-Os";; esac; }

# The core: enhancement chips, the NTSC filter and the DSP in C; CPU, PPU, APU, DMA, renderer and
# the libretro entry points in C++. zipfile.c and loadzip.cpp (zip I/O) are not built.
C_SRCS="c4emu msu1 srtc obc1 bsflash tile bsx spc7110 fxemu sdd1 seta sa1hw dsp filter/snes_ntsc"
CXX_SRCS="apu/apu apu/bapu/dsp/sdsp apu/bapu/smp/smp apu/bapu/smp/smp_state \
	cheats2 clip controls cpu cpuexec cpuops crosshairs dma gfx globals \
	memmap ppu sa1 sa1cpu snapshot sha256 bml fscompat libretro/libretro"

for f in $C_SRCS; do
	$CC $CFLAGS $(opt_for "$f") -c "$SRC/$f.c" -o "$OBJ/core/$(echo "$f" | tr '/' '_').o"
done
for f in $CXX_SRCS; do
	$CXX $CXXFLAGS $(opt_for "$f") -c "$SRC/$f.cpp" -o "$OBJ/core/$(echo "$f" | tr '/' '_').o"
done

# The core goes into an archive, its members in byte order of their names (LC_ALL=C above): the
# link pulls members on demand in that order, and the order decides the blob's layout.
rm -f "$OUT/libsnes9x.a"
$AR rcs "$OUT/libsnes9x.a" "$OBJ"/core/*.o

# The glue: the LK interface, the C++ runtime and heap, the C library and the I/O stubs.
$CXX $COMMON -Os -Wall -c "$ROOT/pico/pico_core.cpp" -o "$OBJ/pico/pico_core.o"
$CXX $COMMON -Os -Wall -c "$ROOT/pico/pico_shim.cpp" -o "$OBJ/pico/pico_shim.o"
$CC  $COMMON -Os -std=gnu99 -Wall -c "$ROOT/pico/pico_libc.c" -o "$OBJ/pico/pico_libc.o"
$CC  $COMMON -Os -std=gnu99 -w    -c "$ROOT/pico/pico_stubs.c" -o "$OBJ/pico/pico_stubs.o"

LIBGCC=$($CC $COMMON -Os -print-libgcc-file-name)
LIBM=$($CC $COMMON -Os -print-file-name=libm.a)
LIBSTDCXX=$($CXX $COMMON -Os -print-file-name=libstdc++.a)

# Flat link at the slot address through the g++ driver, so the LTO plugin runs across the whole
# core (the memory access path inlines across files). -Os then -O2: the last level wins, so the
# link time optimisation runs at -O2. No start files and no default libraries: the glue, the core
# and, on demand, libstdc++, newlib's libm and libgcc resolve everything.
$CXX $COMMON -Os -O2 -nostdlib -nostartfiles \
	-Wl,-T,"$ROOT/pico/blob.ld" -Wl,--gc-sections -Wl,-Map,"$OUT/snes9x-pico.map" \
	"$OBJ/pico/pico_core.o" "$OBJ/pico/pico_shim.o" "$OBJ/pico/pico_libc.o" "$OBJ/pico/pico_stubs.o" \
	-Wl,--start-group "$OUT/libsnes9x.a" "$LIBSTDCXX" "$LIBM" "$LIBGCC" -Wl,--end-group \
	-o "$OUT/snes9x-pico.elf"
$OBJCOPY -O binary "$OUT/snes9x-pico.elf" "$OUT/snes9x-pico.blob"

python3 - "$OUT/snes9x-pico.blob" "$VERSION" <<'EOF'
import struct, sys, hashlib
d = open(sys.argv[1], 'rb').read()
magic, ver, entry, load, span = struct.unpack_from('<5I', d)
assert magic == 0x31534E53 and ver == 2, "bad header"
assert load == len(d), "load size %d != file %d" % (load, len(d))
assert 20 <= entry < load, "entry outside the image"
print("snes9x-pico.blob: %s" % sys.argv[2])
print("  file %d bytes, span %d bytes (%.2f MiB with BSS), entry +0x%x" % (len(d), span, span / 1048576.0, entry))
print("  sha256 %s" % hashlib.sha256(d).hexdigest())
EOF
