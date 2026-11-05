#!/usr/bin/env python3
"""Generates src/Workspace/ColiseumRoman.model.json: Roman arcade facade, columns and terracotta roof.
Coliseum centre is (0, 0, -1200); entrance faces +Z. Run: python3 tools/gen_coliseum.py"""
import json, math
CX, CZ = 0, -1200
TRAV=(236,222,190); MARB=(247,242,232); DARK=(66,52,44); TERRA=(178,92,66); GOLD=(235,190,80)

def part(name, pos, size, color, material, shape="Block", rot=(0,0,0), collide=True):
    return {"className":"Part","name":name,"properties":{
        "Anchored":True,"CanCollide":collide,"CanQuery":collide,"Position":list(pos),"Orientation":list(rot),
        "Size":list(size),"Color":[c/255 for c in color],"Material":material,"Shape":shape,
        "TopSurface":"Smooth","BottomSurface":"Smooth"}}
def pt(r, th): return CX+r*math.cos(th), CZ+r*math.sin(th)
def yaw(th): return 90-math.degrees(th)   # local Z points radially outward

wall=[]; arc=[]; roof=[]
N=40; step=2*math.pi/N
for i in range(N):
    th=i*step
    x,z=pt(101,th)
    if abs(x)<10 and z>CZ: continue          # entrance gap
    wall.append(part("WallBody",(x,16.5,z),(17,33,3),TRAV,"Limestone",rot=(0,yaw(th),0)))
    x3,z3=pt(103.4,th)
    for t in range(3):
        y0=t*9
        arc.append(part("ArchOpening",(x3,y0+3,z3),(6.5,5,.5),DARK,"SmoothPlastic",rot=(0,yaw(th),0)))
        arc.append(part("ArchTop",(x3,y0+5.5,z3),(.5,6.5,6.5),DARK,"SmoothPlastic","Cylinder",rot=(0,180-math.degrees(th),0)))
    arc.append(part("Window",(x3,30,z3),(3,3,.5),DARK,"SmoothPlastic",rot=(0,yaw(th),0)))
    for y,h in ((9,.9),(18,.9),(27,1.1),(33.4,1.6)):
        xc,zc=pt(104,th)
        arc.append(part("Cornice",(xc,y,zc),(17.2,h,5.2),MARB,"Marble",rot=(0,yaw(th),0)))
    # engaged column between bays
    xp,zp=pt(104.2,th+step/2)
    arc.append(part("EngagedColumn",(xp,13.5,zp),(27,2.4,2.4),MARB,"Marble","Cylinder",rot=(0,0,90)))
# interior support columns + roof
for i in range(20):
    th=i/20*2*math.pi+0.05
    x,z=pt(76,th)
    if abs(x)<14 and z>CZ: continue
    roof.append(part("Column",(x,14.8,z),(29.6,2.8,2.8),MARB,"Marble","Cylinder",rot=(0,0,90)))
    roof.append(part("ColumnCap",(x,29.6,z),(2.0,5,5),GOLD,"Metal",rot=(0,yaw(th),0)))
M=56
for i in range(M):
    th=i/M*2*math.pi
    if abs(pt(89,th)[0])<12 and pt(89,th)[1]>CZ+40: pass
    x,z=pt(89,th)
    roof.append(part("RoofTile",(x,32.8,z),(12.6,1,38),TERRA,"Slate",rot=(-12,yaw(th),0)))
for i in range(M):
    th=(i+.5)/M*2*math.pi
    x,z=pt(106.5,th)
    roof.append(part("RoofEave",(x,36.6,z),(11.6,1.4,1.4),GOLD,"Metal",rot=(0,yaw(th),0)))

model={"className":"Folder","children":[
    {"className":"Folder","name":"Facade","children":wall+arc},
    {"className":"Folder","name":"Roof","children":roof}]}
json.dump(model,open("src/Workspace/ColiseumRoman.model.json","w"))
print(len(wall)+len(arc)+len(roof),"parts")
