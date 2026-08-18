# Sigil Factory

Factory × RTS × roguelite game prototype built with Godot 4 and GDScript.

The current design document is available at [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## MVP features

- Click-through run flow from route selection to the next route
- Draggable factory equipment with interactive input/output port wiring
- Equipment palette for adding and deleting sources, processors, combiners, and summoners
- Deterministic fixed-tick glyph factory simulation
- Three production plans: fast scouts, anti-swarm sentinels, and anti-armor golems
- Transactional factory changes made during time stop
- One-dimensional automatic battle with unit roles, lifetimes, and leader objectives
- 24-second enemy threat forecast across a three-minute standard encounter
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
step, choose a production plan as a starting template or customize it with the
equipment palette. Drag equipment to reposition it, click a filled output port
and then an outlined input port to connect them, and right-click an input port to
disconnect it. Select equipment before pressing **Delete**. Incomplete factories
cannot start and display the first missing connection. **Undo** restores placement,
wiring, additions, and deletions made during the current edit session.
While editing, a non-destructive 32-second simulation preview reports expected
scout, sentinel, and golem output plus unmatched glyphs.

Press **Build Complete / Start Battle** when the graph is ready.
During battle, press **Time Stop**, select a production plan, then confirm the
change. Preview changes do not affect the running factory until committed. The
**Fast Forward** button cycles between 1x, 2x, and 4x battle speed and is disabled
during time stop. Use the temporary **Complete Battle** button to inspect the
victory, reward, and next-route screens without waiting for the simulation to
finish.

## Tests

Run the domain tests with the Godot console executable:

```powershell
& "C:\Program Files\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe" `
  --headless `
  --path "C:\Users\sotaw\Documents\Projects\sigil-factory" `
  --script "res://tests/run_tests.gd"
```

Run the three-minute balance simulation with:

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
