# Sigil Factory

Factory × RTS × roguelite game prototype built with Godot 4 and GDScript.

Design documents:

- [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) — overall design and MVP scope
- [`docs/SIGIL_SPEC.md`](docs/SIGIL_SPEC.md) — glyph structure, normalization, matching, and evolution
- [`docs/FACTORY_SPEC.md`](docs/FACTORY_SPEC.md) — factory nodes, routing, blocking, and editing
- [`docs/ROGUELITE_SPEC.md`](docs/ROGUELITE_SPEC.md) — route rewards, progression, and enemy summons

## MVP features

- Click-through run flow from route selection to the next route
- Draggable factory equipment with interactive input/output port wiring
- Equipment palette for adding and deleting sources, processors, combiners, and summoners
- Fixed 100-mana equipment capacity with immediate refunds when nodes are removed
- A single generic summoner enforced by both palette actions and graph validation
- Selection inspector for source material, rotation, and color configuration
- Deterministic fixed-tick glyph factory simulation
- Canonical binary Combine structure with hierarchy-aware sigil matching
- Unique recipe IDs and canonical structures with acquisition-order-independent registration
- Completed-sigil ghost preview for the currently selected production plan
- Pre-battle production preview with the closest recipe and first mismatch correction
- Production provenance for processing count, traversed node kinds, and source IDs
- Quarter-turn normalization of orientation and root-relative position, plus rejection of fully overlapping primitives
- Tick-start input and line snapshots that prevent same-tick cascading or slot reuse
- Three production plans: fast scouts, anti-swarm sentinels, and anti-armor golems
- Transactional factory changes made during time stop
- Work-in-progress discard preview with glyph-type summaries, full undo, and cancel restoration
- Player-facing summon mismatch reasons based on the closest known recipe
- Successful summon feedback that replaces stale mismatch messages after recovery
- Distinct input-full, output-blocked, and missing-material factory warnings
- One-second minimum hold time for transient factory warning text
- Direction arrows and blockage coloring on factory transport lines
- One-dimensional automatic battle with unit roles, lifetimes, and leader objectives
- Per-side 48-unit and eight-spawns-per-tick safety limits with visible rejection counts
- 24-second enemy threat forecast across a three-minute standard encounter
- 60-second advance warnings for major swarm, armor, and final wave changes
- Victory, reward, next-route, defeat, and instant retry flow
- Persistent run rewards for source, processor, or transport speed
- Wave labels, matchup guidance, hit feedback, and post-battle analysis
- Defeat advice classified from summon output, mismatches, reconfiguration, and missing counters
- Before/after production impact shown when battle resumes
- Fifteen-second post-change observation of enemy kills, allied losses, and objective damage

The MVP now preserves glyph production provenance through transport, processing,
copying, and Combine operations. Provenance is exposed on summon events for future
relic effects but does not affect structural sigil matching.

Route selection currently offers three placeholder branches that share the same
battle. The stage briefing, reward choice, reward persistence, and next-route
loop are functional; route-specific encounters remain future content.

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
Select a source, rotator, or colorizer to change its setting in the inspector.
While editing, a non-destructive 32-second simulation preview reports expected
scout, sentinel, and golem output plus unmatched glyphs. When the preview finds
a rejected glyph, it also names the closest known sigil and its highest-priority
correction before battle begins.

During production, rejected glyphs report actionable structural differences such
as missing parts, rotation, or color. Factory equipment and lines also distinguish
missing combiner material, full target buffers, and blocked outputs. Time-stop
edits list the count, processed type, and affected equipment or transport line
for work in progress that will be discarded before the change is committed.
After a committed reconfiguration resumes battle, a 15-second observation window
records enemy defeats, allied losses, and damage dealt to the shield or leader so
the player can compare the production prediction with the immediate battle result.

The first factory step opens an unwired workshop containing a ring source and a
summoner. Connecting its two highlighted ports produces the first scout. The
three completed production plans remain available as reference templates.

Press **Build Complete / Start Battle** when the graph is ready.
During battle, press **Time Stop**, select a production plan, then confirm the
change. Preview changes do not affect the running factory until committed. The
**Fast Forward** button cycles between 1x, 2x, and 4x battle speed and is disabled
during time stop. Use **検証用: 戦闘をスキップ** only when you need to inspect
the victory, reward, and next-route screens without waiting for the simulation
to finish; it is not part of the intended battle controls.

Keyboard shortcuts: **Space** starts, stops, or resumes battle; **F** changes
battle speed; **Ctrl+Z** undoes an edit; **Delete** removes selected equipment;
and **0–3** select factory templates.

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
