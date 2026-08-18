# Sigil Factory

Factory × RTS × roguelite game prototype built with Godot 4 and GDScript.

The current design document is available at [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## Requirements

- Godot 4.3 or newer

## Run

1. Open this directory from the Godot Project Manager.
2. Import `project.godot` when prompted.
3. Press **F6** or **F5** to run the main scene.

The initial scene is an interactive glyph diagnostic sandbox. Use the controls to
change position, rotation, and color until the current glyph exactly matches the
target sigil.

## Tests

Run the domain tests with the Godot console executable:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path "C:\Users\sotaw\Documents\Projects\sigil-factory" `
  --script "res://tests/run_tests.gd"
```

Gameplay systems are implemented as deterministic simulation data separated from
rendering nodes.
