# Cover V1

Generated concept sheet: `reference.png`, built-in image_gen (one 2×1 sheet). Mode: stylized-concept.
Models assembled through Blender MCP; editable source: `cover_models.blend`. Runtime: `trench.glb`, `net.glb`.

Trench: 1×1 footprint, four faceted berms, timber retaining boards, four stones; inner opening .73×.73, floor at -.94. Battle floor and foundation omit trench cells. Actor offsets and combat rules are unchanged.
Net: original environment_v7 roof and posts preserved; four collars and corner bindings added. 456→520 authored vertices (+14%). Original roof openings and cloth patches preserved. No solid transparency plane.
Both assets inherit location floor colors through Visuals; trench soil uses floor darkened 12%, net fabric 10%. Interior floor is darker. Materials remain local per instance.

Validation: tests/cover_visual.tscn checks seven room layouts, omitted foundation cells, actor depth; palette and close-up screenshots inspected. Tests disable persistence.

## Exact generation prompt

Create one 2-column by 1-row game asset modeling reference sheet, landscape, no text. Two isolated very simple low-poly models, same orthographic three-quarter elevated camera, matte muted sage/gray/olive palette, flat shaded geometric faces, minimal details easy to reproduce exactly from boxes and polygon rings in Blender. LEFT: single square infantry trench cell, low continuous faceted earth berm on ALL FOUR sides, square open central pit, visible vertical earth walls, recessed flat earth floor, two simple horizontal wooden retaining boards on each inner wall, just four small angular stones on rim. Square outer footprint 1 unit, open interior .72 units, berm height .14, pit depth .9 units shown as a cutaway square earth block to explain depth. NO black filled top, genuinely open hole. RIGHT: square military camouflage net canopy on four very thin straight posts, footprint 1 unit, height 1.15 units. Roof is a sparse 6 by 6 lattice with large clearly open square holes, thin .025 unit strips; four small flat cloth patches on lattice only, each .12 by .13 units, tiny ties on the FOUR CORNERS and small collars on posts. Airy, mostly empty roof; no solid roof, no dense fabric. Low-detail casual tactical mobile game, no weapons, no characters, no extra props, no photoreal textures, neutral warm gray background, even studio lighting. Keep silhouettes clean and construction extremely simple.
