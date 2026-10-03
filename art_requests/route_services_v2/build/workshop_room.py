
# HQ workshop room: the map stop up close — a ramp under a wooden canopy where the game's HQ vehicle stands
# (placed by service_room.gd at (0, RAMP_H, -2.6), nose to the camera), the orange fuel pump, tool rack, tyres
# and jerrycans. The room camera looks from high above, so the canvas covers only the back of the canopy and the
# front is open steel bows (like the merchant truck's rolled-back tarp).
CAN_X, CAN_Y0, CAN_Y1 = 2.25, 2.15, 4.35
ROOF_Z = 3.0
RAMP_Y = 2.6
RAMP_H = 0.18

def canopy(m):
    for x in (-CAN_X, CAN_X):
        for y in (CAN_Y0, CAN_Y1):
            B("Canopy_Post", (0.22, 0.22, ROOF_Z), (x, y, ROOF_Z / 2), m["wood"], 0.04)
            B("Canopy_Foot", (0.34, 0.34, 0.16), (x, y, 0.08), m["iron"], 0.03)
            B("Canopy_Bracket", (0.3, 0.3, 0.22), (x, y, ROOF_Z - 0.1), m["iron"], 0.03)
        B("Canopy_SideBeam", (0.18, CAN_Y1 - CAN_Y0 + 0.5, 0.2), (x, (CAN_Y0 + CAN_Y1) / 2, ROOF_Z + 0.05), m["wood_dark"], 0.03)
    for y in (CAN_Y0, CAN_Y1):
        B("Canopy_Beam", (2 * CAN_X + 0.3, 0.18, 0.2), (0, y, ROOF_Z + 0.05), m["wood_dark"], 0.03)
    # steel bows over the open front half, canvas pulled over the back half with a roll at its edge
    for i in range(3):
        y = CAN_Y0 + 0.1 + i * 0.5
        B("Canopy_Bow", (2 * CAN_X + 0.1, 0.07, 0.07), (0, y, ROOF_Z + 0.45), m["metal"], 0.02)
        for s in (-1, 1):
            B("Canopy_BowSide", (0.07, 0.07, 0.42), (s * CAN_X, y, ROOF_Z + 0.25), m["metal"], 0.02)
    y0 = CAN_Y0 + 1.25; depth = CAN_Y1 + 0.35 - y0; cy = y0 + depth / 2
    B("Canopy_Top", (2.2, depth, 0.14), (0, cy, ROOF_Z + 0.5), m["canvas"], 0.06)
    for s in (-1, 1):
        B("Canopy_Slope", (1.35, depth, 0.14), (s * 1.62, cy, ROOF_Z + 0.24), m["canvas"], 0.06, rot=(0, s * math.radians(24), 0))
    C("Canopy_Roll", 0.2, 2 * CAN_X + 0.3, (0, y0 - 0.05, ROOF_Z + 0.55), m["canvas"], 12, axis="X", w=0.03)
    for x in (-1.3, 1.3):
        C("Canopy_RollStrap", 0.22, 0.1, (x, y0 - 0.05, ROOF_Z + 0.55), m["wood_dark"], 12, axis="X")
    for x in (-1.0, 1.0):   # work lamps hanging from the front beam
        C("Lamp_Cord", 0.012, 0.45, (x, CAN_Y0, ROOF_Z - 0.2), m["black"], 4)
        C("Lamp_Shade", 0.2, 0.16, (x, CAN_Y0, ROOF_Z - 0.48), m["iron"], 10, top=0.07)
        C("Lamp_Bulb", 0.1, 0.06, (x, CAN_Y0, ROOF_Z - 0.58), m["glow"], 8)

def ramp(m):
    B("Ramp_Deck", (2.2, 2.6, RAMP_H), (0, RAMP_Y, RAMP_H / 2), m["concrete"], 0.04)
    for s in (-1, 1):
        B("Ramp_Slope", (2.2, 0.7, RAMP_H), (0, RAMP_Y + s * 1.6, RAMP_H / 2 - 0.04), m["concrete"], 0.04, rot=(s * math.radians(-12), 0, 0))
        B("Ramp_Kerb", (0.1, 2.6, 0.1), (s * 1.08, RAMP_Y, RAMP_H + 0.05), m["yellow"], 0.02)
    for i in range(2):
        for s in (-1, 1):
            B("Ramp_Chevron", (0.55, 0.15, 0.02), (s * 0.22, RAMP_Y - 1.75 - i * 0.36, 0.05), m["yellow"], 0, rot=(0, 0, s * math.radians(35)))

def pump(m):
    x, y = 2.95, 2.35
    B("Pump_Base", (0.6, 0.5, 0.12), (x, y, 0.06), m["iron"], 0.02)
    B("Pump_Body", (0.5, 0.4, 1.3), (x, y, 0.77), m["orange"], 0.07)
    B("Pump_Top", (0.56, 0.46, 0.12), (x, y, 1.47), m["cream"], 0.03)
    B("Pump_Lamp", (0.24, 0.05, 0.12), (x, y - 0.21, 1.28), m["glow"], 0.02)
    B("Pump_Panel", (0.3, 0.05, 0.34), (x, y - 0.21, 0.9), m["cream"], 0.02)
    for i in range(3):
        B("Pump_Digit%d" % i, (0.06, 0.02, 0.1), (x - 0.08 + i * 0.08, y - 0.24, 0.95), m["black"], 0)
    B("Pump_Nozzle", (0.09, 0.14, 0.28), (x - 0.29, y - 0.05, 0.62), m["black"], 0.02)
    hose = curve_tube("Pump_Hose", [(x - 0.29, y - 0.05, 0.48), (x - 0.4, y - 0.25, 0.12), (x - 0.15, y - 0.4, 0.05), (x, y - 0.2, 0.3)], 0.03)
    assign(hose, m["black"])

def toolrack(m):
    x, y = -3.25, 3.4
    B("Rack_Frame", (1.4, 0.5, 0.06), (x, y, 1.6), m["iron"], 0.02)
    for dx in (-0.66, 0.66):
        B("Rack_Leg", (0.07, 0.5, 1.6), (x + dx, y, 0.8), m["iron"], 0.01)
    for z in (0.3, 0.95):
        B("Rack_Shelf", (1.36, 0.48, 0.05), (x, y, z), m["wood"], 0.01)
    B("Rack_Box", (0.5, 0.36, 0.3), (x - 0.35, y, 0.48), m["olive"], 0.03)
    B("Rack_Box", (0.4, 0.34, 0.26), (x + 0.3, y, 0.46), m["red"], 0.03)
    B("Rack_Radio", (0.42, 0.26, 0.28), (x - 0.3, y, 1.12), m["olive_dark"], 0.03)
    C("Rack_Antenna", 0.012, 0.45, (x - 0.18, y, 1.48), m["metal"], 6)
    C("Rack_Can", 0.09, 0.22, (x + 0.35, y, 1.09), m["yellow"], 8)

def props(m):
    for i in range(2):
        tyre(m, 3.85, 3.4, 0.13 + i * 0.25, 0.38, 0.24)
    for i, (x, y) in enumerate(((-2.75, 2.25), (-2.35, 2.35))):
        jerrycan(m, x, y, 0.2 * i)
    drum(m, -4.25, 2.4, m["olive"])
    crate(m, 3.0, 3.75, 0.7, -0.15)
    pine(m, -4.45, 4.2, 1.2); pine(m, 4.5, 4.3, 1.0)

def build(scene, m):
    ramp(m); canopy(m); pump(m); toolrack(m); props(m)

run_build(build)
