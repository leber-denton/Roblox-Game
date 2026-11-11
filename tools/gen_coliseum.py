#!/usr/bin/env python3
"""Generates src/Workspace/ColiseumRoman.model.json: the Battle Coliseum's Roman shell.

Coliseum centre is (0, 0, -1200); the entrance faces +Z (|x| < 14). Run: python tools/gen_coliseum.py

Layout (radii from the centre; the arena sand, ArenaFloor, is r 100 and lives in the place file):
  - Facade: three-storey travertine arcade, outer wall r 101 (3 thick, 33 high), cornices, engaged columns.
  - Podium: r 89-90.5, 7 high, marble cap and a red frieze, with braziers on top.
  - Stands (cavea): three stone tiers, r 90.5-99.5, tops at y 11 / 15 / 19.
  - Gallery: arched niches, pilasters and banners on the inner wall face above the top tier (y 19-33),
    and an attic parapet (y 33-37) that seals the gap under the roof.
  - Velarium: a canvas roof in red and cream gores, rising from the rim (r 108, y 35.5) to a closed
    centre disc (r 22, y ~58); masts on the wall top.
    The canvas casts no shadow, so the arena keeps daylight while no sky shows from inside;
    eight fill lights under it keep the canvas underside and the stands from going flat grey.
  - Outside: paved approach to the exit portal, two obelisks, a ring of cypress trees.
The runtime ColiseumService fixtures (boards r 72-88.5, spectator screen, banners at r 83, torches at r 87)
were checked against these radii: none sits inside the stands.
"""
import json, math

CX, CZ = 0, -1200
TRAV = (226, 204, 162); MARB = (244, 236, 220); DARK = (58, 40, 30); TERRA = (178, 92, 66)
GOLD = (235, 190, 80); RED = (170, 48, 42); BLUE = (44, 74, 160); CREAM = (240, 228, 200)
CANVAS_RED = (176, 66, 50)
SEAT = (206, 178, 136); STONE = (176, 156, 128)


def part(name, pos, size, color, material, shape="Block", rot=(0, 0, 0), collide=True, shadow=True, children=None, transp=0):
    p = {"className": "Part", "name": name, "properties": {
        "Transparency": transp,
        "Anchored": True, "CanCollide": collide, "CanQuery": collide, "CanTouch": collide,
        "CastShadow": shadow, "Position": [round(v, 3) for v in pos],
        "Orientation": [round(v, 3) for v in rot], "Size": [round(v, 3) for v in size],
        "Color": [c / 255 for c in color], "Material": material, "Shape": shape,
        "TopSurface": "Smooth", "BottomSurface": "Smooth"}}
    if children:
        p["children"] = children
    return p


def folder(name, children):
    return {"className": "Folder", "name": name, "children": children}


def pt(r, th):
    return CX + r * math.cos(th), CZ + r * math.sin(th)


def yaw(th):
    return 90 - math.degrees(th)  # local Z points radially outward


def entrance(x, z, half=14):
    return abs(x - CX) < half and z > CZ


# ---------------------------------------------------------------- facade (outer arcade)
facade = []
N = 40; step = 2 * math.pi / N
for i in range(N):
    th = i * step
    x, z = pt(101, th)
    if entrance(x, z, 10):
        continue
    facade.append(part("WallBody", (x, 16.5, z), (17, 33, 3), TRAV, "Limestone", rot=(0, yaw(th), 0)))
    x3, z3 = pt(103.4, th)
    for t in range(3):
        y0 = t * 9
        facade.append(part("ArchOpening", (x3, y0 + 3, z3), (6.5, 5, .5), DARK, "SmoothPlastic", rot=(0, yaw(th), 0)))
        facade.append(part("ArchTop", (x3, y0 + 5.5, z3), (.5, 6.5, 6.5), DARK, "SmoothPlastic", "Cylinder", rot=(0, 180 - math.degrees(th), 0)))
    facade.append(part("Window", (x3, 30, z3), (3, 3, .5), DARK, "SmoothPlastic", rot=(0, yaw(th), 0)))
    for y, h in ((9, .9), (18, .9), (27, 1.1), (33.4, 1.6)):
        xc, zc = pt(104, th)
        facade.append(part("Cornice", (xc, y, zc), (17.2, h, 5.2), MARB, "Marble", rot=(0, yaw(th), 0)))
    xp, zp = pt(104.2, th + step / 2)
    facade.append(part("EngagedColumn", (xp, 13.5, zp), (27, 2.4, 2.4), MARB, "Marble", "Cylinder", rot=(0, 0, 90)))

# ---------------------------------------------------------------- podium and stands
stands = []
P = 60
for i in range(P):
    th = (i + .5) / P * 2 * math.pi
    x, z = pt(89.75, th)
    if entrance(x, z):
        continue
    w = 2 * math.pi * 91 / P + .3
    stands.append(part("PodiumWall", (x, 3.5, z), (w, 7, 1.5), MARB, "Marble", rot=(0, yaw(th), 0)))
    xc, zc = pt(89.8, th)
    stands.append(part("PodiumCap", (xc, 7.3, zc), (w + .4, .6, 2.4), MARB, "Marble", rot=(0, yaw(th), 0)))
    xf, zf = pt(88.95, th)
    stands.append(part("PodiumFrieze", (xf, 5, zf), (2 * math.pi * 89 / P + .3, 1, .2), RED, "SmoothPlastic", rot=(0, yaw(th), 0)))

T = 48
for k, (r0, top) in enumerate(((90.5, 11), (93.5, 15), (96.5, 19))):
    r1 = r0 + 3
    for i in range(T):
        th = (i + .5) / T * 2 * math.pi
        x, z = pt((r0 + r1) / 2, th)
        if entrance(x, z):
            continue
        w = 2 * math.pi * r1 / T + .3
        aisle = i % 6 == 0
        stands.append(part("StandAisle" if aisle else "StandTier", (x, top / 2, z), (w, top, 3.05),
                           STONE if aisle else SEAT, "Limestone" if not aisle else "Pavement", rot=(0, yaw(th), 0)))
        xe, ze = pt(r0 + .25, th)
        stands.append(part("TierEdge", (xe, top + .15, ze), (w, .3, .6), MARB, "Marble", rot=(0, yaw(th), 0)))

# braziers on the podium (clear of the entrance and of the runtime torches at about 29/151/209/331 degrees)
for deg in (0, 60, 120, 180, 240, 300, 45, 135, 225, 315):
    th = math.radians(deg)
    x, z = pt(89.8, th)
    if entrance(x, z, 20):
        continue
    stands.append(part("BrazierStand", (x, 8.6, z), (1.4, 2, 1.4), DARK, "Metal"))
    stands.append(part("BrazierBowl", (x, 10, z), (1, 3.2, 3.2), GOLD, "Metal", "Cylinder", rot=(0, 0, 90), children=[
        {"className": "Fire", "name": "Flame", "properties": {"Size": 4, "Heat": 6,
                                                            "Color": [1, .55, .2], "SecondaryColor": [1, .85, .3]}},
        {"className": "PointLight", "name": "Glow", "properties": {"Brightness": 1, "Range": 18,
                                                                 "Color": [1, .72, .4], "Shadows": True}}]))

# ---------------------------------------------------------------- upper gallery on the inner wall face
gallery = []
for i in range(N):
    th = i * step
    x, z = pt(99.2, th)
    if entrance(x, z):
        continue
    if i % 5 == 2:  # banner bay
        col = RED if (i // 5) % 2 == 0 else BLUE
        gallery.append(part("GalleryBanner", (x, 26, z), (6, 11, .3), col, "Fabric", rot=(0, yaw(th), 0)))
        xt, zt = pt(99.0, th)
        gallery.append(part("GalleryBannerTrim", (xt, 31.8, zt), (7, .6, .4), GOLD, "Metal", rot=(0, yaw(th), 0)))
        gallery.append(part("GalleryBannerTrim", (xt, 20.6, zt), (6, .4, .4), GOLD, "Metal", rot=(0, yaw(th), 0)))
    else:
        gallery.append(part("GalleryNiche", (x, 23.5, z), (6, 7, .5), DARK, "SmoothPlastic", rot=(0, yaw(th), 0)))
        gallery.append(part("GalleryNicheTop", (x, 27, z), (.5, 6, 6), DARK, "SmoothPlastic", "Cylinder", rot=(0, 180 - math.degrees(th), 0)))
    xp, zp = pt(98.9, th + step / 2)
    if not entrance(xp, zp):
        gallery.append(part("GalleryPilaster", (xp, 26, zp), (1.8, 14, 1.2), MARB, "Marble", rot=(0, yaw(th + step / 2), 0)))
for i in range(N):
    th = (i + .5) * step
    x, z = pt(100, th)
    if entrance(x, z, 10):
        continue
    w = 2 * math.pi * 101 / N + .3
    gallery.append(part("GalleryCornice", (x, 33.3, z), (w, .9, 2.4), MARB, "Marble", rot=(0, yaw(th), 0)))
    gallery.append(part("AtticParapet", (x, 35.2, z), (w, 3.4, 1.2), TRAV, "Limestone", rot=(0, yaw(th), 0)))

# ---------------------------------------------------------------- entrance: gate arch over the tunnel
gate = []
for sx in (-1, 1):
    gate.append(part("GatePier", (CX + sx * 13, 15, CZ + 89.5), (4, 30, 4), MARB, "Marble"))
gate.append(part("GateLintel", (CX, 31, CZ + 89.5), (30, 4, 4.4), MARB, "Marble"))
gate.append(part("GateInscription", (CX, 31, CZ + 87.2), (22, 2.2, .3), RED, "SmoothPlastic", collide=False))
gate.append(part("TunnelCeiling", (CX, 33.5, CZ + 95.5), (28, 1, 12), TRAV, "Limestone"))
for sx in (-1, 1):
    gate.append(part("TunnelWall", (CX + sx * 14.5, 16.5, CZ + 95.5), (1, 33, 12), TRAV, "Limestone"))

# ---------------------------------------------------------------- velarium roof
roof = []
R_RIM, Y_RIM, R_IN = 108.0, 35.5, 22.0
ALPHA = math.radians(15)
TAN = math.tan(ALPHA)


def vy(r):
    return Y_RIM + (R_RIM - r) * TAN


G = 40
rings = (R_IN, 30, 40, 52, 66, 80, 94, R_RIM)
for i in range(G):
    th = (i + .5) / G * 2 * math.pi
    for a, b in zip(rings[:-1], rings[1:]):
        rm = (a + b) / 2
        x, z = pt(rm, th)
        length = (b - a) / math.cos(ALPHA) + .4
        # cream base layer: full outer width, so the canvas is closed (same-colour overlaps are invisible)
        roof.append(part("Velarium", (x, vy(rm) + .3, z), (2 * math.pi * b / G + .4, .6, length), CREAM, "Fabric",
                         rot=(math.degrees(ALPHA), yaw(th), 0), shadow=False))
        if i % 2 == 0:  # straight terracotta stripe, 1.0 thick round the 0.6 base so it shows on both faces
            roof.append(part("VelariumStripe", (x, vy(rm) + .3, z),
                             (7, 1.0, length), CANVAS_RED, "Fabric",
                             rot=(math.degrees(ALPHA), yaw(th), 0), collide=False, shadow=False))
roof.append(part("CrownLight", (CX, vy(R_IN) - 6, CZ), (1, 1, 1), CREAM, "SmoothPlastic", collide=False, shadow=False, transp=1,
                 children=[{"className": "PointLight", "name": "Fill", "properties": {
                     "Brightness": .8, "Range": 40, "Color": [1, .93, .8], "Shadows": False}}]))
# warm fill lights under the canvas so its underside and the stands are not left in flat shade
for i in range(8):
    th = (i + .25) / 8 * 2 * math.pi
    x, z = pt(60, th)
    roof.append(part("CanvasLight", (x, vy(60) - 4, z), (1, 1, 1), CREAM, "SmoothPlastic", collide=False, shadow=False, transp=1,
                     children=[{"className": "PointLight", "name": "Fill", "properties": {
                         "Brightness": .9, "Range": 60, "Color": [1, .93, .8], "Shadows": False}}]))
yc = vy(R_IN)
roof.append(part("VelariumCrown", (CX, yc + .4, CZ), (.6, 2 * R_IN + 2, 2 * R_IN + 2), CREAM, "Fabric", "Cylinder", rot=(0, 0, 90), shadow=False))
for i in range(G):
    th = i / G * 2 * math.pi
    x, z = pt(R_IN, th)
    roof.append(part("CrownRing", (x, yc - .2, z), (2 * math.pi * R_IN / G + .3, 1.4, 1.4), GOLD, "Metal", rot=(0, yaw(th), 0), shadow=False))
for i in range(N):
    th = (i + .5) * step
    x, z = pt(104, th)
    if entrance(x, z, 10):
        continue
    roof.append(part("VelariumMast", (x, 40, z), (12, 1, 1), (120, 86, 52), "Wood", "Cylinder", rot=(0, 0, 90)))
    roof.append(part("MastTip", (x, 46.4, z), (1, 1, 1), GOLD, "Metal", "Ball"))
M = 56
for i in range(M):
    th = (i + .5) / M * 2 * math.pi
    x, z = pt(106.5, th)
    roof.append(part("RoofEave", (x, 36.6, z), (11.6, 1.4, 1.4), GOLD, "Metal", rot=(0, yaw(th), 0)))

# ---------------------------------------------------------------- grounds outside the wall
grounds = []
grounds.append(part("ApproachRoad", (CX, .15, CZ + 130), (18, .3, 58), STONE, "Pavement"))
for sx in (-1, 1):
    for zz in (118, 146):
        grounds.append(part("RoadCurb", (CX + sx * 9.5, .35, CZ + zz), (1, .7, 26), MARB, "Marble"))
    ox = CX + sx * 17
    grounds.append(part("ObeliskBase", (ox, 1.5, CZ + 124), (5, 3, 5), MARB, "Marble"))
    grounds.append(part("Obelisk", (ox, 12, CZ + 124), (2.6, 18, 2.6), TRAV, "Limestone"))
    grounds.append(part("ObeliskTip", (ox, 21.8, CZ + 124), (1.6, 1.6, 1.6), GOLD, "Metal"))
CY_TREES = 26
for n in range(CY_TREES):
    th = n / CY_TREES * 2 * math.pi + .06
    r = 128 + (n % 3) * 9
    x, z = pt(r, th)
    if entrance(x, z, 26):
        continue
    h = 13 + (n % 4) * 1.5
    grounds.append(part("CypressTrunk", (x, 1.5, z), (3, 1.2, 1.2), (100, 72, 48), "Wood", "Cylinder", rot=(0, 0, 90)))
    grounds.append(part("Cypress", (x, 3 + h * .35, z), (h * .7, 5, 5), (46, 88, 52), "Grass", "Cylinder", rot=(0, 0, 90)))
    grounds.append(part("Cypress", (x, 3 + h * .8, z), (h * .45, 3.4, 3.4), (52, 98, 58), "Grass", "Cylinder", rot=(0, 0, 90)))
    grounds.append(part("CypressTop", (x, 3 + h * 1.05, z), (2.6, 2.6, 2.6), (58, 106, 62), "Grass", "Ball"))

model = folder("RomanShell", [folder("Facade", facade), folder("Stands", stands), folder("Gallery", gallery),
                              folder("Gate", gate), folder("Roof", roof), folder("Grounds", grounds)])
del model["name"]
with open("src/Workspace/ColiseumRoman.model.json", "w") as f:
    json.dump(model, f)
print(sum(len(c["children"]) for c in model["children"]), "parts")
