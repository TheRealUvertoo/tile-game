# CLAUDE.md — AI Assistant Guide

## Project Overview
**Tile Wilds** — Cozy tile placement game in Godot 4.6.
Place groups of 1-3 tiles on a square grid, rotate the group, score by adjacency matching.
3 terrain types, hand-based selection, tile merging, cozy gameplay.
Art direction: TBD (exploring oil painting / paper diorama / pastel on cardboard styles).

## Tech Stack
- **Engine:** Godot 4.6 (Forward+, D3D12, Jolt Physics)
- **Language:** GDScript
- **Rendering:** Scene-based tiles (TileBase + colored BoxMesh), prototype state — no art assets yet
- **Resolution:** 2560x1440

## Architecture

### Core Pattern: Data → Group → Hand → Grid → Visual
```
TileData (single terrain type per cell)
  → TileGroup (1-3 tiles with shape + rotation)
    → HandManager (hand of 3 groups, pick one at a time)
      → TileGrid (square grid, group placement, tile merging)
        → TileBase (scene-based tile with grass + decorations)
      → TileScoring (adjacency matching, merge deduplication)
      → GroupTracker (BFS flood-fill)
      → QuestManager (quest tracking)
      → MysteryTileManager (fog-of-war discovery tiles)
      → TileAgingManager (tiles grow taller over turns)
```

### Directory Structure
```
scripts/
├── core/           # Grid, placement, camera, scoring, deck, tile group, hand, main, tile base,
│                   # mystery tiles, tile aging, quest manager
├── components/     # Ground plane, tilt-shift, sprite tint, decoration scatterer
├── data/           # QuestData resource
├── ui/             # Game UI, hand UI, floating text, debug UI
└── util/           # SignalBus (autoload)
scenes/
└── tiles/          # forest_tile, clearing_tile, rocks_tile + merged variants (prototype BoxMesh)
shaders/
├── prototype_tile.gdshader  # Colored tile + terrain pattern + neighbor glow/mix
├── tilt_shift.gdshader      # Post-process diorama DoF
└── sprite_tint.gdshader     # Brightness/tint for Sprite3D
```

### Key Classes
| Class | File | Role |
|-------|------|------|
| `TileData` | `scripts/core/tile_data.gd` | Single terrain type per cell, TerrainType enum, DIRECTIONS (4 cardinal), TERRAIN_COLORS |
| `TileGroup` | `scripts/core/tile_group.gd` | 1-3 tiles with shape (offsets), rotation, 90° CW rotation math |
| `TileGrid` | `scripts/core/tile_grid.gd` | Square grid placement, tile merging (2×2), placed_tiles, merged_tiles, scene instantiation |
| `TileBase` | `scripts/core/tile_base.gd` | Tile scene root: billboard sprites, appear animation (rise + decoration pop) |
| `TilePlacement` | `scripts/core/tile_placement.gd` | Group preview with full tile scenes, R-key rotation, slot markers, LMB place, invalid tint |
| `HandManager` | `scripts/core/hand_manager.gd` | Hand of 3 groups from deck, pick-one-at-a-time, auto-redraw when hand empty |
| `HandUI` | `scripts/ui/hand_ui.gd` | Bottom-center hand bar, clickable slots, terrain-colored shape preview |
| `TileDeck` | `scripts/core/tile_deck.gd` | Random group gen (shape + terrain per member), quest attachment (~20%) |
| `TileScoring` | `scripts/core/tile_scoring.gd` | +10 per same-terrain neighbor, +30 perfect bonus, merge deduplication |
| `GroupTracker` | `scripts/core/group_tracker.gd` | BFS flood-fill: get_group_size() + get_group_cells() |
| `QuestManager` | `scripts/core/quest_manager.gd` | Dorfromantik-style: max 3 active quests, auto-gen when slots empty, BFS checks |
| `QuestData` | `scripts/data/quest_data.gd` | Resource: terrain_type, target_group_size, rewards |
| `MysteryTileManager` | `scripts/core/mystery_tile_manager.gd` | Gray fog tiles spawn near frontier, discover on connect for points |
| `TileAgingManager` | `scripts/core/tile_aging_manager.gd` | Tiles grow taller after turns, bounce animation |
| `CameraController` | `scripts/core/camera_controller.gd` | Orbit camera with dynamic pitch, DoF, smooth movement |
| `Main` | `scripts/core/main.gd` | Game loop: hand → place → score → quests → mystery → aging → next |
| `FloatingText` | `scripts/ui/floating_text.gd` | 2D score popup that rises and fades |
| `SignalBus` | `scripts/util/signal_bus.gd` | Central signal hub (autoload) |

### Grid Math: Square Grid
- Stored as `Vector2i(x, y)` — simple integer coordinates
- 4 cardinal directions: E(+1,0), N(0,-1), W(-1,0), S(0,+1)
- `grid_to_world`: `Vector3(x * tile_size, 0, y * tile_size)`
- `world_to_grid`: `Vector2i(roundi(world.x / tile_size), roundi(world.z / tile_size))`

### Terrain Types
```gdscript
enum TerrainType { FOREST, CLEARING, ROCKS, WATER, DESERT, SWAMP, MOUNTAIN, MEADOW, TUNDRA, VILLAGE, RIVER }
```
- **Forest** — dark green, triangle pattern
- **Clearing** — light green, circle pattern
- **Rocks** — gray-brown, diamond pattern
- **Water** — deep blue, wave pattern (mystery-tile exclusive)
- **Desert** — warm sand, dune ripple pattern
- **Swamp** — dark olive, blob/puddle pattern
- **Mountain** — slate blue, zigzag peak pattern
- **Meadow** — golden yellow, cross/flower pattern
- **Tundra** — icy cyan, scattered dot pattern
- **Village** — terracotta, hollow square pattern
- **River** — bright blue, flowing S-curve pattern (+5 bonus per river neighbor, -5 if isolated)

### TileGroup System
- Each tile = ONE terrain type (no per-edge subdivision)
- Groups of 1-3 tiles placed together
- 5 group shapes: SINGLE, DUO_LINE, TRIO_LINE, TRIO_TRIANGLE, TRIO_ANGLE
- Shape defined as (x,y) offsets from pivot (0,0)
- Rotation: rotates all offsets around pivot — CW step: `(x,y) → (-y, x)`
- R key rotates entire group 90°, updates preview immediately

### Hand System
- Player draws a hand of 3 groups from the deck
- Click a slot in the bottom UI bar to select a group for placement
- After placing, the slot is consumed (nulled)
- When all 3 slots are used, a new hand is drawn after a short delay (0.15s)
- Signals: `hand_changed`, `hand_slot_selected`, `hand_slot_used`, `hand_slot_clicked`

### Tile Merging (2×2 → Big Tile)
- When 4 tiles of the same terrain form a 2×2 square, they merge automatically
- Old 4 tiles: visuals shrink to zero and are destroyed
- New merged tile: scene spawned centered on the 2×2 block
- All 4 cells remain in `placed_tiles` (for placement blocking and BFS)
- `merged_tiles` dict maps each cell → anchor (top-left of 2×2)
- `_merged_visuals` dict maps anchor → Node3D (merged scene)
- For scoring: merged tile counts as **1 neighbor** (not 4), deduplicated via `seen_anchors`
- Merged scenes: `scenes/tiles/merged_*.tscn` — 2× size BoxMesh
- Merge detection: after each group placement, check all 4 possible 2×2 squares per new cell

### Mystery Tiles
- Gray "fog" tiles with "?" spawn near the map frontier
- 40% chance per placement, max 8 on map, 3 initial
- When player places adjacent to mystery tile → auto-discovered
- Discovery: random terrain revealed, +15 points, appear animation
- Blocks valid_positions (can't place on top)
- Can trigger merges after discovery

### Tile Aging
- After each full turn (3 placements = full hand cycle), some tiles age
- 30% chance per tile per turn, max 3 age levels
- Aging: tile jumps up with bounce animation, returns taller
- BoxMesh.size.y increases per age level
- Mesh duplicated per tile to avoid sharing issues

### SignalBus (Autoload)
All module communication via signals — zero direct coupling:
- `group_selected(group)` — HandManager → TilePlacement
- `group_placed(cells, tiles)` — TileGrid → Main, QuestManager, MysteryManager
- `score_earned(total, delta, result)` — Main → UI
- `tiles_merged(cells, terrain)` — TileGrid → (observers)
- `quest_started/progressed/completed(quest)` — QuestManager → UI
- `stack_changed(remaining)` — Main → UI
- `game_ended(final_score)` — Main → UI
- `mystery_tile_spawned(cell)` — MysteryManager → TilePlacement
- `mystery_tile_discovered(cell, terrain, points)` — MysteryManager → Main, UI
- `hand_changed(hand)` — HandManager → HandUI
- `hand_slot_selected(index)` — HandManager → HandUI
- `hand_slot_used(index)` — HandManager → HandUI
- `hand_slot_clicked(index)` — HandUI → HandManager
- `camera_rotated(yaw)` — CameraController → (sprites)

### Scoring System (Adjacency-Based)
- **Same-terrain neighbor**: +10 pts per adjacent cell with same terrain
- **Perfect placement**: All 4 neighbors are same terrain → +30 bonus + 1 extra group
- **Merged tile deduplication**: A merged tile touching multiple sides counts as 1 neighbor only
- **Mystery tile discovery**: +15 pts per discovered tile
- **Quest completion**: bonus groups + bonus score
- Score computed by static `TileScoring.score_group()` after each group placement
- 3D floating Label3D shows score at tile position

### Quest System (Dorfromantik-style)
- Max 3 active quests simultaneously
- ~20% of groups carry a quest (generated in TileDeck)
- Auto-generated quests fill empty slots (after 2s delay)
- Quest: "build [terrain] group of [N]+" (e.g., "Forest group of 10+")
- Auto-quest target = largest existing group + 3-8 (challenging but achievable)
- Group size tracked via BFS flood-fill (`GroupTracker.get_group_size()`)
- Completion rewards: bonus groups + bonus score
- UI: color-coded quest cards with progress bar, reward preview

### Finite Stack
- Currently set to 9999 (effectively infinite — no game over yet)
- Perfect placements add +1 group
- Quest completions add +N groups (varies)
- Game ends when stack = 0

## Important Conventions

### Zero Hardcoding
- ALL numeric values, colors, durations → `@export` or constants
- Terrain colors defined in `TileData.TERRAIN_COLORS` dictionary

### Scene-Based Tiles
- Each terrain has a `.tscn` scene (regular + merged variant)
- Scene structure: root Node3D (TileBase) → TileMesh (MeshInstance3D + GrassLayer) → Decorations (Sprite3D children)
- `TileBase` script handles billboard setup and appear animation
- Merged tiles are 2× size with more instances/decorations

### Preview System
- Previews instantiate real tile scenes (same as placed tiles)
- `_animation_played = true` set BEFORE `add_child()` so decorations show immediately
- Invalid placement: tiles stay visible but get red tint via `material_overlay`
- Tint state cached (`_last_tint_valid`) to avoid per-frame recursive tree traversal
- `_tint_recursive()` sets `material_overlay` on MeshInstance3D, `modulate` on Sprite3D

### Materials
- TilePlacement shares 2 materials (`_mat_neutral`, `_mat_valid`) for all slot markers
- Preview invalid tint uses a single shared `StandardMaterial3D` overlay
- Tile meshes use ShaderMaterial (prototype_tile shader) — `material_overlay` works with any material type
- Billboard sprites (`BILLBOARD_FIXED_Y`) always face camera around Y axis

### Prototype Tile Shader
- `shaders/prototype_tile.gdshader` — colored tiles with terrain-specific patterns
- Uniforms: tile_color, terrain_type (0=forest triangles, 1=clearing circles, 2=rocks diamonds)
- Neighbor uniforms: neighbor_e/n/w/s (bool) + neighbor_*_color (vec4) + neighbor_*_same (bool)
- Edge glow when same-terrain neighbors match (uses bool uniforms, NOT color comparison)
- Cross-terrain interaction glow (subtle bright line between different terrains)
- Color mixing at edges from neighbor influence (increased strength for visibility)
- Grid lines at tile borders

### Group Placement Flow
1. `HandManager.draw_hand()` draws 3 groups → `hand_changed` signal
2. Player clicks slot → `hand_slot_clicked` → `group_selected` signal
3. TilePlacement receives group, shows slot markers, creates preview visuals (real tile scenes)
4. Mouse hover → raycast to ground plane → `world_to_grid()` → group preview at pivot cell
5. R key → `rotate_cw()` → all offsets rotate 90°, preview rebuilds
6. LMB → `TileGrid.try_place_group()` → places all tiles → `group_placed` signal
7. MysteryTileManager discovers adjacent mystery tiles
8. Grid checks for 2×2 merges → `tiles_merged` if applicable
9. Main scores group placement → `score_earned` signal + 3D Label3D popup
10. QuestManager checks all active quests → completion if target met
11. Hand slot consumed → if all 3 slots used: turn++, tile aging, new hand drawn

### Camera System
- **Orbit:** E/Q = snap-rotate 90°, WASD = pan, MMB = pan, Scroll = zoom
- **Dynamic pitch:** zoom in → more into scene (~-20°), zoom out → more top-down (~-40°)
- **Depth of Field:** blur increases with zoom distance
- **Smooth movement:** exponential smoothing on WASD, zoom, and pan

### Shaders
| Shader | File | Purpose |
|--------|------|---------|
| PrototypeTile | `shaders/prototype_tile.gdshader` | Colored tile + terrain pattern + neighbor interaction |
| SpriteTint | `shaders/sprite_tint.gdshader` | Brightness/tint for Sprite3D |
| TiltShift | `shaders/tilt_shift.gdshader` | Zoom-driven tilt-shift blur |

## Common Pitfalls
1. **ShaderMaterial vs StandardMaterial3D**: Tile meshes use ShaderMaterial — use `material_overlay` for universal tinting
2. **_animation_played order**: Set `_animation_played = true` BEFORE `add_child()` — `_ready()` runs during `add_child()`
3. **@tool scripts**: GrassLayer is @tool — density setters gate on `Engine.is_editor_hint()`
4. **filter_nearest**: All grass/ground samplers must use `filter_nearest` for pixel art look
5. **SignalBus**: Always emit/connect through SignalBus, never couple systems directly
6. **Slot marker materials**: TilePlacement shares 2 materials across all markers — don't create per-marker
7. **Variant inference**: Godot 4.6 treats Variant inference as error — always type dictionary iterations (`for key: Type in dict`)
8. **Group rotation math**: CW step for square grid offset: `(x,y) → (-y, x)` — applied N times for N×90° rotation
9. **Merge deduplication**: When scoring, track `seen_anchors` to avoid counting a merged tile multiple times
10. **Preview tint caching**: `_last_tint_valid` avoids re-traversing tree every frame — reset to -1 on group change/rotation
11. **Mesh duplication**: Aging and neighbor systems duplicate meshes/materials per-tile — check `has_meta()` before duplicating

## Build & Run
- Main scene: `res://scenes/main.tscn`
- No build system — run directly from Godot editor (F5)

### Scene Tree (main.tscn)
```
Main (Node3D, main.gd)
├── WorldEnvironment
├── DirectionalLight3D
├── CameraController (Camera3D)
├── UI (Control, game_ui.gd)
│   └── HandUI (runtime, hand_ui.gd)
├── GroundPlane (MeshInstance3D)
├── PostProcess (CanvasLayer)
│   └── TiltShift (ColorRect)
├── TileGrid (Node3D, tile_grid.gd)
├── TilePlacement (Node3D, tile_placement.gd)
├── QuestManager (Node, quest_manager.gd)
├── MysteryTileManager (runtime, mystery_tile_manager.gd)
├── TileAgingManager (runtime, tile_aging_manager.gd)
└── HandManager (runtime, hand_manager.gd)
```

## Current State
- 11 terrain types: Forest, Clearing, Rocks, Water, Desert, Swamp, Mountain, Meadow, Tundra, Village, River
- Water is mystery-tile exclusive; River has chain bonuses (+15/river neighbor, -5 if isolated)
- Each tile = one terrain type (whole-cell, no per-edge subdivision)
- Groups of 1-3 tiles placed together (5 shape types including SINGLE)
- Hand system: 3 slots, pick-and-place, auto-redraw, RMB swap (1/hand)
- R-key rotates entire group pattern (90° increments)
- Adjacency scoring (+10/same-terrain neighbor, +30 perfect bonus with all 4 neighbors)
- 21 cross-terrain interactions (e.g., Symbiosis, Oasis, Bridge, Summit, Bayou)
- Tile merging: 2×2 same-terrain → big merged tile (animated shrink + appear + shockwave ring)
- Terrain group tracking via BFS flood-fill
- Quest system: Dorfromantik-style, max 3 active, quests anchor to newly placed tiles (no overlap)
- Quest star (★) clickable — shows info popup + highlights valid edge positions
- Auto-quests queue as "pending" until matching terrain is placed
- Mystery tiles: max 2 active, gray with pulsing glow, spawn 5-10 tiles away
- Tile aging: tiles grow taller over turns with bounce animation
- Finite deck: 30 starting groups, quests & milestones extend it
- Milestone bonuses: every 100 pts = +2 groups (quiet, no flashy popup)
- Game over when deck AND hand are empty
- Cozy animations: tile squish on place, gentle score float, merge ring, discovery ring, quest slide-in/out
- Score preview on hover (shows potential points before placing)
- Turn tracking (3 placements = 1 turn)
- UI: score, group counter (color warning), turn counter, quest cards with progress, interaction legend, game over panel, hand bar
- Preview shows full tile appearance; invalid placement shows red tint
- Orbit camera with dynamic pitch, tilt-shift post-process

### TODO
- Art direction & assets (exploring oil painting / paper diorama / pastel styles)
- Sound effects and music
- Save/load system
- Balancing (deck size, quest rewards, interaction values)
