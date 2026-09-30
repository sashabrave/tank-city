# Terrain prototype

All combat rooms/worlds generate terrain from run seed + room index using a separate RNG. Ordinary floor and trenches retain existing assets. Half-cell ownership forbids overlaps; ordinary full tiles are omitted wherever specialized tiles replace them.

## Biomes (stable HUD IDs)

| ID | Map | Special floor |
|---|---|---|
| 01 | Sandy desert, ochre | Sand |
| 02 | Terracotta desert | Sand |
| 03 | Pale olive shore | Sand + water |
| 04 | Pale pink shore | Sand + water |
| 05 | Wet forest, muted green | Water |
| 06 | Frozen plain, blue grey | Ice |
| 07 | Lilac mountain pass | Ice |

`biome_catalog.gd` couples floor, concrete, brick, foundation and ambience colours/rules. Selection is `(run_seed + room_index) mod 7`, stable on checkpoint reload; IDs always mean the same combination. HUD below weapon stats shows ID, name and allowed floors. Existing ordinary floor, trenches and cover remain in every biome.

Water and ice share the same one-cell-wide straight / L ribbon generator: 1–5 cells, up to 6 at difficulty >=2; at most two ribbons and a combined budget of min(8, max(3, floor(board area × .035))) cells. Rejected ribbons roll back completely. Sparse maps may generate shorter/fewer ribbons. Sand: up to six cells in deserts, four on shores.
Water: muted location-tinted blue, low plane, minimal ripple marks; blocks movement and navigation but not projectiles. Candidate removal must preserve connectivity between all existing walkable neighbors. Outer lanes, spawn rows, starting area and boss central corridor / generators are reserved.
Sand: location-tinted ochre with three faceted low ridges per half tile. Ground infantry, vehicles and companions use .55 speed; flying actors are unaffected.
Ice: location-tinted pale cyan with short fracture marks. Momentum continues in the prior movement direction through ice in .25 increments, followed by up to .5 coasting off ice. Collision validation applies to each step; water/walls/units stop coasting. Trench occupation clears momentum.
All decorative pieces use MultiMesh batches grouped by material. No runtime physics bodies or per-tile processing.

Implementation: scripts/systems/terrain_system.gd, arena.gd, actor.gd, vehicle_system.gd, enemy_system.gd. Field tablet guide includes terrain rules.
Validation: terrain_v1 across all 21 rooms checks deterministic/exclusive placement, actor and projectile water rules, infantry/tank sand and ice, stopping at water. sections_v21, trench_regression and run_checkpoint_v20 passed. Visual screenshot: docs/reskin/screenshots/terrain-battle.png.

## Navigation

Shared lazy quarter-grid occupancy cache, partitioned by body size and trench/flying permissions. Static geometry results are shared between actors; units, trench reservations and wrecks are checked live. Wall damage invalidates nearby cache buckets (radius 3 for the largest 4-cell body), including partial section damage while the wall survives. Other static changes and room rebuilds also invalidate. Route-search revision changes prevent reuse of stale per-search results.

A cached route blocked by a unit is kept for 650 ms; if cleared, movement resumes without rebuilding it. Persistent blockage requests a new search. The existing resumable BFS and shared ~2 ms expansion budget remain; this change does not introduce A*. Observed 10-unit unreachable-goal regression: worst search batch 3.37 ms on the test machine, not a whole-frame guarantee.

`tests/navigation_cache.tscn` checks sharing, local invalidation after partial damage, distant cache retention, vehicle clearance, jam waiting/release and timeout. `terrain_v1` covers all seven biomes across 21 rooms; `sections_v21` and `trench_regression` cover narrow passages and exclusive trenches.

## Lightweight ambient motion

`terrain_ambience.gd` adds one MultiMesh per active terrain effect, one clock node per room, no collision bodies or per-tile scripts. Water ripple marks cycle through exactly three poses at 3 steps/sec. Ice gets sparse small falling snow particles; sand gets sparse near-surface windblown grains. One particle instance per full ice/sand tile, visible for only part of its cycle, tinted from the biome. The local clock stops on tree pause. Vertex displacement is visual only and does not change floor ownership, navigation or collisions. `tests/terrain_effects.tscn` checks update/pause and bounded batches.
