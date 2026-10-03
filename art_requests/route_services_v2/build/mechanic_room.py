
# Mechanic room: the map stop up close — the tow truck with its yellow crane at the back, the crane holding an
# engine over the lift where the player's vehicle stands (the game model, placed by service_room.gd at
# (2.2, 0.16, -1.2)), the red tool chest and a workbench at the main spot, tyres, jerrycans, drums and a pine.
WR = 0.72                 # stop wheel 0.58 × 1.25
TY = 3.1                  # truck along X at the back (Godot z -3.1)
CAB_X0, CAB_X1, BED_X1 = -4.15, -2.5, 0.75
TW = 2.0
LIFT = (2.2, 1.2)

def wheel(m, x, y, r, w):
    C("Truck_Tyre", r, w, (x, y, r), m["tyre"], 16, axis="Y", w=0.07)
    C("Truck_Hub", r * 0.42, w + 0.04, (x, y, r), m["olive"], 12, axis="Y", w=0.02)
    C("Truck_Cap", r * 0.15, w + 0.1, (x, y, r), m["metal"], 8, axis="Y")
    for i in range(5):
        a = i * math.tau / 5
        C("Truck_Nut", 0.035, w + 0.08, (x + math.cos(a) * r * 0.28, y, r + math.sin(a) * r * 0.28), m["iron"], 6, axis="Y")

def truck(m):
    cz = WR + 0.25; half = TW / 2
    B("Truck_Chassis", (BED_X1 - CAB_X0, TW - 0.6, 0.34), ((CAB_X0 + BED_X1) / 2, TY, WR + 0.08), m["iron"], 0.04)
    for x in (CAB_X0 + 0.8, BED_X1 - 0.75):
        for s in (-1, 1):
            wheel(m, x, TY + s * (half - 0.17), WR, 0.48)
            B("Truck_Fender", (1.5, 0.56, 0.16), (x, TY + s * (half - 0.17), 2 * WR + 0.12), m["olive_dark"], 0.06)
    H = 1.9
    B("Truck_Cab", (CAB_X1 - CAB_X0, TW, H), ((CAB_X0 + CAB_X1) / 2, TY, cz + H / 2), m["olive"], 0.14)
    B("Truck_CabRoof", (CAB_X1 - CAB_X0 - 0.2, TW - 0.2, 0.12), ((CAB_X0 + CAB_X1) / 2 + 0.05, TY, cz + H + 0.04), m["olive_dark"], 0.05)
    B("Truck_Windscreen", (0.06, TW - 0.5, 0.66), (CAB_X0 - 0.01, TY, cz + H - 0.5), m["glass"], 0.03)
    B("Truck_SideWindow", (0.8, 0.06, 0.6), ((CAB_X0 + CAB_X1) / 2 + 0.08, TY - half - 0.01, cz + H - 0.5), m["glass"], 0.03)
    B("Truck_Door", (0.95, 0.04, 1.2), ((CAB_X0 + CAB_X1) / 2 + 0.08, TY - half - 0.02, cz + 0.75), m["olive_dark"], 0.02)
    B("Truck_Handle", (0.18, 0.05, 0.05), ((CAB_X0 + CAB_X1) / 2 + 0.4, TY - half - 0.05, cz + 1.1), m["metal"], 0.01)
    B("Truck_Step", (0.6, 0.3, 0.06), ((CAB_X0 + CAB_X1) / 2 + 0.08, TY - half - 0.08, cz - 0.15), m["iron"], 0.02)
    B("Truck_Grille", (0.06, 1.0, 0.5), (CAB_X0 - 0.02, TY, cz + 0.55), m["olive_dark"], 0.03)
    for i in range(4):
        B("Truck_GrilleBar", (0.07, 0.9, 0.04), (CAB_X0 - 0.04, TY, cz + 0.38 + i * 0.12), m["iron"], 0)
    for s in (-1, 1):
        C("Truck_Headlight", 0.16, 0.09, (CAB_X0 - 0.03, TY + s * (half - 0.32), cz + 0.6), m["amber"], 12, axis="X")
        B("Truck_Mirror", (0.08, 0.12, 0.36), (CAB_X0 + 0.3, TY + s * (half + 0.1), cz + H - 0.4), m["iron"], 0.02)
    for i in range(3):
        B("Truck_RoofLight%d" % i, (0.15, 0.2, 0.1), (CAB_X0 + 0.42, TY - 0.42 + i * 0.42, cz + H + 0.14), m["amber"], 0.02)
    B("Truck_Bumper", (0.24, TW + 0.12, 0.28), (CAB_X0 - 0.12, TY, cz + 0.1), m["metal"], 0.05)
    # flat bed with low sides, the canvas-covered toolbox behind the cab, a red jerrycan
    bz = cz + 0.05
    L = BED_X1 - CAB_X1 - 0.05; bx = (CAB_X1 + BED_X1) / 2 + 0.02
    B("Bed_Floor", (L, TW, 0.18), (bx, TY, bz), m["olive_dark"], 0.03)
    for s in (-1, 1):
        B("Bed_Side", (L, 0.1, 0.44), (bx, TY + s * (half - 0.05), bz + 0.3), m["olive"], 0.03)
    B("Bed_Tail", (0.1, TW, 0.44), (BED_X1 - 0.05, TY, bz + 0.3), m["olive"], 0.03)
    B("Bed_Canvas", (1.3, TW - 0.24, 0.95), (CAB_X1 + 0.72, TY, bz + 0.58), m["canvas"], 0.16)
    for x in (CAB_X1 + 0.35, CAB_X1 + 1.1):
        B("Bed_Strap", (0.08, TW - 0.2, 0.98), (x, TY, bz + 0.6), m["wood_dark"], 0.02)
    B("Bed_RedCan", (0.3, 0.1, 0.36), (CAB_X1 + 0.5, TY - half - 0.02, bz + 0.24), m["red"], 0.03)
    for i, x in enumerate((CAB_X1 + 0.3, BED_X1 - 0.3)):
        B("Bed_Reflector%d" % i, (0.16, 0.04, 0.08), (x, TY - half - 0.01, bz + 0.12), m["amber"], 0.01)

def crane(m):
    bx, by = BED_X1 - 0.55, TY - 0.1
    bz = WR + 0.38
    C("Crane_Turret", 0.4, 0.34, (bx, by, bz + 0.17), m["iron"], 14, w=0.03)
    B("Crane_Mast", (0.42, 0.42, 1.9), (bx, by, bz + 1.29), m["yellow"], 0.07)
    for i in range(4):
        B("Crane_Stripe", (0.44, 0.44, 0.08), (bx, by, bz + 0.55 + i * 0.12), m["black"] if i % 2 else m["yellow"], 0)
    # boom from the mast top over the lift, the engine hangs beside the vehicle
    root = Vector((bx, by, bz + 2.15))
    tip = Vector((LIFT[0] - 0.75, LIFT[1] + 0.7, bz + 3.05))
    d = tip - root
    boom = box("Crane_Boom", (d.length, 0.28, 0.28), location=(root + tip) / 2)
    boom.rotation_euler = d.to_track_quat("X", "Z").to_euler()
    assign(boom, m["yellow"]); soft(boom, 0.06)
    C("Crane_Pin", 0.12, 0.44, tuple(root), m["iron"], 10, axis="Y")
    piston_a = Vector((bx + 0.2, by - 0.05, bz + 0.9)); piston_b = root + (tip - root) * 0.42
    pd = piston_b - piston_a
    p = cylinder("Crane_Piston", 0.07, pd.length, segments=8, location=(piston_a + piston_b) / 2)
    p.rotation_euler = pd.to_track_quat("Z", "Y").to_euler(); assign(p, m["metal"])
    C("Crane_Chain", 0.03, 0.6, (tip.x, tip.y, tip.z - 0.34), m["iron"], 6)
    B("Crane_Hook", (0.16, 0.1, 0.16), (tip.x, tip.y, tip.z - 0.7), m["metal"], 0.02)
    ez = tip.z - 1.12
    B("Engine_Block", (0.7, 0.52, 0.48), (tip.x, tip.y, ez), m["olive_dark"], 0.05)
    for i in range(3):
        B("Engine_Fin%d" % i, (0.72, 0.55, 0.04), (tip.x, tip.y, ez - 0.1 + i * 0.11), m["metal"], 0.01)
    C("Engine_Pulley", 0.12, 0.08, (tip.x + 0.36, tip.y, ez - 0.05), m["iron"], 10, axis="X")
    for dy in (-0.15, 0.15):
        C("Engine_Sling", 0.015, 0.36, (tip.x, tip.y + dy, ez + 0.4), m["iron"], 4)

def lift(m):
    x, y = LIFT
    B("Lift_Pad", (1.6, 2.0, 0.16), (x, y, 0.08), m["concrete"], 0.03)
    for s in (-1, 1):
        B("Lift_Edge", (0.08, 2.0, 0.04), (x + s * 0.78, y, 0.17), m["yellow"], 0)
        B("Lift_Post", (0.16, 0.16, 2.0), (x + s * 0.6, y + 1.1, 1.0), m["red"], 0.03)
        B("Lift_PostFoot", (0.34, 0.34, 0.08), (x + s * 0.6, y + 1.1, 0.04), m["iron"], 0.02)
    B("Lift_Beam", (1.36, 0.14, 0.14), (x, y + 1.1, 2.0), m["red"], 0.03)
    for dx in (-0.6, 0.6):
        for dy in (-0.75, 0.75):
            C("Jack_Leg", 0.1, 0.26, (x + dx, y + dy, 0.32), m["orange"], 4, top=0.05)
    oil = C("Oil_Stain", 0.3, 0.01, (x - 0.4, y - 0.7, 0.165), m["black"], 12)
    oil.scale = (1.3, 0.8, 1)

def workbench(m):
    # the main spot (Godot (0, -1)): red tool chest on castors and a bench with a vice and tools
    x, y = -0.42, 1.15
    B("Tool_Chest", (0.72, 0.6, 0.95), (x, y, 0.55), m["red"], 0.05)
    for i in range(5):
        B("Tool_Drawer%d" % i, (0.6, 0.04, 0.12), (x, y - 0.31, 0.3 + i * 0.15), m["metal"], 0.01)
    B("Tool_ChestLid", (0.74, 0.62, 0.06), (x, y, 1.05), m["red"], 0.02)
    for dx in (-0.28, 0.28):
        C("Tool_Caster", 0.06, 0.06, (x + dx, y, 0.06), m["black"], 8, axis="Y")
    B("Tool_Wrench", (0.42, 0.08, 0.03), (x, y - 0.05, 1.1), m["metal"], 0.01, rot=(0, 0, 0.3))
    bx = 0.4
    B("Bench_Top", (0.9, 0.72, 0.08), (bx, y, 0.86), m["wood"], 0.02)
    for dx in (-0.38, 0.38):
        for dy in (-0.3, 0.3):
            B("Bench_Leg", (0.07, 0.07, 0.82), (bx + dx, y + dy, 0.41), m["iron"], 0.01)
    B("Bench_Shelf", (0.84, 0.64, 0.05), (bx, y, 0.25), m["wood_dark"], 0.01)
    B("Bench_Vice", (0.2, 0.16, 0.14), (bx + 0.28, y - 0.25, 0.97), m["iron"], 0.02)
    C("Bench_ViceScrew", 0.02, 0.24, (bx + 0.28, y - 0.4, 0.97), m["metal"], 6, axis="Y")
    B("Bench_Part", (0.26, 0.2, 0.16), (bx - 0.15, y + 0.05, 0.98), m["olive_dark"], 0.03)
    C("Bench_Can", 0.07, 0.18, (bx - 0.32, y - 0.2, 0.99), m["yellow"], 8)
    B("Bench_Box", (0.4, 0.3, 0.2), (bx + 0.1, y, 0.38), m["olive"], 0.03)

def toolboard(m):
    x, y = 3.55, 2.45
    B("Board_Panel", (1.3, 0.06, 0.9), (x, y, 1.35), m["wood"], 0.02)
    for dx in (-0.55, 0.55):
        B("Board_Leg", (0.07, 0.07, 1.8), (x + dx, y + 0.04, 0.9), m["wood_dark"], 0.01)
    for i in range(5):
        B("Board_Tool%d" % i, (0.06, 0.03, 0.28 + 0.06 * (i % 3)), (x - 0.45 + i * 0.22, y - 0.05, 1.4), m["metal"] if i % 2 else m["iron"], 0.01)
    B("Board_Saw", (0.42, 0.03, 0.1), (x, y - 0.05, 1.1), m["orange"], 0.01)

def props(m):
    for i in range(3):
        tyre(m, -4.3, 1.75, 0.13 + i * 0.25)
    tyre(m, -3.65, 1.95, 0.34, axis="Y")
    for i, (x, y) in enumerate(((3.2, 3.45), (3.62, 3.35))):
        jerrycan(m, x, y, 0.15 * i)
    drum(m, 4.35, 3.35, m["orange"]); drum(m, 4.55, 2.6, m["olive"])
    crate(m, -4.4, 3.4, 0.7, 0.2)
    rock(m, 1.4, 3.85, 1.2)
    pine(m, 4.4, 4.2, 1.25); pine(m, -4.7, 4.3, 1.05)
    lantern(m, -0.42, 1.0, 1.25, 0.7)

def build(scene, m):
    truck(m); crane(m); lift(m); workbench(m); toolboard(m); props(m)

run_build(build)
