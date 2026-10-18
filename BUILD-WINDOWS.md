# How to Build DVDStyler on Windows

The recommended Windows workflow is MSYS2 with a 64-bit MinGW toolchain.

## 1 Install MSYS2

Install MSYS2 from https://www.msys2.org/ and complete the post-install update flow.

After installation, open an `MSYS2 UCRT64` shell for 64-bit builds.

## 2 Install Toolchain And Build Tools

Install MinGW-w64 C/C++ and core build tooling with pacman:

```bash
pacman -Syu
pacman -S --needed base-devel git autoconf automake libtool bison flex pkgconf gettext xmlto docbook-xsl zip unzip
pacman -S --needed mingw-w64-ucrt-x86_64-toolchain
```

Notes:

- `mingw-w64-ucrt-x86_64-toolchain` provides GCC/G++ (C/C++ compiler toolchain).
- If you prefer the MINGW64 environment, use the corresponding `mingw-w64-x86_64-*` package names instead.

## 3 Install DVDStyler Build Dependencies

Use the package set that matches your selected shell environment.

### UCRT64 package set

Run this in an `MSYS2 UCRT64` shell. This is the set CI builds with (see `.github/workflows/ci.yml`):

```bash
pacman -S --needed \
	mingw-w64-ucrt-x86_64-wxwidgets3.2-msw \
	mingw-w64-ucrt-x86_64-wxsvg \
	mingw-w64-ucrt-x86_64-ffmpeg \
	mingw-w64-ucrt-x86_64-libexif \
	mingw-w64-ucrt-x86_64-libjpeg-turbo \
	mingw-w64-ucrt-x86_64-fontconfig \
	mingw-w64-ucrt-x86_64-cairo \
	mingw-w64-ucrt-x86_64-pango
```

### MINGW64 package set (not verified)

Run this in an `MSYS2 MINGW64` shell:

```bash
pacman -S --needed \
	mingw-w64-x86_64-wxwidgets3.2-msw \
	mingw-w64-x86_64-wxsvg \
	mingw-w64-x86_64-ffmpeg \
	mingw-w64-x86_64-libexif \
	mingw-w64-x86_64-libjpeg-turbo \
	mingw-w64-x86_64-fontconfig \
	mingw-w64-x86_64-cairo \
	mingw-w64-x86_64-pango
```

Notes:

- Do not mix UCRT64 and MINGW64 package prefixes in the same shell.
- `libudev`, `libdbus`, and GNOME thumbnail helpers are optional and not used on Windows.
- The MSYS2 wxWidgets build does not include the generic colour dialog, so the colour picker falls back to the native Windows dialog, which cannot edit alpha.

### 3.1 Runtime tools (dvdauthor, mkisofs, growisofs)

`configure` requires `dvdauthor`, `mkisofs` (cdrtools) and `growisofs` (dvd+rw-tools) to be on `PATH`, but **MSYS2 does not package any of them**. They are only invoked at runtime, so for a build-only check you can put stub scripts on `PATH` (this is what CI does):

```bash
mkdir -p ~/stubs
for t in dvdauthor mkisofs growisofs; do
	printf '#!/bin/sh\nexit 1\n' > ~/stubs/$t && chmod +x ~/stubs/$t
done
export PATH="$PATH:$HOME/stubs"
```

For a working application, install Windows builds of these tools and put them on `PATH` instead.

## 4 Build DVDStyler

From the repository root in the same MinGW shell:

```bash
./autogen.sh
./configure
make -j$(nproc)
```

If `configure` cannot find `wx-config`, pass it explicitly: `./configure --with-wx-config=$(command -v wx-config-3.2)`.

On MinGW, `configure` compiles as C++14 (C++17's `std::byte` clashes with the Windows `byte` type) and links `ole32` and `uuid`.

## 4.1 Portable Package

`.github/scripts/package-windows.sh [output-dir]` builds `DVDStyler-<version>-win64-portable.zip`, which CI uploads and attaches to releases. It stages `make install`, puts `dvdstyler.exe`, `ffmpeg.exe` and every DLL they load from `$MINGW_PREFIX/bin` into `bin\`, places the data directories, translations and fontconfig configuration next to it, and fails if any DLL would still resolve from MSYS2. It needs `mingw-w64-ucrt-x86_64-ntldd`.

The package does not include dvdauthor, spumux, mkisofs or growisofs, so authoring, ISO creation and burning do not work with it yet.

## 5 Validate Build Output

- Confirm `configure` detects wxWidgets, ffmpeg/libav, wxSVG with ffmpeg support, libexif, and fontconfig.
- Confirm `src/dvdstyler.exe` is produced without link errors.
- Run a basic smoke test: launch app, open a sample project, preview menu/video, and run a non-burning authoring path.

## TODO (Windows docs)

- Verify the MINGW64 package set.
- Document where to get Windows builds of dvdauthor, cdrtools and dvd+rw-tools.
- Document runtime DLL packaging strategy for distributable artifacts.
- Add troubleshooting notes for path conversion, `pkg-config`, and mixed-shell environment issues.
