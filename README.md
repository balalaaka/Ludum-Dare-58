# Export Project

A minimal LOVE2D project template created from the Ludum Dare 57 build system.

## Files

- `main.lua` - Main game logic (minimal example)
- `conf.lua` - LOVE2D configuration
- `build.bat` - Build script to create executable and zip
- `README.md` - This file

## Building

### Desktop Build
Run `build.bat` to create:
- Executable in `bin/export.exe`
- Distribution zip file `export.zip`

### Web Build
Run `build_web.bat` to create:
- Web files in `web/` folder
- Itch.io package `export_web.zip`
- Canvas dimensions set to 520x800 for Ludum Dare compatibility

## Requirements

- LOVE2D installed with `love.exe` in the parent directory
- Windows build environment

## Usage

1. Edit `main.lua` to implement your game
2. Modify `conf.lua` for window settings and other configuration
3. Run `build.bat` to build your project
