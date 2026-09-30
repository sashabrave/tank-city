# Concrete blocks: 2×2 pressed relief

Created through Blender MCP. Editable source: concrete_2x2.blend.
Two full variants, each with four integral relief figures per lateral face and 0.085–0.10 margin. Edges have a 0.006-wide, two-segment bevel.
_half_0/1/2/3 are real cuts preserving respectively negative X, positive X, negative Z, positive Z. Relief stays at original scale: narrow faces retain one column and two rows. Cut surfaces are plain concrete. _half_4/5 are L-shaped cuts for corner coverage.
Runtime does not scale the half models. Every GLB exports one selected mesh from the active scene at the original cell origin.
Verified GLB bounds, visual review in Godot, and tests/sections_v21.tscn (PASS).

## Mixed concrete
Smooth blocks use the same 0.96 dimensions, ENV7_concrete material and 0.006 bevel as pressed blocks. Source: mixed_concrete.blend (Smooth_Concrete_Matching and Concrete_2x2 scenes).
Families: concrete_smooth, concrete_0, concrete_1. Nine shapes each: full, four half-cuts, four L-corners. Shapes 6/7 are rotations of 4/5.
ConcreteStyle chooses surface independently (50% smooth / 50% pressed) and shape (50% full / 50% among eight cuts). Combat selections are deterministic from run seed, room and cell; hub uses a fixed decorative seed. No combat RNG is consumed. Base-protection shapes stay prescribed.
Test concrete_mix validates all 27 combinations and compares mesh triangle occupancy against all sixteen collision sections. PASS. Hub intro smoke test also passes.
