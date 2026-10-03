
# Room versions of the route stops (author, 3 Oct): the same parts as the map stop, bigger and with more detail,
# built straight in room units (1 = one floor tile). Blender (x, y, z) = Godot (x, -z, y): +Y here is the back of
# the room. The room floor is z = 0; the walkable area is x -3..3, Godot z -2..4 (Blender y -4..2), so the big
# parts stand behind y = 2.1. RoomLayout keeps its spots: MAIN (0, 1), weapon crate (-3.4, -0.5), vending machine
# (-3.4, -2.4), fortune (3.4, -2.9), exit gate (4, -1). Sourced after common.py.
TILE_H = 0.0

def soft(ob, w=0.05, seg=2):
    bevel(ob, width=w, segments=seg, angle_limit=40)   # two segments: seen up close
    return ob

def B(name, size, loc, mat, w=0.05, rot=(0, 0, 0)):
    ob = box(name, size, location=loc, rotation=rot)
    assign(ob, mat)
    return soft(ob, w) if w else ob

def C(name, r, h, loc, mat, seg=14, axis="Z", top=None, w=0.0):
    ob = cylinder(name, r, h, segments=seg, axis=axis, radius_top=top, location=loc)
    assign(ob, mat)
    return soft(ob, w) if w else ob

def jerrycan(m, x, y, rot=0.0, mat=None):
    B("Jerrycan", (0.42, 0.24, 0.6), (x, y, 0.3), mat or m["olive"], 0.04, rot=(0, 0, rot))
    B("Jerrycan_Cap", (0.12, 0.1, 0.1), (x - 0.1, y, 0.64), m["olive_dark"], 0.02, rot=(0, 0, rot))

def drum(m, x, y, mat):
    d = profile_spin("Drum", [(0, 0), (0.36, 0), (0.39, 0.1), (0.4, 0.45), (0.39, 0.8), (0.36, 0.9), (0, 0.9)], steps=14, location=(x, y, 0))
    assign(d, mat)
    for h in (0.3, 0.6):
        C("Drum_Ring", 0.41, 0.05, (x, y, h), m["iron"], 14)

def crate(m, x, y, s=0.75, rot=0.0):
    B("Crate", (s, s, s * 0.85), (x, y, s * 0.425), m["wood"], 0.05, rot=(0, 0, rot))
    for dx, dz in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
        c, sn = math.cos(rot), math.sin(rot)
        ox = dx * (s / 2 - 0.05)
        B("Crate_Corner", (0.12, s + 0.04, 0.12), (x + ox * c, y + ox * sn, s * 0.425 + dz * (s * 0.425 - 0.06)), m["metal"], 0.02, rot=(0, 0, rot))

def rock(m, x, y, s=1.0):
    r = sphere("Rock", 0.33 * s, location=(x, y, 0.1 * s), u=7, v=5, scale=(1.25, 1.0, 0.75)); assign(r, m["rock"])

def tyre(m, x, y, z, r=0.34, w=0.24, axis="Z"):
    t = C("Tyre", r, w, (x, y, z), m["tyre"], 14, axis=axis, w=0.06)
    C("Tyre_Hole", r * 0.5, w + 0.02, (x, y, z), m["black"], 10, axis=axis)
    return t

def lantern(m, x, y, z, k=1.0):
    C("Lantern_Cap", 0.17 * k, 0.12 * k, (x, y, z + 0.28 * k), m["iron"], 6, top=0.05 * k)
    C("Lantern_Glass", 0.13 * k, 0.3 * k, (x, y, z + 0.08 * k), m["glow"], 6)
    C("Lantern_Base", 0.16 * k, 0.07 * k, (x, y, z - 0.1 * k), m["iron"], 6)
