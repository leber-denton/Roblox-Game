#!/usr/bin/env python3
"""Generates src/Workspace/TradePlazaBeach.model.json: ocean tiles, beach props and palms around the Trade Plaza,
the lagoon shoreline, and the beach dressing inside the sun dome (Overhaul Phase 5).
Plaza centre is (0, 0, -1800). Run: python3 tools/gen_trade_beach.py"""
import json, math, random
random.seed(7)
CX, CZ = 0, -1800

def part(name, pos, size, color, material, shape="Block", rot=(0,0,0), transp=0, collide=True):
    return {"className": "Part", "name": name, "properties": {
        "Anchored": True, "CanCollide": collide, "CanQuery": collide,
        "Position": list(pos), "Orientation": list(rot), "Size": list(size),
        "Color": [c/255 for c in color], "Material": material, "Shape": shape,
        "Transparency": transp, "TopSurface": "Smooth", "BottomSurface": "Smooth"}}

def node(name, children):
    return {"className": "Folder", "name": name, "children": children}

kids = []
# ocean: 5x5 tiles of 2048 studs so no void shows at any angle
ocean = []
for i in range(-4, 5):
    for j in range(-4, 5):
        ocean.append(part("OceanTile", (CX+i*2048, -2.5, CZ+j*2048), (2048, 1, 2048), (52,165,222), "Glass", transp=0.15, collide=False))
ocean.append(part("OceanFloor", (CX, -30, CZ), (10240, 2, 10240), (230,208,150), "Sand"))
kids.append(node("Ocean", ocean))

# beach props outside the dome wall (wall radius 84, sand to 185)
props = []
def ring(r, a): return CX + r*math.cos(a), CZ + r*math.sin(a)
for n in range(28):  # palms
    a = n/28*2*math.pi + random.uniform(-.08,.08); r = random.uniform(98,160)
    x, z = ring(r, a); lean = random.uniform(-8,8); h = random.uniform(16,24)
    props.append(part("PalmTrunk", (x, h/2, z), (h, 2.4, 2.4), (140,100,60), "Wood", "Cylinder", rot=(lean,0,90)))
    for k in range(7):
        b = k/7*2*math.pi
        props.append(part("PalmLeaf", (x+4*math.cos(b), h+1, z+4*math.sin(b)), (9, .4, 3), (50,170,70), "Grass", rot=(0, -math.degrees(b), 18)))
for n in range(14):  # umbrellas + towels
    a = n/14*2*math.pi + .2; r = random.uniform(95,170)
    x, z = ring(r, a); col = random.choice([(255,110,120),(255,200,70),(90,200,160),(110,160,255)])
    props.append(part("UmbrellaPole", (x, 5, z), (10, .5, .5), (245,245,245), "SmoothPlastic", "Cylinder", rot=(0,0,90)))
    props.append(part("UmbrellaTop", (x, 10.5, z), (1.5, 12, 12), col, "Fabric", "Cylinder", rot=(0,0,90)))
    props.append(part("Towel", (x+4, .15, z+2), (4, .3, 7), col, "Fabric", rot=(0, random.uniform(0,180), 0)))
for n in range(40):  # rocks and shells
    a = random.uniform(0, 2*math.pi); r = random.uniform(100,180); x, z = ring(r, a); s = random.uniform(2,6)
    props.append(part("BeachRock", (x, s/3, z), (s, s, s), (170,160,150), "Slate", "Ball", rot=(0,random.uniform(0,180),0)))
kids.append(node("Props", props))


# --- tropical resort extras ---
resort = []
wood=(160,115,70); thatch=(214,184,110); white=(245,245,240)
# pier running out to sea from the south side
for i in range(14):
    resort.append(part("PierDeck", (CX+i*0+0, 1.2, CZ+170+i*8), (10, .8, 8.4), wood, "WoodPlanks"))
for i in range(0,14,2):
    for sx in (-4.5,4.5):
        resort.append(part("PierPost", (CX+sx, -1, CZ+170+i*8), (6, 1.2, 1.2), (110,80,50), "Wood", "Cylinder", rot=(0,0,90)))
resort.append(part("PierEndDeck", (CX, 1.2, CZ+290), (26, .8, 20), wood, "WoodPlanks"))
# tiki huts
for k,(a,r) in enumerate([(0.35,125),(1.1,135),(2.6,128),(4.0,132),(5.2,125)]):
    x,z=ring(r,a)
    resort.append(part("TikiFloor",(x,.6,z),(12,1.2,12),wood,"WoodPlanks"))
    for dx in (-5,5):
        for dz in (-5,5):
            resort.append(part("TikiPost",(x+dx,5,z+dz),(9,.8,.8),(110,80,50),"Wood","Cylinder",rot=(0,0,90)))
    resort.append(part("TikiRoof",(x,10.5,z),(1.5,16,16),thatch,"Fabric","Cylinder",rot=(0,45,90)))
    resort.append(part("Hammock",(x,3.5,z+1),(8,.4,3),(255,120,120) if k%2 else (110,190,240),"Fabric",rot=(0,0,12)))
# lifeguard tower
lx,lz=ring(150,1.8)
for dx in (-2.5,2.5):
    for dz in (-2.5,2.5):
        resort.append(part("TowerLeg",(lx+dx,5,lz+dz),(10,.7,.7),white,"Wood","Cylinder",rot=(0,0,90)))
resort.append(part("TowerCabin",(lx,11,lz),(7,6,7),white,"SmoothPlastic"))
resort.append(part("TowerRoof",(lx,15,lz),(9,.8,9),(255,90,90),"SmoothPlastic"))
resort.append(part("TowerFlag",(lx,18,lz),(4,.2,2.5),(255,215,60),"Fabric"))
# shoreline: an unbroken surf line on the sand's edge (r 186) and a turquoise lagoon band beyond it
for n in range(72):
    a=n/72*2*math.pi; x,z=ring(186,a)
    resort.append(part("Foam",(x,.15,z),(2*math.pi*186/72+1,.3,3.2),white,"SmoothPlastic",rot=(0,90-math.degrees(a),0),transp=.15,collide=False))
    xs,zs=ring(198,a)
    resort.append(part("Shallows",(xs,-1.9,zs),(2*math.pi*209/72+1,.4,22),(96,214,214),"Glass",rot=(0,90-math.degrees(a),0),transp=.35,collide=False))
# sailboats offshore
for k,(a,r) in enumerate([(0.9,330),(2.2,420),(4.4,380)]):
    x,z=ring(r,a)
    resort.append(part("BoatHull",(x,0,z),(14,3,5),(250,250,250),"SmoothPlastic",rot=(0,math.degrees(a)+90,0)))
    resort.append(part("BoatMast",(x,7,z),(14,.5,.5),(120,90,60),"Wood","Cylinder",rot=(0,0,90)))
    resort.append(part("BoatSail",(x,8,z),(9,10,.3),(255,110,110) if k%2 else (255,230,110),"Fabric",rot=(0,math.degrees(a)+90,0)))
kids.append(node("Resort", resort))

# --- inside the dome (sand r 85, wall r 84): beach dressing that stays clear of the stalls (r ~38),
# the palms (r ~37-67), the fountain (r 9) and the entrance side (+Z, 55-125 degrees), where players arrive.
inner = []
cols=[(255,110,120),(255,200,70),(90,200,160),(110,160,255),(255,150,80)]
for k,deg in enumerate([15,45,135,165,195,225,255,285,315,345]):
    a=math.radians(deg); x,z=ring(75,a); col=cols[k%len(cols)]
    inner.append(part("Towel",(x,.65,z),(4,.3,7),col,"Fabric",rot=(0,90-deg,0),collide=False))
    if k%2==0:
        xu,zu=ring(78,a+.06)
        inner.append(part("UmbrellaPole",(xu,4.5,zu),(9,.5,.5),white,"SmoothPlastic","Cylinder",rot=(0,0,85)))
        inner.append(part("UmbrellaTop",(xu,9.2,zu),(1.2,11,11),col,"Fabric","Cylinder",rot=(0,0,90)))
for k,(deg,r) in enumerate([(30,68),(150,70),(240,62),(300,70)]):
    x,z=ring(r,math.radians(deg))
    inner.append(part("BeachBall",(x,2,z),(3,3,3),cols[k],"SmoothPlastic","Ball"))
    inner.append(part("BeachBallBand",(x,2,z),(3.05,.6,3.05),white,"SmoothPlastic","Ball"))
for deg in (200,340):  # sandcastles between the fountain and the stalls
    x,z=ring(22,math.radians(deg))
    sand=(226,196,140)
    inner.append(part("CastleBase",(x,1,z),(2,8,8),sand,"Sand","Cylinder",rot=(0,0,90)))
    for dx,dz in ((-3,-3),(3,-3),(-3,3),(3,3)):
        inner.append(part("CastleTower",(x+dx,2.8,z+dz),(3.6,2.2,2.2),sand,"Sand","Cylinder",rot=(0,0,90)))
    inner.append(part("CastleKeep",(x,3.6,z),(3,3,3),sand,"Sand"))
    inner.append(part("CastleFlag",(x+.6,6.4,z),(1.6,1,.1),(255,90,90),"Fabric",collide=False))
    inner.append(part("CastleFlagPole",(x,6,z),(2.6,.2,.2),white,"Wood","Cylinder",rot=(0,0,90),collide=False))
# lifeguard chair at the back wall (-Z), facing the plaza
x,z=ring(72,math.radians(270))
for dx in (-2,2):
    for dz in (-1.5,1.5):
        inner.append(part("ChairLeg",(x+dx,3.5,z+dz),(7,.5,.5),white,"Wood","Cylinder",rot=(0,0,90)))
inner.append(part("ChairSeat",(x,7.2,z),(5,.6,4),(255,90,90),"SmoothPlastic"))
inner.append(part("ChairBack",(x,9.4,z-1.8),(5,4,.5),(255,90,90),"SmoothPlastic"))
inner.append(part("ChairSign",(x,12.6,z-1.8),(6,1.6,.3),(255,215,60),"SmoothPlastic"))
kids.append(node("DomeInterior", inner))

model = {"className": "Folder", "children": kids}
with open("src/Workspace/TradePlazaBeach.model.json", "w") as f: json.dump(model, f)
print(sum(len(k["children"]) for k in kids), "parts")
