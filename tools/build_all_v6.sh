#!/bin/zsh
# Rebuild every v6 asset in dependency order (weapons.json feeds the infantry holds).
set -e
cd "$(dirname "$0")/.."
B=${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}
run() { "$B" -b --factory-startup --python "$@" 2>&1 | grep -E "WEAPONS|tris|VEHICLE|PROP|VEGETATION|CONCRETE|MORTAR|BIOME|Traceback|Error" || true; }
run tools/build_weapons_v6.py
for k in soldier grenadier shield sniper rpg_soldier; do run tools/build_infantry_v6.py -- --kind $k; run tools/build_infantry_v6.py -- --kind $k --species dog; done
run tools/rematerial_kit_v4.py  # vehicles keep kit_v4 geometry, softened by cozy_soften
run tools/build_mortar_v6.py
run tools/build_props_v6.py
run tools/build_yard_props.py
run tools/build_vegetation_v6.py
run tools/build_biome_props.py
"$B" -b -P tools/build_concrete_slab_v6.py 2>&1 | grep -E "CONCRETE|Traceback" || true
echo "v6 assets rebuilt; import them with: Godot --headless --path . --import"
