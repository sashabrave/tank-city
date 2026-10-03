
# Room machines (RoomLayout spots), friendly casino look (author, 3 Oct): chunky rounded cabinets, a glowing
# marquee, rims of bulbs and a coloured light. Kept simple — a concept sheet with 4× fewer details, 15–25 parts each.
# Bulbs use two materials M_BulbA / M_BulbB: scripts/machine_model.gd blinks them in turn (chaser lights).
# Faces -Y (to the camera), origin at the floor centre, room units. MACHINE env var: medkit, ammo or slot.
import os

def emissive(name, color, strength=3.0):
    m = material(name, color + (1,), 0.35)
    b = m.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Emission Color"].default_value = color + (1,)
        b.inputs["Emission Strength"].default_value = strength
    return m

def bulbs(m, points, r=0.045):
    for i, p in enumerate(points):
        s = sphere("Bulb", r, location=p, u=8, v=5); assign(s, m["bulb_a"] if i % 2 == 0 else m["bulb_b"])

def rim(x0, x1, z0, z1, y, step=0.16):
    pts = []
    nx = max(2, int((x1 - x0) / step)); nz = max(2, int((z1 - z0) / step))
    for i in range(nx + 1): pts.append((x0 + (x1 - x0) * i / nx, y, z1))
    for i in range(1, nz + 1): pts.append((x1, y, z1 - (z1 - z0) * i / nz))
    for i in range(1, nx + 1): pts.append((x1 - (x1 - x0) * i / nx, y, z0))
    for i in range(1, nz): pts.append((x0, y, z0 + (z1 - z0) * i / nz))
    return pts

def tray(m, y, z, w=0.42):
    B("Tray", (w, 0.16, 0.14), (0, y - 0.04, z), m["black"], 0.04)
    B("Tray_Lip", (w + 0.04, 0.04, 0.05), (0, y - 0.12, z - 0.05), m["metal"], 0.015)

def medkit(m):
    W, D, H = 0.86, 0.62, 1.62
    B("Cab", (W, D, H), (0, 0, H / 2 + 0.06), m["white"], 0.12)
    B("Cab_Stripe", (W + 0.02, D + 0.02, 0.12), (0, 0, 0.42), m["mint"], 0.04)
    for x in (-0.3, 0.3):
        B("Foot", (0.14, 0.4, 0.06), (x, 0, 0.03), m["iron"], 0.02)
    y = -D / 2
    B("Window", (0.6, 0.04, 0.62), (0, y - 0.005, 1.15), m["glass"], 0.03)
    for i, z in enumerate((0.95, 1.25)):
        B("Shelf", (0.56, 0.06, 0.03), (0, y + 0.0, z - 0.1), m["metal"], 0)
        for j, x in enumerate((-0.17, 0.17)):
            B("Kit", (0.22, 0.06, 0.16), (x, y - 0.03, z), m["white"], 0.03)
            B("Kit_Cross", (0.1, 0.02, 0.03), (x, y - 0.065, z), m["red"], 0)
            B("Kit_Cross", (0.03, 0.02, 0.1), (x, y - 0.065, z), m["red"], 0)
    bulbs(m, rim(-0.33, 0.33, 0.82, 1.48, y - 0.04, 0.165))
    # marquee: a round sign with a big glowing cross on top
    C("Sign_Disc", 0.34, 0.1, (0, 0, H + 0.36), m["red"], 20, axis="Y", w=0.03)
    C("Sign_Ring", 0.36, 0.08, (0, 0.01, H + 0.36), m["white"], 20, axis="Y")
    B("Sign_Cross", (0.36, 0.05, 0.12), (0, -0.07, H + 0.36), m["glow_white"], 0.02)
    B("Sign_Cross", (0.12, 0.05, 0.36), (0, -0.07, H + 0.36), m["glow_white"], 0.02)
    B("Sign_Neck", (0.12, 0.1, 0.16), (0, 0, H + 0.1), m["white"], 0.02)
    B("Coin_Panel", (0.18, 0.04, 0.2), (0.24, y - 0.01, 0.66), m["mint"], 0.02)
    B("Coin_Slot", (0.03, 0.02, 0.1), (0.24, y - 0.035, 0.7), m["glow_warm"], 0)
    tray(m, y, 0.62, 0.32)

def ammo(m):
    # gacha machine: a cabinet, a «glass» dome of pastel capsules, a crank, a cartridge sign
    W, D, H = 0.82, 0.68, 0.95
    B("Cab", (W, D, H), (0, 0, H / 2 + 0.06), m["teal"], 0.12)
    B("Cab_Top", (W + 0.06, D + 0.06, 0.1), (0, 0, H + 0.08), m["brass"], 0.04)
    for x in (-0.3, 0.3):
        B("Foot", (0.14, 0.44, 0.06), (x, 0, 0.03), m["iron"], 0.02)
    dz = H + 0.5
    dome = sphere("Dome", 0.38, location=(0, 0, dz), u=20, v=12); assign(dome, m["dome"])
    caps = ["cap_orange", "cap_blue", "cap_yellow", "cap_cyan", "cap_red"]
    k = 0
    for ring, (zz, rr, n) in enumerate(((-0.12, 0.36, 8), (0.1, 0.34, 7), (0.27, 0.22, 5))):
        for i in range(n):
            a = (i + 0.5 * ring) * math.tau / n
            c = sphere("Capsule", 0.085, location=(math.cos(a) * rr * 0.95, math.sin(a) * rr * 0.95, dz + zz), u=8, v=6); assign(c, m[caps[k % 5]]); k += 1
    C("Dome_Cap", 0.12, 0.08, (0, 0, dz + 0.4), m["brass"], 12, w=0.02)
    C("Dome_Collar", 0.36, 0.08, (0, 0, H + 0.16), m["brass"], 20, w=0.02)
    y = -D / 2
    # crank and the capsule chute
    C("Crank_Disc", 0.13, 0.05, (0, y - 0.02, 0.72), m["brass"], 16, axis="Y", w=0.01)
    B("Crank_Bar", (0.24, 0.05, 0.05), (0, y - 0.06, 0.72), m["metal"], 0.015, rot=(0, math.radians(30), 0))
    C("Crank_Knob", 0.04, 0.08, (0.1, y - 0.1, 0.78), m["red"], 8, axis="Y")
    B("Chute", (0.26, 0.08, 0.2), (0, y - 0.03, 0.3), m["black"], 0.05)
    B("Chute_Flap", (0.22, 0.03, 0.12), (0, y - 0.075, 0.32), m["glow_teal"], 0.02)
    bulbs(m, rim(-0.33, 0.33, 0.18, 0.92, y - 0.02, 0.18))
    # cartridge sign on a short post at the back
    B("Sign_Post", (0.06, 0.06, 0.5), (0.3, 0.22, H + 0.4), m["iron"], 0.01)
    B("Sign_Board", (0.46, 0.06, 0.24), (0.3, 0.2, H + 0.72), m["teal"], 0.03)
    C("Sign_Round", 0.04, 0.24, (0.3, 0.16, H + 0.72), m["glow_warm"], 8, axis="X")
    C("Sign_Tip", 0.04, 0.08, (0.46, 0.16, H + 0.72), m["glow_teal"], 8, axis="X", top=0.005)

def slot(m):
    # built ×1/1.25: slot_machine.gd scales its node by 1.25
    W, D = 0.86, 0.64
    B("Base", (W + 0.06, D + 0.04, 0.55), (0, 0, 0.3), m["red_dark"], 0.08)
    B("Cab", (W, D, 0.7), (0, -0.0, 0.92), m["red"], 0.1)
    arch = profile_extrude("Arch", [(-W / 2, 0), (W / 2, 0), (W / 2, 0.12), (0.3, 0.3), (0, 0.36), (-0.3, 0.3), (-W / 2, 0.12)], D - 0.04,
                           location=(0, D / 2 - 0.02, 1.27), rotation=(math.radians(90), 0, 0))
    assign(arch, m["gold"]); soft(arch, 0.03)
    y = -D / 2
    B("Marquee", (0.56, 0.03, 0.14), (0, y - 0.0, 1.43), m["glow_warm"], 0.02)
    bulbs(m, [(math.sin(a) * 0.4, y - 0.02, 1.33 + math.cos(a) * 0.26) for a in [math.radians(d) for d in range(-80, 81, 20)]], 0.04)
    B("Reel_Frame", (0.7, 0.05, 0.34), (0, y - 0.0, 0.98), m["gold"], 0.03)
    for i, x in enumerate((-0.22, 0.0, 0.22)):
        B("Reel", (0.18, 0.04, 0.26), (x, y - 0.03, 0.98), m["reel"], 0.02)
        B("Reel_Mark", (0.08, 0.02, 0.08), (x, y - 0.055, 0.98), (m["red"], m["gold"], m["cap_blue"])[i], 0.02, rot=(0, math.radians(45), 0))
    B("Ledge", (W + 0.04, 0.24, 0.05), (0, y - 0.08, 0.6), m["gold"], 0.02)
    B("Button", (0.1, 0.06, 0.04), (-0.2, y - 0.12, 0.64), m["glow_red"], 0.015)
    B("Button", (0.1, 0.06, 0.04), (0.0, y - 0.12, 0.64), m["glow_warm"], 0.015)
    tray(m, y, 0.2, 0.46)
    # lever on the right side
    C("Lever_Hub", 0.09, 0.08, (W / 2 + 0.04, 0, 0.95), m["metal"], 12, axis="X")
    C("Lever_Arm", 0.025, 0.42, (W / 2 + 0.08, 0, 1.15), m["metal"], 8)
    sphere_ = sphere("Lever_Ball", 0.07, location=(W / 2 + 0.08, 0, 1.38), u=10, v=7); assign(sphere_, m["glow_red"])
    C("Topper_Star", 0.1, 0.05, (0, 0.0, 1.68), m["glow_warm"], 5, axis="Y")

def build(scene, m):
    m["white"] = material("M_MachineWhite", (0.93, 0.92, 0.88, 1), 0.45)
    m["mint"] = material("M_Mint", (0.45, 0.80, 0.68, 1), 0.5)
    m["teal"] = material("M_Teal", (0.16, 0.42, 0.45, 1), 0.5)
    m["red_dark"] = material("M_RedDark", (0.55, 0.12, 0.10, 1), 0.5)
    m["brass"] = material("M_Brass", (0.95, 0.70, 0.28, 1), 0.3, 1.0)
    m["dome"] = material("M_Dome", (0.62, 0.84, 0.90, 1), 0.1)
    m["reel"] = emissive("M_Reel", (1.0, 0.96, 0.86), 0.8)
    m["bulb_a"] = emissive("M_BulbA", (1.0, 0.85, 0.5), 2.5)
    m["bulb_b"] = emissive("M_BulbB", (1.0, 0.85, 0.5), 2.5)
    m["glow_warm"] = emissive("M_GlowWarm", (1.0, 0.78, 0.35), 1.6)
    m["glow_red"] = emissive("M_GlowRed", (1.0, 0.25, 0.2), 1.8)
    m["glow_white"] = emissive("M_GlowWhite", (1.0, 0.97, 0.92), 1.2)
    m["glow_teal"] = emissive("M_GlowTeal", (0.45, 0.95, 1.0), 2.5)
    for k, c in (("cap_orange", (1.0, 0.55, 0.3)), ("cap_blue", (0.5, 0.75, 1.0)), ("cap_yellow", (1.0, 0.85, 0.35)),
                 ("cap_cyan", (0.5, 0.95, 0.9)), ("cap_red", (1.0, 0.45, 0.45))):
        m[k] = material("M_" + k.title().replace("_", ""), c + (1,), 0.35)
    {"medkit": medkit, "ammo": ammo, "slot": slot}[os.environ["MACHINE"]](m)

run_build(build)
