
# Instructor room: the map stop up close — the wide olive tent at the back with the target board in its open
# doorway, a field table at the main spot, the target dummy on the right (Godot (2.2, -1.2), off the walkable
# floor), the grenade crate, sandbag rows, ammo boxes, a flag and pines.
TENT_W, TENT_D, TENT_H = 4.8, 2.4, 3.1
TENT_Y_BACK = 4.45

def tent(m):
    yf, yb = TENT_Y_BACK - TENT_D, TENT_Y_BACK
    mid = (yf + yb) / 2
    prof = [(yf, 0), (yb, 0), (yb - 0.15, 1.7), (mid + 0.35, TENT_H), (mid - 0.35, TENT_H), (yf + 0.15, 1.7)]
    body = profile_extrude("Tent_Body", prof, TENT_W, location=(-TENT_W / 2, 0, 0), rotation=(math.radians(90), 0, math.radians(90)))
    assign(body, m["olive"]); soft(body, 0.1)
    B("Tent_Doorway", (2.5, 0.04, 2.15), (0, yf - 0.02, 1.08), m["olive_dark"], 0)
    for x in (-1.45, 1.45):
        B("Tent_Post", (0.2, 0.2, 2.55), (x, yf - 0.14, 1.28), m["wood"], 0.04)
        fx = x + (0.26 if x < 0 else -0.26)
        B("Tent_Flap", (0.52, 0.26, 2.2), (fx, yf - 0.24, 1.15), m["canvas"], 0.1)
        B("Tent_Tie", (0.56, 0.3, 0.1), (fx, yf - 0.24, 1.45), m["wood_dark"], 0.02)
    B("Tent_Crossbar", (3.1, 0.18, 0.18), (0, yf - 0.14, 2.5), m["wood"], 0.04)
    C("Tent_Roll", 0.18, 3.1, (0, yf - 0.28, 2.53), m["canvas"], 12, axis="X", w=0.03)
    for x in (-TENT_W / 2 + 0.05, TENT_W / 2 - 0.05):
        C("Tent_RidgeCap", 0.08, 0.28, (x, mid, TENT_H + 0.07), m["wood_dark"], 6)
    for x in (-TENT_W / 2 - 0.35, TENT_W / 2 + 0.35):   # guy ropes and pegs on the sides
        for y in (yf + 0.4, yb - 0.4):
            C("Tent_Peg", 0.04, 0.2, (x, y, 0.1), m["wood_dark"], 5)
            a = Vector((x, y, 0.15)); b = Vector((x - 0.32 if x > 0 else x + 0.32, y, 1.6))
            d = b - a
            r = cylinder("Tent_Rope", 0.012, d.length, segments=4, location=(a + b) / 2)
            r.rotation_euler = d.to_track_quat("Z", "Y").to_euler(); assign(r, m["cream"])

def target_board(m):
    y = TENT_Y_BACK - TENT_D - 0.12
    B("Board", (1.6, 0.08, 1.0), (0, y, 1.5), m["board"], 0.02)
    B("Board_Frame", (1.72, 0.06, 1.12), (0, y + 0.03, 1.5), m["wood"], 0.02)
    for i, r in enumerate((0.36, 0.24)):
        C("Board_Ring%d" % i, r, 0.02, (0, y - 0.05, 1.5), m["white"], 20, axis="Y")
        C("Board_RingIn%d" % i, r - 0.05, 0.03, (0, y - 0.055, 1.5), m["board"], 20, axis="Y")
    C("Board_Dot", 0.06, 0.035, (0, y - 0.06, 1.5), m["white"], 10, axis="Y")
    for i, (x, z) in enumerate(((-0.6, 1.8), (0.55, 1.25), (0.62, 1.82))):   # chalk arrows of a lesson
        B("Board_Chalk%d" % i, (0.24, 0.02, 0.04), (x, y - 0.05, z), m["white"], 0, rot=(0, math.radians(25 - i * 30), 0))
    for x in (-0.74, 0.74):
        B("Board_Leg", (0.09, 0.09, 1.55), (x, y + 0.02, 0.78), m["wood"], 0.02)

def field_table(m):
    # the main spot (Godot (0, -1)): a folding table with a map, a whistle and a stopwatch
    x, y = 0, 1.15
    B("Table_Top", (1.3, 0.7, 0.08), (x, y, 0.78), m["wood"], 0.03)
    for s in (-1, 1):
        B("Table_LegA", (0.07, 0.6, 0.8), (x + s * 0.5, y, 0.39), m["wood_dark"], 0.02, rot=(math.radians(18), 0, 0))
        B("Table_LegB", (0.07, 0.6, 0.8), (x + s * 0.5, y, 0.39), m["wood_dark"], 0.02, rot=(math.radians(-18), 0, 0))
    B("Table_Map", (0.8, 0.5, 0.01), (x - 0.12, y, 0.83), m["cream"], 0, rot=(0, 0, math.radians(-6)))
    for i, (dx, dy) in enumerate(((-0.3, 0.1), (0.05, -0.08), (-0.1, 0.15))):
        B("Table_MapMark%d" % i, (0.06, 0.06, 0.012), (x - 0.12 + dx, y + dy, 0.84), m["red"], 0)
    C("Table_Stopwatch", 0.08, 0.04, (x + 0.45, y - 0.15, 0.84), m["metal"], 12)
    C("Table_Whistle", 0.035, 0.16, (x + 0.42, y + 0.15, 0.85), m["yellow"], 8, axis="X")
    C("Table_Mug", 0.06, 0.12, (x + 0.48, y + 0.0, 0.88), m["olive_dark"], 8)

def dummy(m, x, y, k=1.0):
    B("Dummy_Base", (0.6 * k, 0.6 * k, 0.12), (x, y, 0.06), m["concrete"], 0.03)
    B("Dummy_Post", (0.14, 0.14, 0.95 * k), (x, y, 0.12 + 0.47 * k), m["wood"], 0.02)
    B("Dummy_Board", (0.8 * k, 0.12, 1.05 * k), (x, y, 1.5 * k), m["cream"], 0.05)
    B("Dummy_Head", (0.36 * k, 0.12, 0.32 * k), (x, y, 2.18 * k), m["cream"], 0.04)
    C("Dummy_Ring", 0.3 * k, 0.03, (x, y - 0.07, 1.5 * k), m["black"], 16, axis="Y")
    C("Dummy_RingIn", 0.2 * k, 0.04, (x, y - 0.075, 1.5 * k), m["cream"], 16, axis="Y")
    C("Dummy_Bull", 0.09 * k, 0.05, (x, y - 0.08, 1.5 * k), m["black"], 10, axis="Y")
    for dx, dz in ((0.12, 0.18), (-0.2, -0.1)):
        C("Dummy_Hole", 0.03, 0.06, (x + dx * k, y - 0.08, (1.5 + dz) * k), m["black"], 6, axis="Y")

def grenades(m):
    x, y = -2.55, 2.45
    B("Crate", (1.3, 0.85, 0.66), (x, y, 0.33), m["olive"], 0.05)
    B("Crate_Lid", (1.36, 0.5, 0.06), (x, y + 0.5, 0.7), m["olive_dark"], 0.03, rot=(math.radians(-35), 0, 0))
    for dx in (-0.3, 0.3):
        B("Crate_Latch", (0.15, 0.04, 0.11), (x + dx, y - 0.44, 0.5), m["metal"], 0.01)
    for i, dx in enumerate((-0.36, -0.12, 0.12, 0.36)):
        g = sphere("Grenade%d" % i, 0.15, location=(x + dx, y, 0.72), u=10, v=7, scale=(1, 1, 1.25)); assign(g, m["olive_dark"])
        C("Grenade_Cap%d" % i, 0.05, 0.09, (x + dx, y, 0.93), m["metal"], 8)

def sandbags_row(m, x0, y, count, rows=2, dx=0.8):
    for row in range(rows):
        for i in range(count - row):
            B("Sandbag", (0.78, 0.46, 0.3), (x0 + (i + row * 0.5) * dx, y, 0.15 + row * 0.28), m["bag"], 0.12)

def props(m):
    sandbags_row(m, -4.45, 2.1, 2)
    sandbags_row(m, 2.95, 2.1, 2)
    dummy(m, 2.2, 1.2)
    dummy(m, 3.75, 3.1, 0.85)
    for i in range(2):
        B("Ammo_Box", (0.6, 0.36, 0.32), (-3.9 + i * 0.12, 3.2, 0.16 + i * 0.32), m["olive"], 0.03, rot=(0, 0, 0.1 * i))
    C("Flag_Pole", 0.04, 3.2, (2.95, 3.9, 1.6), m["iron"], 6)
    B("Flag", (0.04, 0.9, 0.55), (2.95, 3.45, 2.9), m["olive"], 0.02)
    B("Flag_Star", (0.05, 0.16, 0.16), (2.95, 3.45, 2.9), m["yellow"], 0, rot=(math.radians(45), 0, 0))
    lantern(m, 1.6, 2.0, 2.3, 0.8)
    pine(m, -4.45, 4.15, 1.2); pine(m, 4.45, 4.25, 1.05)
    rock(m, -1.7, 4.6, 1.3)

def build(scene, m):
    tent(m); target_board(m); field_table(m); grenades(m); props(m)

run_build(build)
