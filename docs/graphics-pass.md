# Graphics pass: Compatibility

- Shared imported palette now separates bare steel (metallic 1, roughness .38), paint (.56), dark matte parts (.88), and stone (.95).
- Procedural sky provides ambient light and reflected environment; the background stays neutral. A warm directional light highlights existing mesh bevels.
- Combat bursts use short fire lobes, rising smoke, and ballistic sparks. At most 20 effects and 3 shadowless explosion lights coexist. Visual randomness does not use the combat RNG.
- Effects last at most 1.15 seconds and own their transient materials. Shared sphere geometry reduces mesh allocation.

This first pass uses stylized geometry, not realistic fire/smoke flipbooks. No dynamic GI, SSR, local reflection probes, model rebuild, or renderer switch was introduced. Actual frame-time comparisons on target hardware remain to be done.

Verification: 103 existing smoke checks passed; graphical preview rendered in Compatibility on Apple M4 and verified effect cleanup. Preview: screenshots/graphics-preview.png. Original edited scripts: tmp/graphics-backup/.
