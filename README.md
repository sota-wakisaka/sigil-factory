# Sigil Factory

Factory × RTS × roguelite game prototype built with Godot 4 and GDScript.

The current design document is available at [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## MVP features

- Click-through run flow from route selection to the next route
- Deterministic fixed-tick glyph factory simulation
- Three production plans: fast scouts, anti-swarm sentinels, and anti-armor golems
- Transactional factory changes made during time stop
- One-dimensional automatic battle with unit roles, lifetimes, and leader objectives
- 60-second enemy threat forecast across a ten-minute encounter
- Victory, reward, next-route, defeat, and instant retry flow

The route selection, stage information, and reward screens are intentionally
content-free placeholders. They make the complete game progression testable
before content production begins.

The intended strategy is to start with scouts, switch to sentinels for the swarm
phase, and finish with golems against armored enemies. Balance validation ensures
that adaptive production wins while scout-only and golem-only production do not.

## Requirements

- Godot 4.3 or newer

## Run

1. Open this directory from the Godot Project Manager.
2. Import `project.godot` when prompted.
3. Press **F6** or **F5** to run the main scene.

Follow the highlighted progression bar from **Route Selection**. At the factory
step, choose a production plan and press **Build Complete / Start Battle**.
During battle, press **Time Stop**, select a production plan, then confirm the
change. Preview changes do not affect the running factory until committed. Use
the temporary **Complete Battle** button to inspect the victory, reward, and
next-route screens without waiting for the simulation to finish.

## Tests

Run the domain tests with the Godot console executable:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path "C:\Users\sotaw\Documents\Projects\sigil-factory" `
  --script "res://tests/run_tests.gd"
```

Run the ten-minute balance simulation with:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path "C:\Users\sotaw\Documents\Projects\sigil-factory" `
  --script "res://tests/simulate_mvp.gd"
```

Run the click-through progression test with:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path "C:\Users\sotaw\Documents\Projects\sigil-factory" `
  --script "res://tests/run_flow_ui_tests.gd"
```

Gameplay systems are implemented as deterministic simulation data separated from
rendering nodes.
