# Bake ambient occlusion into vertex colours of finished GLB models (T-064): dark seams, the gap under a turret,
# wheel arches and crevices, free at runtime (Godot multiplies the albedo by COLOR_0). The v6 models use
# one-colour palette UVs, so a texture cannot hold AO — vertex colours can. Everything is baked together, so
# parts shade each other. AO is remapped to [LOW, 1] to stay soft.
# /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/art/bake_ao_glb.py -- out_dir in1.glb [in2.glb ...]
import bpy, os, sys
LOW = .58; DISTANCE = .35; SAMPLES = 48
args = sys.argv[sys.argv.index("--") + 1:]
out_dir, sources = args[0], args[1:]
os.makedirs(out_dir, exist_ok=True)
for src in sources:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"; scene.cycles.samples = SAMPLES; scene.cycles.device = "CPU"
    if scene.world is None: scene.world = bpy.data.worlds.new("W")
    scene.world.light_settings.distance = DISTANCE
    scene.render.bake.target = "VERTEX_COLORS"
    # Hidden parts (e.g. alternative gear left out of the view layer) are exported as they are, not baked.
    meshes = [o for o in bpy.context.view_layer.objects if o.type == "MESH"]
    for ob in meshes:
        me = ob.data
        for a in list(me.color_attributes): me.color_attributes.remove(a)
        attr = me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        me.color_attributes.active_color = attr; me.color_attributes.render_color_index = 0
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes: ob.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.bake(type="AO")
    for ob in meshes:
        data = ob.data.color_attributes["AO"].data
        for c in data:
            v = c.color[0]; v = LOW + (1 - LOW) * v
            c.color = (v, v, v, 1.0)
    out = os.path.join(out_dir, os.path.basename(src))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_yup=True, export_animations=False, export_vertex_color="ACTIVE")
    print("BAKED", os.path.basename(src), len(meshes), "meshes ->", out)
