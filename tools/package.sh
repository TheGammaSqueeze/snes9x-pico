#!/bin/bash
# Copyright (c) 2026 TheGammaSqueeze. Distributed under the Snes9x licence (LICENSE).
# Package a built blob for release (run ./build.sh first):
#
#   tools/package.sh            -> dist/snes9x-pico-<version>.zip
#                                  dist/snes9x-pico-<version>-src.tar.gz
#
# The zip is what goes on the SD card plus the licence texts: cores/snes9x-pico.blob, LICENSE (the
# Snes9x licence, which must go with every copy), THIRD_PARTY_NOTICES.md and licenses/ (the
# LGPL 2.1 text upstream ships for the NTSC filter and the DSP and, when the toolchain ships them,
# the copyright files of newlib and libstdc++). The source archive is this repository and the
# upstream submodule at the commit the blob was built from.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -f out/snes9x-pico.blob ] || { echo "out/snes9x-pico.blob missing: run ./build.sh first" >&2; exit 1; }

VER=${VERSION:-$(git describe --tags --always --dirty 2>/dev/null || echo unknown)}
NAME=snes9x-pico-$VER
PKGDIR=dist/$NAME
rm -rf "$PKGDIR" "dist/$NAME.zip" "dist/$NAME-src.tar.gz"
mkdir -p "$PKGDIR/cores" "$PKGDIR/licenses"

cp out/snes9x-pico.blob "$PKGDIR/cores/"
cp LICENSE THIRD_PARTY_NOTICES.md README.md "$PKGDIR/"
cp upstream/filter/snes_ntsc-license.txt "$PKGDIR/licenses/LGPL-2.1.txt"
for pkg in libnewlib-arm-none-eabi:newlib libstdc++-arm-none-eabi-newlib:libstdc++; do
	doc=/usr/share/doc/${pkg%%:*}/copyright
	if [ -f "$doc" ]; then
		cp "$doc" "$PKGDIR/licenses/${pkg##*:}-COPYRIGHT.txt"
	else
		echo "note: $doc not found; see THIRD_PARTY_NOTICES.md" >&2
	fi
done
(cd "$PKGDIR/cores" && sha256sum snes9x-pico.blob > snes9x-pico.blob.sha256)
{
	echo "snes9x-pico $VER"
	echo "upstream libretro/snes9x $(git -C upstream rev-parse HEAD)"
	echo "toolchain $(${CC:-arm-none-eabi-gcc} --version | head -1)"
	echo "blob sha256 $(cut -d' ' -f1 "$PKGDIR/cores/snes9x-pico.blob.sha256")"
} > "$PKGDIR/BUILD_INFO.txt"
(cd dist && rm -f "$NAME.zip" && zip -qr "$NAME.zip" "$NAME")

# the source: every tracked file, the submodule's included
git ls-files --recurse-submodules -z | tar --null -czf "dist/$NAME-src.tar.gz" --transform "s,^,$NAME-src/," -T -

echo "dist/$NAME.zip"
echo "dist/$NAME-src.tar.gz"
