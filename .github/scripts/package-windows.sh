#!/bin/sh
# Assemble a portable Windows build. Run from the repository root in an MSYS2
# UCRT64 shell after ./configure && make.
#
# The layout follows installer/DVDStyler.iss: executables and DLLs in bin\,
# data directories one level up, because the application looks for its data
# next to the executable and then in the parent directory.
#
# Usage: package-windows.sh [output-dir]
# Prints the path of the created zip on the last line of stdout.
set -eu

: "${MINGW_PREFIX:?run this in an MSYS2 MinGW shell}"
OUT=$(cd "${1:-.}" && pwd)
VERSION=$(sed -n 's/^AC_INIT(\[DVDStyler\],\[\([^]]*\)\].*/\1/p' configure.ac)
[ -n "$VERSION" ] || { echo "cannot read version from configure.ac" >&2; exit 1; }
NAME=DVDStyler-$VERSION-win64-portable

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
STAGE=$WORK/install
ROOT=$WORK/$NAME

make install DESTDIR="$STAGE" >/dev/null
PREFIX=$(sed -n 's/^prefix = //p' Makefile)

mkdir -p "$ROOT/bin" "$ROOT/etc"
cp "$STAGE$PREFIX/bin/dvdstyler.exe" "$MINGW_PREFIX/bin/ffmpeg.exe" "$ROOT/bin/"
cp -R "$STAGE$PREFIX/share/dvdstyler/." "$ROOT/"
cp -R "$STAGE$PREFIX/share/locale" "$ROOT/locale"
# fontconfig locates its configuration relative to its DLL (..\etc\fonts).
cp -R "$MINGW_PREFIX/etc/fonts" "$ROOT/etc/"
cp COPYING ChangeLog README "$ROOT/"
cp installer/README-windows-portable.txt "$ROOT/README-Windows.txt"

NTLDD=$MINGW_PREFIX/bin/ntldd.exe

# Turn ntldd -R output into one Unix path per resolved DLL.
resolved() {
	tr -d '\r' | sed -n 's/.* => \(.*\) (0x[0-9a-fA-F]*)$/\1/p' |
		while read -r p; do cygpath -u "$p"; done
}

# Bundle every DLL resolved from the MinGW prefix. Repeat until nothing new is
# found, since DLLs copied in one pass may pull in more.
for _ in 1 2 3 4 5; do
	NEW=$("$NTLDD" -R "$ROOT"/bin/*.exe "$ROOT"/bin/*.dll 2>/dev/null | resolved |
		grep -i "^$MINGW_PREFIX/bin/" | sort -u |
		while read -r dll; do
			[ -e "$ROOT/bin/$(basename "$dll")" ] || echo "$dll"
		done)
	[ -n "$NEW" ] || break
	echo "$NEW" | while read -r dll; do cp "$dll" "$ROOT/bin/"; done
done

# Every dependency must now resolve inside the package or to Windows itself.
# Check with a PATH that excludes MSYS2 so nothing resolves from the build tree.
# API-set names (api-ms-win-*, ext-ms-*) are resolved by the loader, not files.
CHECK=$(PATH=/c/Windows/System32:/c/Windows "$NTLDD" -R "$ROOT"/bin/*.exe | tr -d '\r')
[ -n "$CHECK" ] || { echo "ntldd produced no output" >&2; exit 1; }
MISSING=$(echo "$CHECK" | grep -Ev '^[[:space:]]*(api|ext)-ms-' | grep -i 'not found' || true)
LEAKED=$(echo "$CHECK" | resolved | grep -i "^$MINGW_PREFIX/" || true)
if [ -n "$MISSING$LEAKED" ]; then
	echo "DLLs missing from the package:" >&2
	printf '%s\n' "$MISSING" "$LEAKED" | sed '/^$/d' >&2
	exit 1
fi
echo "Bundled $(find "$ROOT/bin" -name '*.dll' | wc -l) DLLs; $(du -sh "$ROOT" | cut -f1) unpacked" >&2

(cd "$WORK" && zip -qr -9 "$OUT/$NAME.zip" "$NAME")
echo "$OUT/$NAME.zip"
