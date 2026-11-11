#!/usr/bin/env python3
# Copyright (c) 2026 TheGammaSqueeze. Distributed under the Snes9x licence (LICENSE).
# Writes a 32 KiB LoROM test cartridge for tools/host_test.cpp, so the core can be checked
# without a commercial game (CI uses it):
#
#   tools/make_test_rom.py out/pico_test.sfc
#
# The program turns the screen on, then once a frame writes a new backdrop colour (an 8 bit
# counter, written as both bytes of colour 0) and waits for the next vertical blank. Every frame
# looks different, which is what the host test's picture and save state checks need.
import sys

PROGRAM = bytes([
    0x78,                    # sei
    0x18,                    # clc
    0xFB,                    # xce              native mode, 8 bit A and X
    0xA9, 0x0F,              # lda #$0f
    0x8D, 0x00, 0x21,        # sta $2100        screen on, full brightness
    # frame loop (offset 8)
    0x9C, 0x21, 0x21,        # stz $2121        colour 0
    0xE8,                    # inx
    0x8A,                    # txa
    0x8D, 0x22, 0x21,        # sta $2122        low byte
    0x8D, 0x22, 0x21,        # sta $2122        high byte
    0xAD, 0x12, 0x42,        # lda $4212
    0x10, 0xFB,              # bpl -5           until vertical blank starts
    0xAD, 0x12, 0x42,        # lda $4212
    0x30, 0xFB,              # bmi -5           until it ends
    0x80, (8 - 31) & 0xFF,   # bra frame loop
])


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: make_test_rom.py <out.sfc>")
    rom = bytearray(0x8000)
    rom[0:len(PROGRAM)] = PROGRAM
    rom[0x7FC0:0x7FD5] = b"SNES9X-PICO TEST".ljust(21, b" ")
    rom[0x7FD5] = 0x20       # LoROM
    rom[0x7FD6] = 0x00       # ROM only
    rom[0x7FD7] = 0x05       # 32 KiB
    rom[0x7FD8] = 0x00       # no SRAM
    rom[0x7FD9] = 0x01       # North America (NTSC)
    rom[0x7FDA] = 0x33
    rom[0x7FDB] = 0x00
    rom[0x7FEA:0x7FEC] = b"\x00\x80"   # native NMI (never enabled)
    rom[0x7FFC:0x7FFE] = b"\x00\x80"   # reset -> $8000
    # checksum and its complement, computed with the complement fields at $ffff/$0000
    rom[0x7FDC:0x7FE0] = b"\xff\xff\x00\x00"
    s = sum(rom) & 0xFFFF
    rom[0x7FDC:0x7FDE] = (s ^ 0xFFFF).to_bytes(2, "little")
    rom[0x7FDE:0x7FE0] = s.to_bytes(2, "little")
    with open(sys.argv[1], "wb") as f:
        f.write(rom)


if __name__ == "__main__":
    main()
