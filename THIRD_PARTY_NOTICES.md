# Third party notices

The snes9x-pico blob (`snes9x-pico.blob`) is built from the following. The emulator is under the
Snes9x licence (`LICENSE`, non-commercial); two of its sound and video modules are LGPL 2.1 code
whose author granted their use in Snes9x; the C and C++ runtime parts listed last are under
licences that place no conditions on the blob beyond keeping their notices.

## Snes9x and its libretro port (Snes9x licence)

- Source: <https://github.com/libretro/snes9x>, the `upstream/` submodule, at the commit recorded
  in this repository (and in `BUILD_INFO.txt` of a release).
- Copyright (c) 1996 to 2023 the Snes9x team (Gary Henderson, Jerremy Koot, Matthew Kendora,
  Peter Bortas, Joel Yliluoma, John Weidman, funkyass, Kris Bleakley, Brad Jorsch, Nach, zones,
  nitsuja, BearOso, OV2, qwertymodo and the authors of the enhancement chip, sound and filter code
  named in `LICENSE`); the libretro port (c) 2011 to 2017 Hans-Kristian Arntzen and Daniel De
  Matteis, and the libretro/snes9x contributors since.
- Licence: the Snes9x licence, copied unchanged from upstream into `LICENSE`. Use, copying,
  modification and distribution in binary and source form are allowed for non-commercial
  purposes, provided the licence and copyright notice go with every copy and every derived work.
  Commercial use needs the copyright holders' permission. Under no circumstances will commercial
  rights be given for the libretro port.
- Built from it: the 65816 CPU, PPU and renderer, DMA, memory map, enhancement chips (SuperFX,
  SA-1, DSP-1 to 4, C4, S-DD1, SPC7110, OBC1, ST010/ST011, S-RTC, BS-X, MSU-1), the S-SMP
  (byuu), the controllers, snapshots, and `libretro/libretro.cpp`. Its zip and file I/O are not
  built.

## LGPL 2.1 modules inside Snes9x

- **SPC_DSP** (`upstream/apu/bapu/dsp/SPC_DSP.cpp`, built through `sdsp.cpp`), Copyright (C) 2007
  Shay Green: the S-DSP sound chip.
- **snes_ntsc** (`upstream/filter/snes_ntsc.c`), Copyright (C) 2006-2007 Shay Green: the NTSC
  composite video filter.

Both files say they are free software under the GNU Lesser General Public License, version 2.1 or
later; upstream's `LICENSE` notes that their authors granted an exception for their use in Snes9x.
The licence text is `upstream/filter/snes_ntsc-license.txt`, shipped in a release as
`licenses/LGPL-2.1.txt`. This repository and every release's source archive hold the complete
source and the build script, so the blob can be rebuilt with a modified version of either module.

## libretro API and libretro-common headers (MIT)

`libretro/libretro.h` and the `libretro-common` headers the core includes are Copyright (C) 2010
to 2024 The RetroArch team, under the MIT licence printed at the top of each file. None of
libretro-common's `.c` files are built: the file and VFS functions they would provide are stubbed
in `pico/pico_stubs.c`.

## This repository

The glue in `pico/`, the patches in `patches/`, the build and packaging scripts and the host test
in `tools/`: Copyright (c) 2026 TheGammaSqueeze, distributed under the Snes9x licence like the core
they are built into. `pico/snes_core_abi.h` is a copy of the interface header of the GammaOS LK
(lk-mt6785) by the same author, provided here under the same terms.

## The runtime linked into the blob

`out/snes9x-pico.map` lists every library member in the blob.

- **libstdc++** (the GCC project): `std::string`, string streams, `std::map` and the iostream and
  locale objects they pull in (Snes9x uses them in its memory map, controller and BML code).
  GPL-3.0 with the GCC Runtime Library Exception, which places no conditions on the compiled blob.
  The copyright file of the toolchain package (Ubuntu's `libstdc++-arm-none-eabi-newlib`) ships
  in a release as `licenses/libstdc++-COPYRIGHT.txt`.
- **libgcc** (the GCC project): soft float arithmetic, 64 bit division and the ARM unwinder
  libstdc++ references. GPL-3.0 with the GCC Runtime Library Exception.
- **newlib's libm** (Sun Microsystems' fdlibm and the newlib contributors): `sin`, `cos`, `pow`,
  `exp`, `sqrt`, `floor`, `ceil`, `rint` and their helpers. BSD style permissive licences; the
  notices are in newlib's `COPYING.NEWLIB` and, for the toolchain releases are built with
  (Ubuntu's `libnewlib-arm-none-eabi`), in the copyright file shipped in a release as
  `licenses/newlib-COPYRIGHT.txt`. newlib's C library is not linked: `pico/pico_libc.c` provides
  the C functions the core needs.

## Corresponding source

The Snes9x licence asks that its notice goes with every copy, and the LGPL modules ask that the
blob can be rebuilt from modified source. Every release carries `LICENSE` and
`snes9x-pico-<version>-src.tar.gz`, this repository with the upstream submodule at the exact
commit the blob was built from; `./build.sh` rebuilds the blob from it.
