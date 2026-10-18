DVDStyler portable build for Windows (64-bit)
==============================================

Unzip anywhere and run bin\dvdstyler.exe. Nothing is installed; settings are
stored in DVDStyler.ini in this folder.

Limitations of this build
-------------------------

This is an early, unsigned build produced by CI from MSYS2 packages.

* DVD authoring, ISO creation and burning do not work yet. They need the
  external tools dvdauthor, spumux, mkisofs and growisofs, which are not
  included. Editing projects and menus and previewing work. If you have
  Windows builds of these tools, place them in the bin folder.
* The colour picker cannot edit transparency (alpha) on Windows.
* Windows SmartScreen may warn because the executable is not signed.

Please report problems at https://github.com/thalter/DVDStyler-Official/issues
