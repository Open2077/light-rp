#!/usr/bin/env python3
"""Cook the original blackjack table, 52 cards + back/turn poses and chip stacks.

Uses the native board-prop cooker (tools/build-board-game-props.py) as a
read-only schema/tool library and tools/casino_art.py for the HUD typeface,
suit shapes and preview renders. Only this resource and --work receive outputs.
Requires Pillow + numpy for the original top print, card and chip artwork, lupa
(prints the limits from the shared rules), plus .NET and WolvenKit from the lab.

Art direction: a high-end Night City table. Dark composite top whose printed
betting circles and rules glow (the print is its own Emissive map), a padded
black leather armrest on a polished chrome lip, a neon line under the rail, a
black chrome skirt and pedestal on a lit floor ring, a sleek shoe, a chip rack
of layered rolls and a discard tray. Cards: ivory faces with jumbo HUD indices
and original geometric court figures, a black/magenta circuit back. Chips:
layered machined discs, edge inserts and a colour ring per denomination.

Coordinates are unscaled metres (the client renders every prop at 0.65). The
table origin is the floor under the centre of the felt arc; the top is at
Z=1.35, players sit around the arc at -Y and the dealer stands at +Y (nothing
of the table reaches past the apron at y=0.26: the croupier stands there).
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,random,struct,subprocess,sys,zipfile
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFilter
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import casino_art as art
import mesh_checks
RESOURCE=ROOT/'resources/assets/models/open77_casino_blackjack'
DEPOT='open77\\assets\\op77_lightrp\\casino_blackjack'
LAB=ROOT.parent/'dop-tests'
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()
# Player collision (tools/COLLISION.md): <base>_collider.ent, boxes in table-local metres before the 0.65 scale.
spec=importlib.util.spec_from_file_location('collision_props',ROOT/'tools/collision_props.py');col=importlib.util.module_from_spec(spec);spec.loader.exec_module(col)

# Layout shared with client/core/casino_blackjack.lua.
FZ=1.35;FELT_R=1.00;RAIL_R=1.12;DEALER_EDGE=.14;APRON=.26
SEAT_ANGLES=[54,18,-18,-54]
SEAT_R=.80;CARD_R=.55
CARD_W,CARD_H,CARD_T=.100,.130,.0016
CARD_STEP=CARD_T+.0008   # client: each overlapping card a thickness + 0.8 mm above the previous one
CHIP_R,CHIP_T=.030,.0052
RANKS='A23456789TJQK';SUITS='SHDC'
# Denomination, most chips in one stack prop, body colour, edge-insert colour, ring colour.
DENOMS=[(1,4,'#E8E6E1','#1B9FD0','#22E6FF'),(5,4,'#B3122E','#F1EEE8','#FF4D6A'),(25,3,'#0F6B4A','#F1EEE8','#3DFFB0'),
        (100,4,'#16171C','#D8B25A','#F2C14E'),(500,1,'#4B1F86','#E9E4F5','#B07CFF'),(1000,10,'#C9922B','#16171C','#FFE08A')]
# Table body: the arc of the rail and the apron (the croupier stands beyond y=APRON).
COLLIDERS={'blackjack_table':[col.Box.between((-1.12,-.45,0),(1.12,APRON,FZ+.05)),
                              col.Box.between((-.85,-.80,0),(.85,-.45,FZ+.05)),
                              col.Box.between((-.45,-1.03,0),(.45,-.80,FZ+.05))]}

# Materials: key -> (sRGB colour or texture name, roughness, metalness, emissive EV or None).
EMISSIVE=True
MATERIALS={
 'TEX:felt':('bj_felt',.55,.1,.6),       # the top's print glows (dark composite barely emits)
 'TEX:cards':('bj_cards',.5,0,None),
 'TEX:chips':('bj_chips',.35,.1,None),
 'card_edge':('#EDEAE1',.55,0,None),
 'leather':('#15151A',.5,0,None),
 'black_chrome':('#121319',.16,.9,None),
 'graphite':('#23262F',.42,.55,None),
 'chrome':('#D9DEE6',.08,1.0,None),
 'smoke':('#0B0D12',.08,.35,None),        # shoe and tray bodies: smoked glossy shell
 'neon_cyan':('#22E6FF',.3,0,4.0),
 'neon_magenta':('#FF2E9E',.3,0,4.0),
}
for _,_,body,insert,ring in DENOMS:
 MATERIALS.setdefault('chip:'+body,(body,.35,0,None));MATERIALS.setdefault('chip:'+insert,(insert,.35,0,None))
TEX={k:v[0] for k,v in MATERIALS.items() if k.startswith('TEX:')}

def rules():
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute('LightRpBoardGames={};LightRpItems={}')
 lua.execute((ROOT/'resources/gamemodes/op77_lightrp/shared/casino_blackjack.lua').read_text())
 B=lua.globals().LightRpBlackjack
 return {'min':B.MIN_BET,'max':B.MAX_BET}

def tri(out,a,b,c,color,uv=None):
 f={'a':list(a),'b':list(b),'c':list(c),'color':color}
 if uv:f['uv']=[list(x) for x in uv]
 out.append(f)
def quad(out,p,color,uv=None):
 tri(out,p[0],p[1],p[2],color,uv and (uv[0],uv[1],uv[2]));tri(out,p[0],p[2],p[3],color,uv and (uv[0],uv[2],uv[3]))
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def oriented(out,p,color,outward,uv=None):
 """Quad whose winding is flipped if needed so its normal points along `outward`."""
 n=cross([p[1][i]-p[0][i] for i in range(3)],[p[2][i]-p[0][i] for i in range(3)])
 if sum(n[i]*outward[i] for i in range(3))<0:p=p[::-1];uv=uv[::-1] if uv else None
 quad(out,p,color,uv)
def box(out,x0,x1,y0,y1,z0,z1,color,skip=()):
 """Axis-aligned box, outward faces. `skip` leaves out faces that touch another
 surface ('-z' = the base sitting on the top, '+y' = a face against a wall...):
 a hidden face coincident with a visible one z-fights in game."""
 sides={'-x':([(x0,y0,z0),(x0,y1,z0),(x0,y1,z1),(x0,y0,z1)],[-1,0,0]),'+x':([(x1,y0,z0),(x1,y1,z0),(x1,y1,z1),(x1,y0,z1)],[1,0,0]),
        '-y':([(x0,y0,z0),(x1,y0,z0),(x1,y0,z1),(x0,y0,z1)],[0,-1,0]),'+y':([(x0,y1,z0),(x1,y1,z0),(x1,y1,z1),(x0,y1,z1)],[0,1,0]),
        '-z':([(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0)],[0,0,-1]),'+z':([(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)],[0,0,1])}
 assert set(skip)<=set(sides),skip
 for key,(pts,n) in sides.items():
  if key not in skip:oriented(out,[list(v) for v in pts],color,n)
def drop_plane(faces,z):
 """Leave out the flat faces lying in the plane Z=z (a cap resting on, or under, another part)."""
 return [f for f in faces if max(abs(f[k][2]-z) for k in ('a','b','c'))>1e-9]
def transform(faces,fn):
 for f in faces:
  for k in ('a','b','c'):f[k]=list(fn(*f[k]))
 return faces
def extrude_yz(out,poly,x0,x1,side,edge=None,floor=None):
 """Extrude a (y,z) polygon between x0 and x1; `edge(outward)` picks each rim face's material.
 A rim face lying at Z=`floor` (the base on the top) is left out."""
 area=sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly)))
 if area<0:poly=poly[::-1]
 for a,b,c in base.triangulate(poly):
  for x,n in ((x0,-1),(x1,1)):
   pts=[(x,*poly[a]),(x,*poly[b]),(x,*poly[c])]
   nn=cross([pts[1][i]-pts[0][i] for i in range(3)],[pts[2][i]-pts[0][i] for i in range(3)])
   if nn[0]*n<0:pts=pts[::-1]
   tri(out,*pts,side)
 for i in range(len(poly)):
  (y0,z0),(y1,z1)=poly[i],poly[(i+1)%len(poly)];outward=[0,z1-z0,-(y1-y0)]
  if floor is not None and abs(z0-floor)<1e-12 and abs(z1-floor)<1e-12:continue
  oriented(out,[(x0,y0,z0),(x1,y0,z0),(x1,y1,z1),(x0,y1,z1)],edge(outward) if edge else side,outward)

# --- Card atlas: 13 ranks x 4 suits, back at row 4 -------------------------
ATLAS_W,ATLAS_H,CELL_W,CELL_H=2048,1024,157,204
def cell_uv(col,row):
 x0,y0=col*CELL_W+1.5,row*CELL_H+1.5;x1,y1=(col+1)*CELL_W-1.5,(row+1)*CELL_H-1.5
 return x0/ATLAS_W,y0/ATLAS_H,x1/ATLAS_W,y1/ATLAS_H
def card_cell(code):return RANKS.index(code[0]),SUITS.index(code[1])
BACK_CELL=(0,4)
def card_faces(top,bottom,edge='card_edge'):
 """A flat card lying on Z=0: top/bottom are atlas cells or None for a blank side."""
 out=[];w,h,t=CARD_W/2,CARD_H/2,CARD_T
 def side(z,cell,down):
  pts=[[-w,-h,z],[w,-h,z],[w,h,z],[-w,h,z]]
  if cell is None:
   oriented(out,pts,edge,[0,0,-1 if down else 1]);return
  u0,v0,u1,v1=cell_uv(*cell)
  uv=[[u0,v1],[u1,v1],[u1,v0],[u0,v0]]
  if down:uv=[[u1,v1],[u0,v1],[u0,v0],[u1,v0]]
  oriented(out,pts,'TEX:cards',[0,0,-1 if down else 1],uv)
 side(t,top,False);side(0,bottom,True)
 for a,b,n in (((-w,-h),(w,-h),[0,-1,0]),((w,-h),(w,h),[1,0,0]),((w,h),(-w,h),[0,1,0]),((-w,h),(-w,-h),[-1,0,0])):
  oriented(out,[[a[0],a[1],0],[b[0],b[1],0],[b[0],b[1],t],[a[0],a[1],t]],edge,n)
 return out
def turned_card():
 """Generic half-turned pose: back up, tilted 70 degrees on its long axis, face blank."""
 out=card_faces(BACK_CELL,None);th=math.radians(70);lift=CARD_W/2*math.sin(th)
 for f in out:
  for k in ('a','b','c'):
   x,y,z=f[k];f[k]=[x*math.cos(th)-z*math.sin(th),y,x*math.sin(th)+z*math.cos(th)+lift]
 return out

# --- Chips: layered machined discs ----------------------------------------------
CHIP_CELL=170
def chip_uv(index,x,y):
 col,row=index%3,index//3;cx,cy=(col*CHIP_CELL+85)/512,(row*CHIP_CELL+85)/512;r=80/512
 return [cx+x/CHIP_R*r,cy-y/CHIP_R*r]
def chips(index,count,sides=32,top_texture=True,radius=CHIP_R,thick=CHIP_T):
 """`count` stacked chips from z=0: chamfered edges, edge inserts, textured top."""
 out=[];_,_,body,insert,_=DENOMS[index];body,insert='chip:'+body,'chip:'+insert;c=thick*.16;r=radius;ri=r-c
 def ring(z0,r0,z1,r1,color_at):
  for j in range(sides):
   a,b=j*math.tau/sides,(j+1)*math.tau/sides;m=(a+b)/2
   p=[[r0*math.cos(a),r0*math.sin(a),z0],[r0*math.cos(b),r0*math.sin(b),z0],[r1*math.cos(b),r1*math.sin(b),z1],[r1*math.cos(a),r1*math.sin(a),z1]]
   oriented(out,p,color_at(j),[math.cos(m),math.sin(m),.6 if r1<r0 else -.6 if r0<r1 else 0])
 for i in range(count):
  z0,z1=i*thick,(i+1)*thick
  ring(z0,ri,z0+c,r,lambda j:body)
  ring(z0+c,r,z1-c,r,lambda j,i=i:insert if (j+2*i)%4==0 else body)
  ring(z1-c,r,z1,ri,lambda j:body)
 top=count*thick
 for j in range(sides):
  a,b=j*math.tau/sides,(j+1)*math.tau/sides
  pa=[ri*math.cos(a),ri*math.sin(a),top];pb=[ri*math.cos(b),ri*math.sin(b),top]
  if top_texture:tri(out,[0,0,top],pa,pb,'TEX:chips',[chip_uv(index,0,0),chip_uv(index,pa[0],pa[1]),chip_uv(index,pb[0],pb[1])])
  else:tri(out,[0,0,top],pa,pb,body)
  tri(out,[0,0,0],[pb[0],pb[1],0],[pa[0],pa[1],0],body)
 return out

# --- The table ------------------------------------------------------------------
def felt_uv(x,y):return [(x+1.04)/2.08,(.16-y)/1.20]
def arc(r,steps=96):return [(r*math.cos(math.pi+math.pi*i/steps),r*math.sin(math.pi+math.pi*i/steps)) for i in range(steps+1)]
def fan(out,outline,z,color,center,down=False,uvf=None):
 for p,q in zip(outline,outline[1:]+outline[:1]):
  pts=[[center[0],center[1],z],[p[0],p[1],z],[q[0],q[1],z]]
  uv=[uvf(*pt[:2]) for pt in pts] if uvf else None
  n=cross([pts[1][i]-pts[0][i] for i in range(3)],[pts[2][i]-pts[0][i] for i in range(3)])
  if (n[2]<0)!=down:pts=pts[::-1];uv=uv[::-1] if uv else None
  tri(out,*pts,color,uv)
def sweep(out,path,profile,color):
 """Sweep a (radial offset, z) profile along a path of (x,y,outward-x,outward-y).
 The profile runs with the solid on its right (up the inner wall, over the top,
 down the outside), so a face's outward normal is the profile direction turned
 left, (-dz, dr) in (radial, z). (The former per-material centre point turned
 the chrome lip's wall and bevel away from the players: culled, they left a
 see-through slit under a sliver of chrome that shimmered in game.)"""
 for (x0,y0,nx0,ny0),(x1,y1,nx1,ny1) in zip(path,path[1:]):
  nx,ny=(nx0+nx1)/2,(ny0+ny1)/2
  for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
   p=[[x0+nx0*r0,y0+ny0*r0,z0],[x1+nx1*r0,y1+ny1*r0,z0],[x1+nx1*r1,y1+ny1*r1,z1],[x0+nx0*r1,y0+ny0*r1,z1]]
   oriented(out,p,color,[-(z1-z0)*nx,-(z1-z0)*ny,r1-r0])
# Rail cross-section (radial offset from the top's edge, z), by material, one
# continuous profile from below the top's edge to the belly.
RAIL=[('chrome',[(0,FZ-.004),(0,FZ+.010),(.006,FZ+.016),(.016,FZ+.018)]),
      ('leather',[(.016,FZ+.018),(.026,FZ+.036),(.045,FZ+.050),(.07,FZ+.056),(.095,FZ+.049),(.112,FZ+.032),(.12,FZ+.010),(.12,FZ-.012)]),
      ('neon_magenta',[(.12,FZ-.012),(.12,FZ-.024)]),
      ('black_chrome',[(.12,FZ-.024),(.12,FZ-.07),(.11,FZ-.09),(.10,FZ-.20)])]
BELLY_Z=FZ-.20
def table():
 out=[]
 outline=arc(FELT_R)+[(FELT_R,DEALER_EDGE),(-FELT_R,DEALER_EDGE)]
 fan(out,outline,FZ,'TEX:felt',(0,-.35),uvf=felt_uv)
 # Rail: chrome lip, padded leather armrest, neon line, black chrome skirt; up the straight sides too.
 path=[(x,y,x/FELT_R,y/FELT_R) for x,y in arc(FELT_R)]
 for color,profile in RAIL:
  sweep(out,path,profile,color)
  for side in (-1,1):sweep(out,[(side*FELT_R,0,side,0),(side*FELT_R,APRON,side,0)],profile,color)
 # Rail ends at the apron: closing caps.
 for side in (-1,1):
  for color,profile in RAIL:
   for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
    x0,x1=side*(FELT_R+r0),side*(FELT_R+r1)
    if abs((x0-side*FELT_R)*(z1-FZ+.12)-(x1-side*FELT_R)*(z0-FZ+.12))<1e-9:continue   # collinear with the apex
    tri(out,[x0,APRON,z0],[x1,APRON,z1],[side*FELT_R,APRON,FZ-.12],color)
    f=out[-1];n=cross([f['b'][i]-f['a'][i] for i in range(3)],[f['c'][i]-f['a'][i] for i in range(3)])
    if n[1]<0:f['b'],f['c']=f['c'],f['b']
 # Dealer apron: black chrome block under a chrome top, a chrome edge band
 # standing proud of its face towards the players and a cyan line facing the
 # croupier, set 4 mm proud of the block's back. Faces that touch another part
 # are left out (each touching pair would z-fight); the block's ends sit
 # inside the side rails.
 box(out,-FELT_R,FELT_R,DEALER_EDGE,APRON-.004,FZ-.12,FZ+.012,'black_chrome',skip=('-x','+x','+z'))
 box(out,-FELT_R,FELT_R,DEALER_EDGE,APRON-.004,FZ+.012,FZ+.018,'chrome',skip=('-z',))
 box(out,-FELT_R,FELT_R,APRON-.004,APRON,FZ-.05,FZ-.038,'neon_cyan',skip=('-y',))
 box(out,-FELT_R,FELT_R,DEALER_EDGE-.003,DEALER_EDGE,FZ,FZ+.012,'chrome',skip=('-x','+x','+y','-z'))
 # Underside closures (flush with the apron's back, its top and bottom touching the apron and the belly).
 bottom=arc(FELT_R+.10)+[(FELT_R+.10,APRON-.004),(-FELT_R-.10,APRON-.004)]
 fan(out,bottom,BELLY_Z,'graphite',(0,-.35),down=True)
 box(out,-FELT_R-.09,FELT_R+.09,APRON-.014,APRON-.004,BELLY_Z,FZ-.12,'black_chrome',skip=('-z','+z'))
 # Pedestal: a faceted black chrome column on a plinth with a lit floor ring.
 # The column's end caps (on the plinth, under the belly) and each plinth
 # layer's base (on the layer below) are hidden contact faces: left out.
 col_=[];g.lathe(col_,[(0,.16),(.16,.16),(.12,.20),(.09,.26),(.11,BELLY_Z-.06),(.15,BELLY_Z-.03),(.15,BELLY_Z),(0,BELLY_Z)],'black_chrome',8)
 out.extend(transform(drop_plane(drop_plane(col_,.16),BELLY_Z),lambda x,y,z:(x*1.9,y-.33,z)))
 for r,z0,z1,c in ((.50,0,.05,'black_chrome'),(.512,.012,.022,'neon_cyan'),(.46,.05,.14,'graphite'),(.30,.14,.16,'chrome')):
  plinth=[];g.lathe(plinth,[(0,z0),(r,z0),(r,z1),(0,z1)],c,48)
  if z0 in (.05,.14):plinth=drop_plane(plinth,z0)
  out.extend(transform(plinth,lambda x,y,z:(x*1.25,y*.62-.33,z)))
 # Card shoe on the dealer's left (+X): smoked wedge, chrome rails, cyan light, top card at the mouth.
 shoe=[(.16,FZ),(-.10,FZ),(-.145,FZ+.004),(-.10,FZ+.03),(-.10,FZ+.055),(.16,FZ+.092)]
 extrude_yz(out,shoe,.60,.80,'smoke',lambda n:'smoke',floor=FZ)
 for x0,x1 in ((.596,.604),(.796,.804)):
  extrude_yz(out,[(.165,FZ+.002),(-.105,FZ+.002),(-.105,FZ+.06),(.165,FZ+.098)],x0,x1,'chrome',lambda n:'chrome')
 box(out,.61,.79,.155,.163,FZ+.05,FZ+.085,'neon_cyan')
 box(out,.648,.752,-.104,-.06,FZ+.03,FZ+.055,'card_edge')
 u0,v0,u1,v1=cell_uv(*BACK_CELL)
 # The top card at the mouth: parallel to the shoe's lower front slope, 1.5 mm off it.
 (ya,za),(yb,zb)=shoe[2],shoe[3];L=math.hypot(yb-ya,zb-za);dy,dz=(yb-ya)/L,(zb-za)/L;ny,nz=dz,-dy
 if nz<0:ny,nz=-ny,-nz
 lo,hi=[(ya+dy*t+ny*.0015,za+dz*t+nz*.0015) for t in (.004,L-.004)]
 oriented(out,[[.65,*lo],[.75,*lo],[.75,*hi],[.65,*hi]],'TEX:cards',[0,ny,nz],[[u0,v1],[u1,v1],[u1,v1-(v1-v0)*.35],[u0,v1-(v1-v0)*.35]])
 # Discard tray on the dealer's right (-X): smoked well, chrome rim, magenta inner line, spent cards.
 # Walls stand on the base and butt against each other (no overlapping volumes);
 # the faces they touch with are left out.
 # The tray's back touches the apron's face at y=DEALER_EDGE: those faces are left out too.
 box(out,-.79,-.61,-.08,DEALER_EDGE,FZ,FZ+.006,'smoke',skip=('-z','+y'))
 for x0,x1,y0,y1 in ((-.79,-.78,-.08,DEALER_EDGE),(-.62,-.61,-.08,DEALER_EDGE),(-.78,-.62,DEALER_EDGE-.01,DEALER_EDGE),(-.78,-.62,-.08,-.07)):
  ends=('-x','+x') if x1-x0>.05 else ()
  if abs(y1-DEALER_EDGE)<1e-12:   # below the apron's chrome top (FZ+.018) the back face is against the apron
   box(out,x0,x1,y0,y1,FZ+.006,FZ+.018,'smoke',skip=('-z','+z','+y')+ends);box(out,x0,x1,y0,y1,FZ+.018,FZ+.045,'smoke',skip=('-z','+z')+ends)
  else:box(out,x0,x1,y0,y1,FZ+.006,FZ+.045,'smoke',skip=('-z','+z')+ends)
  box(out,x0,x1,y0,y1,FZ+.045,FZ+.05,'chrome',skip=('-z',)+ends)
 box(out,-.78,-.62,-.07,-.067,FZ+.035,FZ+.04,'neon_magenta',skip=('-y','-x','+x'))
 # The spent pile: card-edge sides, its top is the printed back itself.
 box(out,-.75,-.65,-.035,.095,FZ+.006,FZ+.022,'card_edge',skip=('-z','+z'))
 oriented(out,[[-.75,-.035,FZ+.022],[-.65,-.035,FZ+.022],[-.65,.095,FZ+.022],[-.75,.095,FZ+.022]],'TEX:cards',[0,0,1],[[u0,v1],[u1,v1],[u1,v0],[u0,v0]])
 # Chip rack in front of the dealer: black chrome tray, chrome dividers, layered chip rolls.
 box(out,-.34,.34,-.005,.135,FZ,FZ+.014,'black_chrome',skip=('-z',))
 box(out,-.34,.34,-.008,-.005,FZ+.004,FZ+.01,'neon_cyan',skip=('+y',))
 for k in range(7):
  x=-.33+k*.11;box(out,x-.005,x+.005,-.005,.135,FZ+.014,FZ+.04,'chrome',skip=('-z',))
 for k in range(6):
  index=len(DENOMS)-1-k;roll=chips(index,22,16,False,.026,.0052)
  x=-.275+k*.11
  # Lying on its edge along Y, centred in its channel.
  out.extend(transform(roll,lambda a,b,c,x=x:(a+x,-c+.065+11*.0052,b+FZ+.014+.026)))
 return out

def models():
 result={'blackjack_table':table()}
 for s in SUITS:
  for r in RANKS:result['bj_card_'+(r+s).lower()]=card_faces(card_cell(r+s),BACK_CELL)
 result['bj_card_back']=card_faces(BACK_CELL,BACK_CELL)
 result['bj_card_turn']=turned_card()
 for i,(denom,most,_,_,_) in enumerate(DENOMS):
  for n in range(1,most+1):result[f'bj_chips_{denom}_{n}']=chips(i,n)
 return result

# --- Original artwork -----------------------------------------------------------
def rgb(c):return tuple(int(c[i:i+2],16) for i in (1,3,5))+(255,)
RED,INK,IVORY=(178,18,44,255),(20,22,28,255),(246,243,236,255)
GOLD,CYAN,MAGENTA=(226,186,104,255),(34,230,255,255),(255,46,158,255)
def paste_center(im,piece,x,y,rotate=0):
 if rotate:piece=piece.rotate(rotate,resample=Image.Resampling.BICUBIC,expand=True)
 im.alpha_composite(piece,(round(x-piece.width/2),round(y-piece.height/2)))
def suit(im,s,size,x,y,color,rotate=0):art.paste_mask(im,art.suit_mask(s,int(size)),color,x,y,'mm',rotate)
PIPS={2:[(.5,0),(.5,1)],3:[(.5,0),(.5,.5),(.5,1)],4:[(0,0),(1,0),(0,1),(1,1)],
 5:[(0,0),(1,0),(.5,.5),(0,1),(1,1)],6:[(0,0),(1,0),(0,.5),(1,.5),(0,1),(1,1)],
 7:[(0,0),(1,0),(.5,.25),(0,.5),(1,.5),(0,1),(1,1)],8:[(0,0),(1,0),(.5,.25),(0,.5),(1,.5),(.5,.75),(0,1),(1,1)],
 9:[(0,0),(1,0),(0,1/3),(1,1/3),(.5,.5),(0,2/3),(1,2/3),(0,1),(1,1)],
 10:[(0,0),(1,0),(.5,1/6),(0,1/3),(1,1/3),(0,2/3),(1,2/3),(.5,5/6),(0,1),(1,1)]}
def court_figure(im,rank,box,ink,accent):
 """Original geometric court figure, double-ended (top half drawn, then mirrored)."""
 x0,y0,x1,y1=box;w,h=x1-x0,(y1-y0)/2;half=Image.new('RGBA',(int(w),int(h)),(0,0,0,0));d=ImageDraw.Draw(half,'RGBA')
 cx=w/2;ink=ink[:3]+(255,);acc=accent[:3]+(255,);gold=(200,160,72,255)
 # Shoulders / robe.
 d.polygon([(cx-w*.42,h),(cx-w*.30,h*.68),(cx-w*.12,h*.60),(cx+w*.12,h*.60),(cx+w*.30,h*.68),(cx+w*.42,h)],fill=ink)
 d.polygon([(cx-w*.08,h*.62),(cx+w*.08,h*.62),(cx,h)],fill=acc)
 for k in range(3):d.line((cx-w*(.34-.05*k),h*(.80+.06*k),cx+w*(.34-.05*k),h*(.80+.06*k)),fill=gold,width=max(1,int(w*.012)))
 # Head: a chamfered visor-face.
 hw,hy=w*.16,h*.38
 face=[(cx-hw,hy-h*.12),(cx+hw,hy-h*.12),(cx+hw,hy+h*.07),(cx+hw*.5,hy+h*.16),(cx-hw*.5,hy+h*.16),(cx-hw,hy+h*.07)]
 d.polygon(face,fill=(232,214,190,255),outline=ink,width=max(1,int(w*.01)))
 d.line((cx-hw*.85,hy-h*.01,cx+hw*.85,hy-h*.01),fill=acc,width=max(2,int(h*.045)))  # visor light
 if rank=='K':
  d.polygon([(cx-hw*.7,hy+h*.08),(cx+hw*.7,hy+h*.08),(cx+hw*.3,hy+h*.2),(cx-hw*.3,hy+h*.2)],fill=ink)   # beard
  d.polygon([(cx-hw*1.15,hy-h*.12),(cx-hw*1.15,hy-h*.32),(cx-hw*.55,hy-h*.2),(cx,hy-h*.38),(cx+hw*.55,hy-h*.2),(cx+hw*1.15,hy-h*.32),(cx+hw*1.15,hy-h*.12)],fill=gold)
  d.ellipse((cx-w*.025,hy-h*.31,cx+w*.025,hy-h*.25),fill=acc)
 elif rank=='Q':
  d.polygon([(cx-hw*1.5,hy+h*.25),(cx-hw*1.25,hy-h*.14),(cx-hw,hy-h*.14),(cx-hw,hy+h*.1)],fill=ink)   # hair
  d.polygon([(cx+hw*1.5,hy+h*.25),(cx+hw*1.25,hy-h*.14),(cx+hw,hy-h*.14),(cx+hw,hy+h*.1)],fill=ink)
  d.polygon([(cx-hw*1.05,hy-h*.12),(cx-hw*.7,hy-h*.27),(cx,hy-h*.20),(cx+hw*.7,hy-h*.27),(cx+hw*1.05,hy-h*.12)],fill=gold)
  d.ellipse((cx-w*.04,hy-h*.33,cx+w*.04,hy-h*.23),outline=acc,width=max(1,int(w*.012)))
 else:
  d.polygon([(cx-hw*1.1,hy-h*.1),(cx-hw*.9,hy-h*.26),(cx+hw*.9,hy-h*.26),(cx+hw*1.1,hy-h*.1)],fill=ink)   # helmet
  d.polygon([(cx+hw*.9,hy-h*.26),(cx+hw*1.6,hy-h*.34),(cx+hw*1.1,hy-h*.16)],fill=acc)                   # fin
 # Attribute: J a light blade, Q an orb, K a sceptre, across the shoulder.
 lw=max(2,int(w*.02))
 if rank=='J':d.line((cx+w*.30,h*.98,cx+w*.40,h*.34),fill=acc,width=lw);d.line((cx+w*.27,h*.86,cx+w*.42,h*.88),fill=gold,width=lw)
 elif rank=='Q':d.ellipse((cx-w*.40,h*.70,cx-w*.26,h*.84),fill=acc,outline=gold,width=max(1,lw//2))
 else:d.line((cx-w*.34,h*.98,cx-w*.40,h*.30),fill=gold,width=lw);d.ellipse((cx-w*.45,h*.24,cx-w*.35,h*.34),fill=acc)
 im.alpha_composite(half,(int(x0),int(y0)))
 im.alpha_composite(half.rotate(180),(int(x0),int(y0+h)))
def card_face(code,S=4):
 w,h=CELL_W*S,CELL_H*S;im=Image.new('RGBA',(w,h),IVORY);d=ImageDraw.Draw(im,'RGBA')
 rank,s=code[0],code[1];color=RED if s in 'HD' else INK;label='10' if rank=='T' else rank
 accent=(214,30,110,255) if s in 'HD' else (16,150,190,255)
 d.rectangle((4*S,4*S,w-4*S-1,h-4*S-1),outline=(205,198,184,255),width=S)
 # Jumbo corner index: rank and suit, upright at top-left, turned at bottom-right.
 corner=Image.new('RGBA',(w,h),(0,0,0,0))
 size=(34 if label!='10' else 28)*S
 art.hud_text(corner,label,24*S,27*S,size,color,anchor='mm',tracking=.6 if label=='10' else 1.2,weight=.21)
 suit(corner,s,22*S,24*S,60*S,color)
 im.alpha_composite(corner);im.alpha_composite(corner.rotate(180))
 if rank in '23456789T':
  n=10 if rank=='T' else int(rank);size=(32 if n<7 else 27)*S
  for px,py in PIPS[n]:
   cx,cy=w*(.36+.28*px),h*(.2+.6*py);suit(im,s,size,cx,cy,color,180 if py>.5 else 0)
 elif rank=='A':
  ring=art.shape_mask((w,h),lambda dd,k:dd.ellipse((k*(w/2-54*S),k*(h/2-54*S),k*(w/2+54*S),k*(h/2+54*S)),outline=255,width=int(2*S*k)))
  art.paste_mask(im,ring,accent,w/2,h/2)
  for a in range(0,360,30):
   r0,r1=48*S,54*S;ca,sa=math.cos(math.radians(a)),math.sin(math.radians(a))
   d.line((w/2+r0*ca,h/2+r0*sa,w/2+r1*ca,h/2+r1*sa),fill=accent,width=S)
  suit(im,s,(80 if s=='S' else 66)*S,w/2,h/2,color)
 else:
  x0,y0,x1,y1=46*S,30*S,w-46*S,h-30*S
  d.rectangle((x0,y0,x1,y1),fill=(236,231,220,255),outline=(200,160,72,255),width=2*S)
  court_figure(im,rank,(x0+2*S,y0+2*S,x1-2*S,y1-2*S),INK if s in 'SC' else (120,14,34,255),accent)
  d.line((x0,(y0+y1)/2,x1,(y0+y1)/2),fill=(200,160,72,255),width=S)
  suit(im,s,15*S,x0+11*S,y0+13*S,color);suit(im,s,15*S,x1-11*S,y1-13*S,color,180)
 return im.resize((CELL_W,CELL_H),Image.Resampling.LANCZOS)
def card_back(S=4):
 w,h=CELL_W*S,CELL_H*S;im=Image.new('RGBA',(w,h),IVORY);d=ImageDraw.Draw(im,'RGBA')
 m=7*S;d.rectangle((m,m,w-m,h-m),fill=(10,10,16,255))
 inner=Image.new('RGBA',(w,h),(0,0,0,0));di=ImageDraw.Draw(inner,'RGBA')
 rng=random.Random(2077)
 # Circuit traces: orthogonal runs with 45-degree jogs and pads, magenta and cyan.
 for _ in range(70):
  x=rng.randrange(m,w-m);y=rng.randrange(m,h-m);c=MAGENTA if rng.random()<.6 else CYAN;pts=[(x,y)]
  for _ in range(3):
   L=rng.randrange(8,26)*S;dx,dy=rng.choice([(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,1)]);x+=dx*L;y+=dy*L;pts.append((x,y))
  di.line(pts,fill=c[:3]+(150,),width=S);di.ellipse((x-2*S,y-2*S,x+2*S,y+2*S),outline=c[:3]+(200,),width=S)
 inner=inner.crop((m,m,w-m,h-m));im.alpha_composite(inner,(m,m))
 d.rectangle((m,m,w-m,h-m),outline=MAGENTA,width=2*S);d.rectangle((m+5*S,m+5*S,w-m-5*S,h-m-5*S),outline=(255,46,158,110),width=S)
 cx,cy=w/2,h/2
 hexo=[(cx+40*S*math.cos(math.radians(60*i+30)),cy+40*S*math.sin(math.radians(60*i+30))) for i in range(6)]
 d.polygon(hexo,fill=(10,10,16,255),outline=CYAN,width=2*S)
 hexi=[(cx+32*S*math.cos(math.radians(60*i+30)),cy+32*S*math.sin(math.radians(60*i+30))) for i in range(6)]
 d.polygon(hexi,outline=(255,46,158,200),width=S)
 art.hud_text(im,'77',cx,cy,26*S,(240,252,255,255),weight=.2,glow_color=CYAN[:3],glow_radius=4*S)
 return im.resize((CELL_W,CELL_H),Image.Resampling.LANCZOS)
def card_atlas():
 im=Image.new('RGBA',(ATLAS_W,ATLAS_H),(10,10,16,255))
 for code in [r+s for s in SUITS for r in RANKS]:
  col,row=card_cell(code);im.alpha_composite(card_face(code),(col*CELL_W,row*CELL_H))
 im.alpha_composite(card_back(),(BACK_CELL[0]*CELL_W,BACK_CELL[1]*CELL_H))
 return im
def chip_atlas():
 """Chip tops, 160 px across: edge inserts, colour ring, machined centre, value."""
 S=4;im=Image.new('RGBA',(512,512),(20,20,24,255))
 for i,(denom,_,body,insert,ring) in enumerate(DENOMS):
  col,row=i%3,i//3;cx,cy=col*CHIP_CELL+85,row*CHIP_CELL+85
  t=Image.new('RGBA',(170*S,170*S),(0,0,0,0));d=ImageDraw.Draw(t,'RGBA');c=85*S;r=84*S
  d.ellipse((c-r,c-r,c+r,c+r),fill=rgb(body))
  for k in range(8):
   a=math.radians(k*45+22.5);pts=[(c+rr*math.cos(a+da),c+rr*math.sin(a+da)) for da,rr in ((-.13,r+S),(.13,r+S),(.13,r-15*S),(-.13,r-15*S))]
   d.polygon(pts,fill=rgb(insert))
  d.ellipse((c-62*S,c-62*S,c+62*S,c+62*S),outline=rgb(ring),width=4*S)
  face=(24,25,30,255) if denom!=1000 else (30,26,18,255)
  d.ellipse((c-56*S,c-56*S,c+56*S,c+56*S),fill=face)
  for rr in range(50,20,-6):d.ellipse((c-rr*S,c-rr*S,c+rr*S,c+rr*S),outline=(255,255,255,14),width=S)
  label='1K' if denom==1000 else str(denom)
  art.hud_text(t,label,c,c,(40 if len(label)<3 else 34)*S,rgb(ring),weight=.2,tracking=1.0)
  im.alpha_composite(t.resize((170,170),Image.Resampling.LANCZOS),(col*CHIP_CELL,row*CHIP_CELL))
 return im
def felt(limits):
 """Top print at 1 px/mm over x -1.04..1.04, y 0.16..-1.04, then resized."""
 W,H=2080,1200
 base_rgb=np.array([18,20,27],np.float32)
 yy,xx=np.mgrid[0:H,0:W]
 weave=((((xx+yy)//6)%2)^(((xx-yy)//6)%2)).astype(np.float32)   # fine twill
 n=art.noise((W,H),7721,8,1.0)
 cxp,cyp=1040,160;dist=np.hypot(xx-cxp,yy-cyp)/1000
 vign=np.clip(1.08-.25*dist,.75,1.1)
 arr=(base_rgb[None,None,:]*(1+.10*weave[...,None]+.04*n[...,None]))*vign[...,None]
 im=Image.fromarray(np.concatenate([np.clip(arr,0,255).astype(np.uint8),np.full((H,W,1),255,np.uint8)],2),'RGBA')
 def px(x,y):return ((x+1.04)*1000,(.16-y)*1000)
 glowl=Image.new('RGBA',(W,H),(0,0,0,0));gd=ImageDraw.Draw(glowl,'RGBA')
 def ring(dr,x,y,r,color,width):cx,cy=px(x,y);dr.ellipse((cx-r*1000,cy-r*1000,cx+r*1000,cy+r*1000),outline=color,width=width)
 # Pinstripes along the rail: gold, then a magenta light line.
 cx,cy=px(0,0)
 for r,width,c in ((.975,3,GOLD),(.955,4,MAGENTA)):
  gd.arc((cx-r*1000,cy-r*1000,cx+r*1000,cy+r*1000),0,180,fill=c,width=width)
 for seat,angle in enumerate(SEAT_ANGLES):
  a=math.radians(angle);ux,uy=math.sin(a),-math.cos(a)
  ring(gd,SEAT_R*ux,SEAT_R*uy,.075,CYAN,7);ring(gd,SEAT_R*ux,SEAT_R*uy,.062,(34,230,255,140),2)
  for k in range(12):   # tick marks inside the circle
   t=math.radians(k*30);r0,r1=.050,.056;sx,sy=px(SEAT_R*ux+r0*math.cos(t),SEAT_R*uy+r0*math.sin(t));ex,ey=px(SEAT_R*ux+r1*math.cos(t),SEAT_R*uy+r1*math.sin(t))
   gd.line((sx,sy,ex,ey),fill=(34,230,255,160),width=2)
  x,y=px((SEAT_R+.12)*ux,(SEAT_R+.12)*uy);art.hud_text(glowl,str(seat+1),x,y,40,GOLD,rotate=angle,weight=.18)
  corners=[]
  for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1)):
   lx,ly=sx*(CARD_W/2+.012)+.09*(sx>0),sy*(CARD_H/2+.012)
   corners.append(px(CARD_R*ux+lx*math.cos(a)-ly*math.sin(a),CARD_R*uy+lx*math.sin(a)+ly*math.cos(a)))
  for p,q in zip(corners,corners[1:]+corners[:1]):   # card box: corner brackets only
   for t0,t1 in ((0,.18),(.82,1)):gd.line((p[0]+(q[0]-p[0])*t0,p[1]+(q[1]-p[1])*t0,p[0]+(q[0]-p[0])*t1,p[1]+(q[1]-p[1])*t1),fill=(34,230,255,170),width=3)
 def arc_text(text,r,size,color,center=270,glow_color=None):
  pieces=[art.text_mask(ch,size,0,.17) if ch!=' ' else None for ch in text]
  widths=[((p.width-size*.17)*1.0+size*.2)/1000 if p else size*.5/1000 for p in pieces];total=sum(widths);pos=-total/2
  for p,wd in zip(pieces,widths):
   a=math.radians(center)+(pos+wd/2)/r;pos+=wd
   if p:
    x,y=px(r*math.cos(a),r*math.sin(a));art.paste_mask(glowl,p,color,x,y,'mm',math.degrees(a)-270)
 arc_text('BLACKJACK PAYS 3 TO 2',.41,46,GOLD)
 arc_text('DEALER STANDS ON ALL 17S',.665,30,CYAN)
 arc_text('DOUBLE ON ANY FIRST TWO CARDS',.705,22,(200,214,230,255))
 x,y=px(0,-.10);art.hud_text(glowl,'TABLE LIMITS  %d – %s'%(limits['min'],format(limits['max'],',')),x,y,26,(230,236,245,255),tracking=1.6,weight=.16)
 gd.line((x-330,y-34,x+330,y-34),fill=MAGENTA,width=3)
 for xx_ in (x-330,x+330):gd.polygon([(xx_-9,y-34),(xx_,y-43),(xx_+9,y-34),(xx_,y-25)],fill=MAGENTA)
 # Dealer's hand: a faint bracket where the dealer's cards land.
 for k in range(7):
  sx,sy=px(-.07+k*.075,-.24)
  gd.rectangle((sx-50,sy-65,sx+50,sy+65),outline=(255,255,255,18),width=2)
 art.glow(im,glowl,6,1.0)
 return im.resize((2048,1024),Image.Resampling.LANCZOS)
def artwork():return {'bj_felt':felt(rules()),'bj_cards':card_atlas(),'bj_chips':chip_atlas()}

# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so the cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V=True
def cooked(image):return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image

def encode_texture(directory,name,image,template):
 image=Image.alpha_composite(Image.new('RGBA',image.size,(0,0,0,255)),image.convert('RGBA'));source=RESOURCE/'sources'/(name+'.png');image.save(source,optimize=True)
 width,height=image.size;data=bytearray();mips=[];level=cooked(image)
 while True:
  block=level.tobytes();w,h=level.size;mips.append({'$type':'rendRenderTextureBlobMipMapInfo','layout':{'$type':'rendRenderTextureBlobMemoryLayout','rowPitch':w*4,'slicePitch':len(block)},'placement':{'$type':'rendRenderTextureBlobPlacement','offset':len(data),'size':len(block)}});data.extend(block)
  if (w,h)==(1,1):break
  level=level.resize((max(1,w//2),max(1,h//2)),Image.Resampling.BOX)
 obj=copy.deepcopy(template);r=obj['Data']['RootChunk'];r['width']=width;r['height']=height
 blob=r['renderTextureResource']['renderResourceBlobPC']['Data'];header=blob['header'];header['mipMapInfo']=mips;header['sizeInfo']['width']=width;header['sizeInfo']['height']=height
 header['textureInfo'].update(mipCount=len(mips),sliceSize=len(data),textureDataSize=len(data));blob['textureData']['Bytes']=base64.b64encode(data).decode()
 (directory/(name+'.xbm.json')).write_text(json.dumps(obj,separators=(',',':')))
 return {'name':name,'flipV':FLIP_V,'depot':DEPOT+'\\textures\\'+name+'.xbm','width':width,'height':height,'mips':len(mips),'bytes':len(data),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest()}

ORIGINAL_MATERIAL=base.material
def linear(v):
 v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def material(key):
 """metal_base instance: BaseColor (atlas or white x colour), roughness, metalness
 and, for emissive keys, Emissive/EmissiveEV/EmissiveColor (as the slot pack)."""
 value,rough,metal,ev=MATERIALS[key];result=ORIGINAL_MATERIAL(base.WHITE)
 if key in TEX:
  texture=base.ref(DEPOT+'\\textures\\'+value+'.xbm');rgb3=[1,1,1];tint=(255,255,255)
 else:
  texture=base.ref('engine\\textures\\editor\\white.xbm');tint=tuple(int(value[i:i+2],16) for i in (1,3,5));rgb3=[linear(v) for v in tint]
 result['values'][0]['BaseColor']=texture;result['values'][1]['BaseColorScale'].update(X=rgb3[0],Y=rgb3[1],Z=rgb3[2])
 result['values'][2]['RoughnessScale']=rough;result['values'][3]['MetalnessScale']=metal
 if EMISSIVE and ev is not None:
  result['values']+=[{'$type':'rRef:ITexture','Emissive':copy.deepcopy(texture)},{'$type':'Float','EmissiveEV':ev},
   {'$type':'Color','EmissiveColor':{'$type':'Color','Red':tint[0],'Green':tint[1],'Blue':tint[2],'Alpha':255}}]
 return result
base.material=material

def glb(path,faces):
 colors=base.glb(path,faces)
 # Explicit atlas UVs replace the cooker's planar projection where given.
 raw=bytearray(path.read_bytes());json_length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+json_length]);binary=28+json_length;groups={}
 for face in faces:groups.setdefault(face['color'],[]).append(face)
 for mi,group in enumerate(groups.values()):
  accessor=doc['accessors'][doc['meshes'][mi]['primitives'][0]['attributes']['TEXCOORD_0']];view=doc['bufferViews'][accessor['bufferView']];start=binary+view.get('byteOffset',0)+accessor.get('byteOffset',0)
  for i,face in enumerate(group):
   if 'uv' in face:
    for j,uv in enumerate(face['uv']):struct.pack_into('<ff',raw,start+(i*3+j)*8,*uv)
 path.write_bytes(raw);return colors

def preview_resolver(images):
 def resolve(key):
  value,rough,metal,ev=MATERIALS[key];m={'rough':rough,'metal':metal,'emit':0 if ev is None else .1*2**(ev-1)}
  if key in TEX:m['texture']=images[value]
  else:m['color']=tuple(int(value[i:i+2],16) for i in (1,3,5))
  return m
 return resolve

def previews(geometry,images):
 """Design renders written to sources/preview_*.png (not shipped in the archive).
 Cards and chips are placed with the same formulas as client/core/casino_blackjack.lua."""
 def table_scene():
  v=art.Preview(preview_resolver(images));v.add(geometry['blackjack_table'])
  hands={54:['AS','KD'],18:['9C','7H','5S'],-18:['QH','JC'],-54:['TD','2S','8H','3C']}
  bets={54:[('100',1),('25',1)],18:[('5',3)],-18:['1000',],-54:[('500',1),('100',2)]}
  for angle,cards in hands.items():
   a=math.radians(angle);ux,uy,tx,ty=math.sin(a),-math.cos(a),math.cos(a),math.sin(a)
   for k,code in enumerate(cards):
    r=.55-k*.012;v.add(geometry['bj_card_'+code.lower()],(r*ux+k*.032*tx,r*uy+k*.032*ty,FZ+.001+k*CARD_STEP),angle)
   stacks={54:[('100',1),('25',1)],18:[('5',3)],-18:[('1000',2)],-54:[('500',1),('100',2)]}[angle]
   offs={1:[(0,0)],2:[(-.033,0),(.033,0)],3:[(-.033,.02),(.033,.02),(0,-.035)]}[len(stacks)]
   for (d,n),(o1,o2) in zip(stacks,offs):v.add(geometry[f'bj_chips_{d}_{n}'],(.80*ux+o1*tx+o2*ux,.80*uy+o1*ty+o2*uy,FZ+.0005),angle)
  v.add(geometry['bj_card_kh'],(-.07,-.24,FZ+.001));v.add(geometry['bj_card_back'],(.005,-.24,FZ+.001+CARD_STEP))
  return v
 out={}
 t=table_scene()
 out['preview_blackjack_hero']=t.render((1.75,-2.1,FZ+1.0),(0,-.3,FZ-.42),fov=46,size=(1400,900))
 a=math.radians(18);out['preview_blackjack_player']=t.render((1.65*math.sin(a),-1.65*math.cos(a),FZ+.85),(0,-.28,FZ),fov=50,size=(1400,900))
 out['preview_blackjack_dealer']=t.render((0,.95,FZ+.8),(0,-.55,FZ),fov=55,size=(1400,900))
 out['preview_blackjack_side']=t.render((-2.4,-2.2,FZ+.2),(0,-.2,.8),fov=42,size=(1400,900))
 # Close-up of the rail's chrome lip and the dealer's edge band, from a seated eye.
 out['preview_blackjack_rail']=t.render((.75,-1.25,FZ+.32),(-.85,-.15,FZ),fov=34,size=(1400,900))
 cards=art.Preview(preview_resolver(images))
 codes=['AS','2H','3C','4D','5S','6H','7C','8D','9S','TH','JC','QD','KS','JH','QS','KD','AH','AD','AC','TC','7S','9H','8C','5D']
 for i,code in enumerate(codes):cards.add(geometry['bj_card_'+code.lower()],((i%8-3.5)*.115,(1.5-i//8)*.145,0))
 for i in range(4):cards.add(geometry['bj_card_back'],((i-1.5)*.115,-2.6*.145+.0,0))
 out['preview_blackjack_cards']=cards.render((0,-.42,.95),(0,-.04,0),fov=50,size=(1400,1000),bloom=False)
 ch=art.Preview(preview_resolver(images))
 for i,(denom,most,*_) in enumerate(DENOMS):
  for n in range(1,most+1):ch.add(geometry[f'bj_chips_{denom}_{n}'],((n-5)*.07,(i-2.5)*.075,0))
 out['preview_blackjack_chips']=ch.render((.05,-.55,.42),(0,-.02,0),fov=46,size=(1400,1000))
 for name,im in out.items():im.save(RESOURCE/'sources'/(name+'.png'),optimize=True)
 return out

# Where the table is seen from (unscaled table-local metres): seated eyes at each
# base, the client's seat / dealer / overview / top cameras.
VIEWPOINTS=[p for a in SEAT_ANGLES for p in ((1.3*math.sin(math.radians(a)),-1.3*math.cos(math.radians(a)),FZ+.45),
            (1.65*math.sin(math.radians(a)),-1.65*math.cos(math.radians(a)),FZ+.85))]+[(0,.95,FZ+.8),(1.55,-1.35,FZ+1.15),(0,-.42,FZ+2.4),(-2.4,-2.2,FZ+.2)]
def check_geometry(geometry):
 """No z-fighting and no holes, on the authored faces: no two material groups
 overlap in one plane (within 1 mm, either facing: touching faces are left
 out), and from every viewpoint the first surface on each ray faces the viewer."""
 for name,faces in geometry.items():
  pairs=mesh_checks.coplanar_overlaps(faces,tol=.001,same_material=lambda key:key.startswith('TEX:'))
  assert not pairs,(name,len(pairs),mesh_checks.describe(faces,pairs))
 # The chip rolls are closed lathes: aimed at and occluding through the rest only (keeps the check fast).
 table=[f for f in geometry['blackjack_table'] if not f['color'].startswith('chip:')]
 bad=mesh_checks.see_through(table,VIEWPOINTS)
 assert not bad,('back faces seen from the viewpoints',sorted({c for _,_,c in bad}),len(bad))
 print(f'GEOMETRY: {len(geometry)} models without coplanar overlaps between materials; table closed from {len(VIEWPOINTS)} viewpoints',flush=True)

EXPECTED_MODELS=1+52+2+sum(d[1] for d in DENOMS)
EXPECTED_TEXTURES=len(TEX)
def verify(work,manifest):
 """Independent cooked-file, namespace, package-index, atlas and authored-pose checks."""
 spec=importlib.util.spec_from_file_location('archive_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
 archive=work/'archive';verified=work/'verified';packed=(work/'packed/archive.archive').read_bytes()
 entries=checks.archive_entries(packed);files=manifest['files']
 assert len(manifest['models'])==EXPECTED_MODELS and len(manifest['textures'])==EXPECTED_TEXTURES
 assert len(entries)==len(files)==EXPECTED_MODELS*2+EXPECTED_TEXTURES+len(COLLIDERS)
 assert [row['for'] for row in manifest['colliders']]==list(COLLIDERS)
 for row in manifest['colliders']:
  assert row['name']==col.collider_name(row['for']) and row['scaleBaked']==col.SCALE
  col.check_collider_entity(next(verified.rglob(row['name']+'.ent.json')),COLLIDERS[row['for']])
 # The croupier's side stays clear: nothing of the table or its collider reaches past the apron.
 assert all(b.center[1]+b.size[1]/2<=APRON+1e-9 for boxes in COLLIDERS.values() for b in boxes)
 assert set(entries)=={checks.fnv(row['depot']) for row in files}
 assert all(row['depot'].startswith(DEPOT+'\\') for row in files)
 allowed={row['depot'] for row in files}|set(manifest['materialDependencies'])
 for row in files:
  data=(archive/row['depot'].replace('\\','/')).read_bytes()
  assert data[:4]==b'CR2W' and len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
 for model in manifest['models']:
  name=model['name']
  for ext,kind in (('mesh','CMesh'),('ent','entEntityTemplate')):
   candidates=list(verified.rglob(f'{name}.{ext}.json'));assert len(candidates)==1,(name,ext)
   r=json.loads(candidates[0].read_text())['Data']['RootChunk'];assert r['$type']==kind
   for path in checks.depot_paths(r):assert not path or path in allowed,(name,path)
   if ext=='ent':
    assert r['entity']['Data']['$type']=='entEntity' and len(r['components'])==1
    assert r['components'][0]['mesh']['DepotPath']['$value']==model['mesh']
   else:
    assert r['objectType']=='ROT_Static' and not r['boneNames'] and not r['parameters']
    blob=r['renderResourceBlob']['Data'];chunks=blob['header']['renderChunkInfos'];assert sum(c['numIndices'] for c in chunks)//3==model['triangles']
    pixels=base64.b64decode(blob['renderBuffer']['Bytes'])
    for chunk_index,chunk in enumerate(chunks):
     vertices=chunk['chunkVertices'];layout=vertices['vertexLayout'];elements=layout['elements']['Elements']
     for color in (e for e in elements if e['usage']=='PS_Color'):
      stream=color['streamIndex'];offset=vertices['byteOffsets']['Elements'][stream];stride=layout['slotStrides']['Elements'][stream]
      assert all(pixels[offset+j*stride:offset+j*stride+4]==b'\xff'*4 for j in range(chunk['numVertices']))
     uv=next(e for e in elements if e['usage']=='PS_TexCoord' and e['usageIndex']==0);stream=uv['streamIndex'];offset=vertices['byteOffsets']['Elements'][stream];stride=layout['slotStrides']['Elements'][stream]
     values=[struct.unpack_from('<ee',pixels,offset+j*stride) for j in range(chunk['numVertices'])]
     assert all(math.isfinite(v) for pair in values for v in pair)
     if model['materials'][chunk_index] in TEX:
      assert len(set(values))>1 and all(-.001<=v<=1.001 for pair in values for v in pair),(name,'atlas UV out of bounds')
    mats=r['localMaterialBuffer']['materials'];names={e['name']['$value'] for e in r['materialEntries']}
    for key,mat in zip(model['materials'],mats):   # emissive keys keep their Emissive channel through the round trip
     values={k:v for e in mat['values'] for k,v in e.items() if k!='$type'}
     if EMISSIVE and MATERIALS[key][3] is not None:
      assert abs(values['EmissiveEV']-MATERIALS[key][3])<1e-5 and values['Emissive']['DepotPath']['$value']==values['BaseColor']['DepotPath']['$value'],(name,key)
      assert max(values['EmissiveColor'][c] for c in ('Red','Green','Blue'))>0,(name,key)
     else:assert 'Emissive' not in values,(name,key)
    assert all(0<=e['index']<len(mats) for e in r['materialEntries'])
    assert all(c['$value'] in names for a in r['appearances'] for c in a['Data']['chunkMaterials'])
    lo,hi=r['boundingBox']['Min'],r['boundingBox']['Max']
    for i,axis in enumerate(('X','Y','Z')):
     assert math.isfinite(lo[axis]) and math.isfinite(hi[axis]) and lo[axis]<hi[axis]
     assert abs(lo[axis]-model['bounds']['min'][i])<1e-5 and abs(hi[axis]-model['bounds']['max'][i])<1e-5
 for texture in manifest['textures']:
  r=json.loads(next(verified.rglob(texture['name']+'.xbm.json')).read_text())['Data']['RootChunk']
  assert r['$type']=='CBitmapTexture' and r['width']==texture['width'] and r['height']==texture['height']
  blob=r['renderTextureResource']['renderResourceBlobPC']['Data'];data=base64.b64decode(blob['textureData']['Bytes'])
  assert len(blob['header']['mipMapInfo'])==texture['mips']
  source=RESOURCE/'sources'/(texture['name']+'.png');image=Image.open(source).convert('RGBA')
  assert hashlib.sha256(source.read_bytes()).hexdigest()==texture['sourceSha256']
  assert data[:image.width*image.height*4]==(cooked(image) if texture.get('flipV') else image).tobytes() and all(v==255 for v in data[3::4])
 by_name={m['name']:m for m in manifest['models']}
 # Authored poses: flat cards are one card thick; the turned pose stands on its edge.
 for code in [r+s for s in SUITS for r in RANKS]:
  b=by_name['bj_card_'+code.lower()]['bounds'];assert abs(b['max'][2]-CARD_T)<1e-6 and abs(b['max'][0]-CARD_W/2)<1e-6 and abs(b['min'][2])<1e-9
 turn=by_name['bj_card_turn']['bounds'];assert abs(turn['min'][2])<1e-6 and turn['max'][2]>.04
 assert 'TEX:cards' in by_name['bj_card_back']['materials'] and 'TEX:cards' in by_name['bj_card_turn']['materials']
 for denom,most,*_ in DENOMS:
  for n in range(1,most+1):assert abs(by_name[f'bj_chips_{denom}_{n}']['bounds']['max'][2]-n*CHIP_T)<1e-6
 t=by_name['blackjack_table']['bounds'];assert abs(t['min'][2])<1e-9 and FZ<t['max'][2]<FZ+.1 and abs(t['max'][0]-RAIL_R)<1e-6 and t['max'][1]<=APRON+1e-9
 check_geometry(models())
 with zipfile.ZipFile(RESOURCE/'dist/open77_casino_blackjack.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_casino_blackjack.archive']
  assert z.read(z.namelist()[0])==packed
 print(f'VERIFIED: {EXPECTED_MODELS} native props + {len(COLLIDERS)} collider entity, {EXPECTED_TEXTURES} opaque mipmapped textures, {len(files)} exact RDAR entries, emissive top print/neon, geometry/atlas UVs/poses/package hashes',flush=True)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path('/tmp/casino-blackjack-props/build'));p.add_argument('--verify-only',action='store_true');p.add_argument('--art-only',action='store_true',help='write sources/*.png and stop');p.add_argument('--preview',action='store_true',help='write sources/*.png and the preview renders, then stop');p.add_argument('--check-geometry',action='store_true',help='only run the z-fighting / hole checks on the authored geometry');a=p.parse_args();work=a.work
 if a.check_geometry:
  check_geometry(models());return
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 if a.art_only or a.preview:
  (RESOURCE/'sources').mkdir(parents=True,exist_ok=True);images=artwork()
  for name,image in images.items():Image.alpha_composite(Image.new('RGBA',image.size,(0,0,0,255)),image.convert('RGBA')).save(RESOURCE/'sources'/(name+'.png'),optimize=True)
  if a.preview:previews(models(),images);print('PREVIEWS written to',RESOURCE/'sources',flush=True)
  return
 tools=a.lab/'tools';env=os.environ.copy();env['DOTNET_ROOT']=str(tools/'dotnet');env['DOTNET_CLI_HOME']=str(work.parent/'dotnet-home')
 def cli(*args,imports=0):
  result=subprocess.run([str(tools/'dotnet/dotnet'),str(tools/'wolvenkit/WolvenKit.CLI.dll'),*map(str,args)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  if '[ 0: Error' in result.stdout or (result.returncode and not(imports and result.stdout.count('Rebuilt with buffers:')==imports)):print(result.stdout);raise RuntimeError('WolvenKit failed '+str(args[:3]))
  print(f'wolvenkit {args[0]} {args[1] if len(args)>1 else ""}: {sum("Success" in line for line in result.stdout.splitlines())} success lines',flush=True)
 schemas=work/'json';raw=work/'raw';tex=work/'texture-json';host=work/'host-schema'
 for folder in (schemas,raw,tex,host,RESOURCE/'sources'):folder.mkdir(parents=True,exist_ok=True)
 donor=json.loads((a.lab/'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_text())
 cli('convert','serialize','/home/dop42/opx_pool_assets/assets/hosts/open77/assets/opx_infinity/pool/ball_01.ent','-o',host);template=json.loads((host/'ball_01.ent.json').read_text())
 # The shared cooker's wood textures only serve as an XBM schema template here (not shipped).
 template_dir=work/'texture-template';template_dir.mkdir(exist_ok=True)
 base.RESOURCE=work/'texture-template-resource';base.wood_textures(template_dir);base.RESOURCE=RESOURCE
 texture_template=json.loads((template_dir/'wood_ivory.xbm.json').read_text())
 for stale in ('wood_ebony','wood_grain','wood_ivory','wood_natural'):(RESOURCE/'sources'/(stale+'.png')).unlink(missing_ok=True)
 textures=[encode_texture(tex,name,image,texture_template) for name,image in artwork().items()]
 geometry=models();records=[]
 for i,(name,faces) in enumerate(geometry.items()):
  for f in faces:
   p1,p2,p3=(f[k] for k in ('a','b','c'));normal=base.cross([p2[j]-p1[j] for j in range(3)],[p3[j]-p1[j] for j in range(3)])
   assert sum(x*x for x in normal)>1e-22,(name,f)
  colors=glb(raw/(name+'.mesh.glb'),faces)
  (schemas/(name+'.mesh.json')).write_text(json.dumps(base.mesh_json(donor,colors,faces)))
  (schemas/(name+'.ent.json')).write_text(json.dumps(base.entity_json(template,name,i)))
  records.append({'name':name,'mesh':DEPOT+'\\'+name+'.mesh','entity':DEPOT+'\\'+name+'.ent','triangles':len(faces),'materials':colors,'bounds':{'min':[min(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)],'max':[max(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)]}})
 colliders=[]
 for i,(name,boxes) in enumerate(COLLIDERS.items()):
  (schemas/(col.collider_name(name)+'.ent.json')).write_text(json.dumps(col.collider_entity_json(template,boxes,i)))
  colliders.append({'name':col.collider_name(name),'for':name,'entity':DEPOT+'\\'+col.collider_name(name)+'.ent','scaleBaked':col.SCALE,'boxes':[{'size':list(b.size),'center':list(b.center)} for b in boxes]})
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');(target/'textures').mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target);cli('convert','deserialize',tex,'-o',target/'textures');cli('import',*[raw/(name+'.mesh.glb') for name in geometry],'-o',target,'--keep',imports=len(geometry))
 verified=work/'verified';verified.mkdir(exist_ok=True);cli('convert','serialize',archive,'-o',verified);packed=work/'packed';packed.mkdir(exist_ok=True);cli('pack',archive,'-o',packed)
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_casino_blackjack.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_casino_blackjack.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 layout={'feltZ':FZ,'feltRadius':FELT_R,'railRadius':RAIL_R,'seatAngles':dict(zip(['white','black','white2','black2'],SEAT_ANGLES)),'seatRadius':SEAT_R,'cardRadius':CARD_R,
  'card':{'width':CARD_W,'height':CARD_H,'thickness':CARD_T},'chip':{'radius':CHIP_R,'thickness':CHIP_T},'chipStacks':{str(d):most for d,most,*_ in DENOMS}}
 manifest={'version':'2.0.0','style':'Night City table: dark composite top with an emissive print, leather and chrome rail, ivory cards with HUD indices, layered machined chips','namespace':DEPOT,'models':records,'colliders':colliders,'textures':textures,'files':files,'layout':layout,'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=1)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
