# snes9x-pico

> **All of the emulation here is the work of the Snes9x team and the libretro port's authors.**
> [Snes9x](https://github.com/snes9xgit/snes9x) (Gary Henderson, Jerremy Koot, BearOso, OV2 and
> the many authors named in `LICENSE`) and its libretro port
> ([libretro/snes9x](https://github.com/libretro/snes9x), Hans-Kristian Arntzen, Daniel De Matteis
> and contributors) do everything that matters in this core. If you enjoy it, please thank and
> support them, not this repository.

[Snes9x](https://www.snes9x.com/), in the form of its libretro port, built as a loadable Super
Nintendo core for the GammaOS bootloader emulator on the Konkr Pocket Advance (MediaTek MT6785,
`lk-mt6785`, branch `lk-gba-emu-sd-card-kpa`).

This repository adds no emulation code: it holds the upstream tree as a submodule, the smallest
possible set of patches, the glue that lets Snes9x run inside a bootloader with no operating
system, and a build script.

**This is an experimental project and does not accept issues.** Please do not report problems you
see with snes9x-pico to Snes9x or libretro either: this build runs Snes9x in a bootloader on
hardware upstream does not target, so its behaviour here says nothing about Snes9x itself.

## Credits

- **Snes9x** (the Snes9x team, Snes9x licence): the Super Nintendo emulator, its 65816 CPU, PPU,
  DMA, memory map and every enhancement chip it supports, with the S-SMP by byuu and the S-DSP
  (SPC_DSP) and NTSC filter by Shay Green. See `LICENSE` for the full list of authors.
- **The libretro port** (Hans-Kristian Arntzen, Daniel De Matteis and the libretro/snes9x
  contributors): `libretro/libretro.cpp`, the interface this core is driven through, and its core
  options.

## License

Snes9x is under the **Snes9x licence**, copied unchanged from upstream into `LICENSE`: free for
non-commercial use, copying, modification and distribution in binary and source form, provided the
licence and copyright notice go with every copy and every derived work. It is not an open source
licence: commercial use needs the copyright holders' permission, and none will be given for the
libretro port. The glue in `pico/`, `patches/`, `tools/` and the build scripts are distributed under
the same licence, so the blob as a whole is under it. The blob also links libstdc++ and libgcc (GCC
Runtime Library Exception) and parts of newlib's libm (BSD style licences), and Snes9x itself
contains two LGPL 2.1 modules by Shay Green; `THIRD_PARTY_NOTICES.md` lists everything, and every
release carries the licence texts and the complete source the blob was built from.

## Layout

| Path | What it is |
| --- | --- |
| `upstream/` | libretro/snes9x, as a git submodule, never modified in place |
| `patches/` | changes to upstream, applied by `build.sh` to a copy in `out/src` |
| `pico/pico_core.cpp` | the LK's core interface (`snes_core_abi.h`, version 2) filled in through the libretro API |
| `pico/pico_shim.cpp` | the heap (a zeroed bump arena), `operator new`, the static constructor runner, C++ ABI stubs |
| `pico/pico_libc.c` | the C library functions the core uses (memory, strings, `vsnprintf`, number parsing) |
| `pico/pico_stubs.c` | file, zip, VFS and wide character functions that are referenced but never run, all failing safely |
| `pico/snes_core_abi.h` | a copy of `lk-mt6785/emu/snes9x/snes_core_abi.h`; the LK's copy is the reference |
| `pico/blob.ld` | link script: flat image, fixed address 0x4F000000, 20 byte header |
| `build.sh` | builds `out/snes9x-pico.blob` |
| `tools/package.sh` | packs a release: the SD card zip and the source archive, into `dist/` |
| `tools/host_test.cpp`, `tools/build_host_test.sh` | runs the patched core natively on a PC and checks it |
| `tools/make_test_rom.py` | writes a small test cartridge for the host test |
| `.github/workflows/build.yml` | CI: builds every push, publishes a release for a `v*` tag |
| `THIRD_PARTY_NOTICES.md` | what is in the blob and under which licence |

### Patches

| Patch | Why |
| --- | --- |
| `0001-linear-interpolation-default.patch` | `libretro/libretro.cpp`: without a `snes9x_audio_interpolation` value the DSP uses Linear interpolation instead of Gaussian, which is cheaper on the device (128 fps with Linear against 121 with Gaussian at 1400 MHz). The LK always sets the option from its Audio Filter setting, so this is only the fallback. |
| `0002-run-ahead-raw-snapshot.patch` | `snapshot.cpp`: adds `S9xFreezeRunAhead` and `S9xUnfreezeRunAhead`, an in-memory snapshot of the same state as a save state, copied raw instead of serialised field by field into allocated big endian blocks, and holding only the cartridge's real SRAM size. Run ahead and rewind save and load every frame; on the device a save went from 1397 to 461 us and a load from 1442 to 475 us (Super Mario World). Not a portable format, so states on the card keep the normal one; carts with an enhancement chip report it unsupported and the LK uses the normal functions. |

## Building

Needs `arm-none-eabi-gcc` and `arm-none-eabi-g++` with newlib and libstdc++ (tested with
10.3-2021.07; on Ubuntu 22.04 the packages `gcc-arm-none-eabi`, `libnewlib-arm-none-eabi` and
`libstdc++-arm-none-eabi-newlib`), Python 3 and git.

```
git clone --recurse-submodules <this repository>   # or: git submodule update --init upstream
./build.sh
```

Output: `out/snes9x-pico.blob`, plus the ELF and a link map. The script prints the size, the
memory span with BSS and the SHA-256.

Build settings: ARMv8-A instruction selection tuned for the Cortex-A76, 32 bit, soft float (the
LK's calling convention, and no VFP or NEON registers the LK would have to save), freestanding C
and C++ without exceptions or RTTI, link time optimisation. Optimisation is chosen per file: the
code every frame runs through (CPU, DMA, PPU, memory map, SPC700 and DSP) at `-O2`, the rest at
`-Os` so the image stays small (it had to fit a 2 MB slot when the LK kept it on the eMMC), and `-O2` again for the link time pass. These are exactly the
flags, sources and link order the LK used when the core was built inside its tree, and the blob
is the one that build produced.

`EXTRA_PATCHES=/path/a.patch ./build.sh` applies more patches after `patches/` for experiments.

## Testing on a PC

`tools/host_test.cpp` builds the same patched sources natively (x86-64) and drives them through
the libretro API: it loads a ROM, runs frames, checks that the picture has a sane size and
changes, then that a save state and a run ahead snapshot taken and loaded each reproduce the same
next frame.

```
./build.sh                        # prepares out/src
tools/build_host_test.sh          # needs gcc and g++
tools/make_test_rom.py out/pico_test.sfc
out/host_test out/pico_test.sfc 600    # or any .sfc/.smc
```

## Installing

Copy `out/snes9x-pico.blob` to the SD card as `/cores/snes9x-pico.blob` (or unpack a release zip
and copy its `cores` folder to the root of the card). Super Nintendo games go in `/roms/snes`.

## How the LK uses it

- When a Super Nintendo game is started from the ROM selector, the LK reads
  `/cores/snes9x-pico.blob` from the card. It checks the 20 byte header (magic `0x31534E53`,
  "SNS1", ABI version 2; entry offset; bytes to load; span including BSS), copies the image to
  its fixed slot at 0x4F000000 (the slot ends at 0x4F800000), zeroes the BSS, cleans the data
  cache and invalidates the instruction cache over it, and calls the entry,
  `snes_core_blob_init`, with its imports (the pad state, the wall clock for S-RTC and BS-X
  carts). The entry returns the export table, which the LK checks again for magic and version.
- The LK then hands the core a heap in the shared emulator arena at 0x50000000 (`heap_init`,
  which zeroes it: Snes9x expects zeroed memory), calls `init` (which runs the C++ static
  constructors, now that `operator new` has memory), and loads the ROM from its own buffer
  (`load`). Each frame, `run` returns an RGB565 picture (256 or 512 wide) and the frame's audio.
- Battery saves are kept in `/saves/snes` (`.srm`), save states and the resume state in
  `/states/snes`. Run ahead and rewind use the raw snapshot (patch 0002) with a fallback to the
  normal save state, and skip the picture and sound of frames that are never shown
  (`set_av_skip`, through libretro's audio/video enable flags).
- The in-game Pico menu sets the core options it shows (aspect, overscan, audio filter, hi-res
  blending) through `set_option`, the libretro variables the core reads.

## Target notes for maintainers

- **The interface.** `pico/snes_core_abi.h` is the contract with the LK. Keep the copy here
  identical to the LK's, and the version in `pico/blob.ld`'s header equal to
  `SNES_CORE_ABI_VERSION`.
- **Memory.** Everything large (the ROM, Snes9x's RAM and VRAM, the APU RAM) is allocated from
  the arena the LK passes to `heap_init`. The allocator never frees; `heap_mark` and `heap_reset`
  let run ahead drop the temporary buffers the normal save state allocates. The LK calls
  `heap_init` again before every game.
- **Static constructors.** `.init_array` is kept and run from `init`, not from the blob entry: the
  constructors (libstdc++'s stream and locale objects, Snes9x's globals) allocate, and the heap
  only exists after `heap_init`.
- **No files.** The ROM arrives as a buffer and saves go through the core's memory interface, so
  the zip, VFS and stdio functions are stubs that fail (`pico/pico_stubs.c`).
- **Threads.** The LK runs the core on a thread of its own (deep C++ call chains need more stack
  than the emulator thread has) and drives one frame per `run`.
