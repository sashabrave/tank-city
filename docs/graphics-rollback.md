# Graphics rollback — 2026-09-26

The "atmosphere" pass that followed the first graphics pass (per-room seasons /
time of day / weather, volumetric-style fog, wet + snowy ground shader, field
lamps and searchlights, Forward+ switch, "Свет и погода" quality option) was
rolled back at the author's request. The look that is kept is the **first
graphics pass** documented in `graphics-pass.md` — the one in
`screenshots/graphics-preview.png`.

## Current state

- Renderer: `gl_compatibility` (Compatibility), as in the first pass.
- One shared look for every scene: `Visuals.setup_world()` builds the
  WorldEnvironment (procedural sky as ambient + reflection source,
  `ambient_light_energy = .48`, linear tonemap) and the warm directional sun
  (`fff0d7`, energy `.95`, shadows on). It is called by **hub.gd, route_map.gd,
  service_room.gd and arena.gd** — every scene root. Any new scene gets the same
  treatment by calling it.
- One shared material palette: `Visuals.normalize_materials()` (steel
  metallic 1 / roughness .38, paint .56, dark matte .88, stone .95) runs inside
  `Visuals.model()`, so every `.glb` in the game goes through it.
- Explosions: `combat_effect.gd` — fire lobes, smoke, sparks, capped at 20
  effects and 3 shadowless flash lights.
- Pre-existing cloud/biome ambience (`location_ambience.gd`,
  `assets/weather/clouds.gdshader`, `weather_profile.gd`) is untouched — it
  predates the rolled-back pass.
- `rendering/textures/vram_compression/import_etc2_astc=true` — required for
  macOS arm64/universal export.

## Where the removed work went

Nothing was deleted. `tmp/` is `.gdignore`d, so Godot ignores it:

- `tmp/atmosphere-rollback/` — files the pass created (room_atmosphere.gd,
  ground.gdshader, field_lamp/field_searchlight .glb, field_lights.blend,
  build_lighting_assets.py, tests/atmosphere.*).
- `tmp/atmosphere-applied-backup/` — the edited scripts and project.godot as
  they were with the pass applied, in case any of it is wanted back.
- `tmp/atmosphere-backup/` — the pre-pass originals that were restored.

Do not re-introduce the pass without asking.
