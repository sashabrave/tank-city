# Czech hedgehog ability icon (anti-tank «ёж»): three crossed angle-iron beams, rusty olive paint, a hazard
# band; rendered on a transparent background in the 3/4 icon view. Higgsfield credits ran out, so this is
# modelled and rendered in Blender.
# /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/art/render_hedgehog_icon.py -- out.png
import bpy, math, sys, mathutils
out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "/tmp/hedgehog.png"
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"; scene.cycles.samples = 96; scene.cycles.use_denoising = True
scene.render.film_transparent = True; scene.render.resolution_x = scene.render.resolution_y = 1024
scene.view_settings.view_transform = "AgX"; scene.view_settings.look = "AgX - Medium High Contrast"

def mat_paint():
    m = bpy.data.materials.new("Paint"); m.use_nodes = True; n = m.node_tree.nodes; l = m.node_tree.links
    bsdf = n["Principled BSDF"]
    noise = n.new("ShaderNodeTexNoise"); noise.inputs["Scale"].default_value = 9; noise.inputs["Detail"].default_value = 12
    ramp = n.new("ShaderNodeValToRGB"); ramp.color_ramp.elements[0].position = .52; ramp.color_ramp.elements[1].position = .62
    ramp.color_ramp.elements[0].color = (.11, .13, .08, 1); ramp.color_ramp.elements[1].color = (.30, .12, .04, 1)
    l.new(noise.outputs["Fac"], ramp.inputs["Fac"])
    # Hazard band: yellow/black stripes around the middle of one beam, chosen by object coordinate.
    coord = n.new("ShaderNodeTexCoord"); sep = n.new("ShaderNodeSeparateXYZ"); l.new(coord.outputs["Object"], sep.inputs[0])
    wave = n.new("ShaderNodeTexWave"); wave.wave_type = "BANDS"; wave.inputs["Scale"].default_value = 1.3; wave.wave_profile = "SAW"
    l.new(coord.outputs["Object"], wave.inputs["Vector"])
    stripe = n.new("ShaderNodeMath"); stripe.operation = "GREATER_THAN"; stripe.inputs[1].default_value = .5; l.new(wave.outputs["Fac"], stripe.inputs[0])
    yb = n.new("ShaderNodeMix"); yb.data_type = "RGBA"; yb.inputs[6].default_value = (.08, .07, .05, 1); yb.inputs[7].default_value = (.85, .62, .06, 1)
    l.new(stripe.outputs[0], yb.inputs[0])
    band = n.new("ShaderNodeAttribute"); band.attribute_type = "OBJECT"; band.attribute_name = "band"
    inband = n.new("ShaderNodeMath"); inband.operation = "LESS_THAN"; inband.inputs[1].default_value = .22
    absx = n.new("ShaderNodeMath"); absx.operation = "ABSOLUTE"; l.new(sep.outputs["X"], absx.inputs[0])
    off = n.new("ShaderNodeMath"); off.operation = "SUBTRACT"; off.inputs[1].default_value = 1.05; l.new(absx.outputs[0], off.inputs[0])
    absoff = n.new("ShaderNodeMath"); absoff.operation = "ABSOLUTE"; l.new(off.outputs[0], absoff.inputs[0]); l.new(absoff.outputs[0], inband.inputs[0])
    mask = n.new("ShaderNodeMath"); mask.operation = "MULTIPLY"; l.new(inband.outputs[0], mask.inputs[0]); l.new(band.outputs["Fac"], mask.inputs[1])
    mix = n.new("ShaderNodeMix"); mix.data_type = "RGBA"; l.new(mask.outputs[0], mix.inputs[0]); l.new(ramp.outputs["Color"], mix.inputs[6]); l.new(yb.outputs[2], mix.inputs[7])
    l.new(mix.outputs[2], bsdf.inputs["Base Color"])
    rough = n.new("ShaderNodeMapRange"); rough.inputs[3].default_value = .45; rough.inputs[4].default_value = .85; l.new(noise.outputs["Fac"], rough.inputs[0]); l.new(rough.outputs[0], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = .35
    bump = n.new("ShaderNodeBump"); bump.inputs["Strength"].default_value = .25
    fine = n.new("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 60; l.new(fine.outputs["Fac"], bump.inputs["Height"]); l.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m

paint = mat_paint()
root = bpy.data.objects.new("Hedgehog", None); scene.collection.objects.link(root)
L, W, T = 1.75, .42, .06  # half length, flange width, plate thickness
def angle_beam(axis, band):
    # Angle iron: two plates in an L, long along local X; rotated onto the axis.
    parts = []
    for size, off in [((L * 2, W, T), (0, W * .5 - T * .5, 0)), ((L * 2, T, W), (0, 0, W * .5 - T * .5))]:
        bpy.ops.mesh.primitive_cube_add(size=1, location=off); o = bpy.context.object; o.scale = size
        bpy.ops.object.transform_apply(scale=True); parts.append(o)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts: o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]; bpy.ops.object.join(); o = bpy.context.object
    bev = o.modifiers.new("b", "BEVEL"); bev.width = .012; bev.segments = 2
    # End caps slightly cut at an angle like torch-cut steel.
    o.rotation_euler = {"x": (0, 0, 0), "y": (0, 0, math.pi / 2), "z": (0, -math.pi / 2, 0)}[axis]
    o.data.materials.append(paint); o["band"] = 1.0 if band else 0.0; o.parent = root
    return o
angle_beam("x", True); angle_beam("y", False); angle_beam("z", False)
# Centre gusset plates and bolts.
bpy.ops.mesh.primitive_cube_add(size=1); g = bpy.context.object; g.scale = (.5, .5, .5); g.data.materials.append(paint); g.parent = root; g["band"] = 0.0
bev = g.modifiers.new("b", "BEVEL"); bev.width = .03; bev.segments = 3
for v in [(1, 1, 1), (-1, 1, 1), (1, -1, 1), (1, 1, -1)]:
    bpy.ops.mesh.primitive_cylinder_add(radius=.05, depth=.7, location=(0, 0, 0)); b = bpy.context.object
    b.rotation_euler = mathutils.Vector(v).to_track_quat("Z", "Y").to_euler(); b.data.materials.append(paint); b.parent = root; b["band"] = 0.0
# Stand it on three arm ends: body diagonal (1,1,1) vertical.
# Classic tank-trap pose: two beams make a big X facing the viewer, the third runs front to back, tilted up.
root.rotation_mode = "XYZ"; root.rotation_euler = (math.radians(-38), math.radians(45), math.radians(18))

cam_data = bpy.data.cameras.new("Cam"); cam_data.type = "ORTHO"; cam_data.ortho_scale = 4.6
cam = bpy.data.objects.new("Cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam
cam.location = (3.5, -11.5, 3.0); direction = mathutils.Vector((0, 0, .1)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
def light(name, kind, loc, energy, size, color=(1, 1, 1)):
    d = bpy.data.lights.new(name, kind); d.energy = energy; d.color = color
    if kind == "AREA": d.size = size
    o = bpy.data.objects.new(name, d); scene.collection.objects.link(o); o.location = loc
    o.rotation_euler = (mathutils.Vector((0, 0, 0)) - o.location).to_track_quat("-Z", "Y").to_euler()
light("Key", "AREA", (-5, -6, 8), 1400, 5, (1, .95, .88))
light("Fill", "AREA", (8, -2, 2), 350, 6, (.8, .88, 1))
light("Rim", "AREA", (2, 8, 5), 700, 3)
world = bpy.data.worlds.new("W"); scene.world = world; world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.5, .52, .55, 1); world.node_tree.nodes["Background"].inputs["Strength"].default_value = .45
scene.render.filepath = out; bpy.ops.render.render(write_still=True); print("rendered", out)
