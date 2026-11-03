#!/usr/bin/env python3
"""Cook the original slot machine: cabinet, three reel strips, lever poses, lamp, coin.

Uses the existing native board-prop cooker as a read-only schema/tool library
and tools/casino_art.py for the HUD typeface, neon bloom and preview renders.
Only this resource and --work receive outputs. Requires Pillow and numpy
(original symbol, topper, belly and paytable artwork), lupa (reads the reel
strips and pays from the shared rules), .NET and WolvenKit from the lab.

Art direction: a high-end Night City cabinet. Black chrome body between two
sculpted fins whose front edges are cyan neon, a concave curved topper screen
under a hood with a magenta light line, a chrome reel bezel with payline
chevrons, a lit paytable screen, a slanted console with glowing buttons, a
chrome lever with a glowing knob and a lit coin tray. Neon, screens and the
reel strips use metal_base's Emissive channel (EMISSIVE below).

Props turn about Z only, so every moving part is a separate prop: the reels are
flat symbol strips that slide vertically behind the bezel window, the lever is
six authored pose meshes and the lamp a lit/unlit pair. Inactive poses park
inside the closed cabinet, away from the reel bay that the window shows.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,struct,subprocess,sys,zipfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageFilter
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import casino_art as art
RESOURCE=ROOT/'resources/assets/models/open77_casino_slots'
DEPOT='open77\\assets\\op77_lightrp\\casino_slots'
LAB=ROOT.parent/'dop-tests'
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()
# Player collision (tools/COLLISION.md): <base>_collider.ent, boxes in cabinet-local metres before the 0.65 scale.
spec=importlib.util.spec_from_file_location('collision_props',ROOT/'tools/collision_props.py');col=importlib.util.module_from_spec(spec);spec.loader.exec_module(col)
COLLIDERS={'slot_cabinet':[col.Box.between((-.505,-.44,0),(.505,.36,2.56))]}  # plinth+body+fins; lever (+X), deck lip, tray and topper hood stay open

# Materials: key -> (sRGB colour or texture name, roughness, metalness, emissive EV).
# EV None = not emissive. Textured screens emit their own artwork (dark
# backgrounds barely glow, neon ink does). Tune the EVs here after a live look.
EMISSIVE=True
MATERIALS={
 'black_chrome':('#121319',.16,.9,None),   # body shell, hood, fins
 'graphite':('#23262F',.42,.55,None),      # recessed panels, plinth top
 'chrome':('#D9DEE6',.08,1.0,None),        # bezel, lever, rails
 'satin':('#8C929C',.3,1.0,None),          # brushed trims
 'lining':('#060608',.95,0,None),          # reel bay interior
 'void':('#030304',.9,0,None),             # coin chute mouth
 'neon_cyan':('#22E6FF',.3,0,4.0),
 'neon_magenta':('#FF2E9E',.3,0,4.0),
 'payline':('#FF3B5C',.3,0,4.5),
 'button_spin':('#38F0FF',.25,0,3.0),
 'button_bet':('#FFB547',.25,0,2.0),
 'button_max':('#FF2E9E',.25,0,2.5),
 'tray_glow':('#B8862E',.25,.6,.6),       # lit coin tray floor
 'knob':('#FF2E7A',.12,0,3.0),
 'lamp_off':('#2A1420',.12,.2,None),
 'lamp_on':('#FF5FB8',.08,0,6.0),
 'gold':('#F2C14E',.22,1.0,None),
 'TEX:symbols':('slot_symbols',.3,0,1.2),
 'TEX:marquee':('slot_marquee',.12,0,1.6),
 'TEX:belly':('slot_belly',.12,0,1.2),
 'TEX:paytable':('slot_paytable',.12,0,1.4),
}
TEXTURED={k:v[0] for k,v in MATERIALS.items() if k.startswith('TEX:')}

# Layout in unscaled board-local metres (the client renders everything at 0.65).
# The front faces -Y; the lever is on the player's right (+X). Mirrored by
# client/core/casino_slots.lua (L) and checked by tools/test-casino-slots-client.py.
STOPS=12;ENTRIES=STOPS+3
LAYOUT={'paylineZ':1.33,'pitch':.085,'stripY':-.33,'reelX':[-.22,0,.22],'reelWidth':.20,
 'leverAngles':[0,17,34,51,68,85],'leverPivot':[.55,0,1.35],'leverLength':.45,
 'leverPark':[-.14,.16,0],'lampPark':[0,.15,-.32],
 'chuteY':-.37,'chuteZ':.73,'trayY':-.44,'trayZ':.574,'coinPark':[0,.2,.4]}
BODY_BOX=((-.46,.46),(-.36,.36),(.12,2.52))  # closed interior the parked poses hide in
BAY=((-.34,.34),(-.36,-.24),(.15,2.51))     # dark reel bay behind the window
P=LAYOUT['pitch'];PZ=LAYOUT['paylineZ']
WINDOW_X=(-.31,.31);WINDOW_Z=(PZ-1.3*P,PZ+1.3*P) # 2.6 visible rows
HOLE_X=(-.325,.325)
# Curved topper: a concave arc bending towards the player, from the body front
# at TOPPER_Z0 up to TOPPER_Z1 (radius TOPPER_R, centre in front and below).
TOPPER_Z0,TOPPER_Z1,TOPPER_R=1.78,2.48,1.4
TOPPER_A=math.asin((TOPPER_Z1-TOPPER_Z0)/TOPPER_R)
def topper_point(a):return (-.36-TOPPER_R*(1-math.cos(a)),TOPPER_Z0+TOPPER_R*math.sin(a))
TOPPER_FRONT=topper_point(TOPPER_A)[0]
PAYTABLE=(-.42,.42,1.535,1.745)               # screen x0,x1,z0,z1 on the body front
DECK=(1.00,1.10,-.53)                          # console z0, z1 at the body, front y
DECK_SLOPE=math.atan2(DECK[1]-1.035,-.36-DECK[2])


def reels():
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute('LightRpBoardGames={};LightRpItems={}')
 lua.execute((ROOT/'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
 S=lua.globals().LightRpCasinoSlots
 assert S.STOPS==STOPS
 symbols=[S.SYMBOLS[i+1] for i in range(len(S.SYMBOLS))]
 strips=[[S.REELS[r+1][i+1] for i in range(STOPS)] for r in range(3)]
 return symbols,strips

def pays():
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute('LightRpBoardGames={};LightRpItems={}')
 lua.execute((ROOT/'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
 S=lua.globals().LightRpCasinoSlots
 three={k:S.THREE[k] for k in S.THREE.keys()}
 return {'three':three,'twoCherries':S.TWO_CHERRIES,'mixedFruit':S.MIXED_FRUIT,'oneCherry':S.ONE_CHERRY,'min':S.MIN_BET,'max':S.MAX_BET}


# Geometry helpers ------------------------------------------------------------
def tri(out,a,b,c,color,uv=None):
 f={'a':list(a),'b':list(b),'c':list(c),'color':color}
 if uv is not None:f['uv']=[list(x) for x in uv]
 out.append(f)

def quad(out,points,c,uv=None):
 for ids in ((0,1,2),(0,2,3)):
  tri(out,*(points[i] for i in ids),c,None if uv is None else [uv[i] for i in ids])

def vcross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]
def oriented(out,p,c,outward,uv=None):
 """Quad whose winding is flipped if needed so its normal points along `outward`."""
 n=vcross([p[1][i]-p[0][i] for i in range(3)],[p[2][i]-p[0][i] for i in range(3)])
 if sum(n[i]*outward[i] for i in range(3))<0:p=p[::-1];uv=uv[::-1] if uv else None
 quad(out,p,c,uv)

def tri_facing(out,a,b,c,color,outward):
 n=vcross([b[i]-a[i] for i in range(3)],[c[i]-a[i] for i in range(3)])
 if sum(n[i]*outward[i] for i in range(3))<0:b,c=c,b
 tri(out,a,b,c,color)

def front(out,x0,x1,z0,z1,y,c,uv=None):
 """A rectangle in the XZ plane facing -Y (towards the player)."""
 quad(out,[(x0,y,z0),(x1,y,z0),(x1,y,z1),(x0,y,z1)],c,uv)

def box(out,x0,x1,y0,y1,z0,z1,c):g.box(out,(x0+x1)/2,(y0+y1)/2,(z0+z1)/2,x1-x0,y1-y0,z1-z0,c)

def inward_box(out,b,c,skip=()):
 """Inside faces of a box (a cavity seen from within); `skip` drops open sides."""
 (x0,x1),(y0,y1),(z0,z1)=b;tmp=[];g.box(tmp,(x0+x1)/2,(y0+y1)/2,(z0+z1)/2,x1-x0,y1-y0,z1-z0,c)
 for f in tmp:
  pts=[f['a'],f['b'],f['c']];cx=sum(p[0] for p in pts)/3;cy=sum(p[1] for p in pts)/3;cz=sum(p[2] for p in pts)/3
  side=('-y' if abs(cy-y0)<1e-9 else '+y' if abs(cy-y1)<1e-9 else '-x' if abs(cx-x0)<1e-9 else '+x' if abs(cx-x1)<1e-9 else '-z' if abs(cz-z0)<1e-9 else '+z')
  if side in skip:continue
  out.append({'a':f['a'],'b':f['c'],'c':f['b'],'color':c})

def transform(faces,fn):
 for f in faces:
  for k in ('a','b','c'):f[k]=list(fn(*f[k]))
 return faces

def lathe(out,profile,c,sides=32,at=(0,0,0)):
 tmp=[];g.lathe(tmp,profile,c,sides);out.extend(transform(tmp,lambda x,y,z:(x+at[0],y+at[1],z+at[2])));return out

def cylinder_x(out,x0,x1,y,z,r,c,sides=32):
 """A closed cylinder along +X (lathe along Z, then turned)."""
 tmp=[];g.lathe(tmp,[(0,0),(r,0),(r,x1-x0),(0,x1-x0)],c,sides)
 out.extend(transform(tmp,lambda px,py,pz:(x0+pz,y+py,z-px)))

def lathe_x(out,profile,c,x0,y,z,sides=40):
 """A lathe whose axis runs along +X from x0; profile is (radius, distance along X)."""
 tmp=[];g.lathe(tmp,profile,c,sides)
 out.extend(transform(tmp,lambda px,py,pz:(x0+pz,y+py,z-px)))

def rot_x(faces,angle,pivot=(0,0)):
 """Rotate about the X axis through (y,z)=pivot; +angle turns +Z towards -Y."""
 ca,sa=math.cos(angle),math.sin(angle);py,pz=pivot
 return transform(faces,lambda x,y,z:(x,py+(y-py)*ca-(z-pz)*sa,pz+(y-py)*sa+(z-pz)*ca))

def extrude_yz(out,poly,x0,x1,side,edge):
 """Extrude a (y,z) polygon between x0 and x1. `edge(outward,p,q)` picks each rim face's material."""
 area=sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in range(len(poly)))
 if area<0:poly=poly[::-1]
 for a,b,c in base.triangulate(poly):
  for x,n in ((x0,-1),(x1,1)):
   pts=[(x,*poly[a]),(x,*poly[b]),(x,*poly[c])]
   nn=vcross([pts[1][i]-pts[0][i] for i in range(3)],[pts[2][i]-pts[0][i] for i in range(3)])
   if nn[0]*n<0:pts=pts[::-1]
   tri(out,*pts,side)
 for i in range(len(poly)):
  (y0,z0),(y1,z1)=poly[i],poly[(i+1)%len(poly)]
  outward=[0,z1-z0,-(y1-y0)]  # right-hand normal of a CCW polygon
  c=edge(outward,poly[i],poly[(i+1)%len(poly)])
  if c is None:continue
  inlay=None
  if isinstance(c,tuple):c,inlay=c
  oriented(out,[(x0,y0,z0),(x1,y0,z0),(x1,y1,z1),(x0,y1,z1)],c,outward)
  if inlay:  # a light strip down the middle of this rim face, standing just proud of it
   colour,width=inlay;n=math.hypot(outward[1],outward[2]);oy,oz=outward[1]/n*.0015,outward[2]/n*.0015;xm=(x0+x1)/2
   oriented(out,[(xm-width/2,y0+oy,z0+oz),(xm+width/2,y0+oy,z0+oz),(xm+width/2,y1+oy,z1+oz),(xm-width/2,y1+oy,z1+oz)],colour,outward)


# Models ------------------------------------------------------------------------
def topper_arc(n=18):return [topper_point(TOPPER_A*i/n) for i in range(n+1)]

def fin_profile():
 """Side fin outline (y,z): flush plinth, a proud front edge following the topper, hood."""
 arc=[(y-.05,z) for y,z in topper_arc()]
 return [(.34,.10),(-.41,.10),(-.41,TOPPER_Z0)]+arc[1:]+[(TOPPER_FRONT-.07,2.56),(.34,2.56)]

def cabinet():
 out=[];(bx0,bx1),(by0,by1),(bz0,bz1)=BODY_BOX
 # Plinth: black chrome with a floor-glow line around the front and sides.
 box(out,-.50,.50,-.43,.35,0,bz0,'black_chrome')
 box(out,-.505,.505,-.435,.355,.022,.036,'neon_cyan')
 box(out,-.49,.49,-.42,.34,bz0-.012,bz0,'satin')
 # Closed shell: sides follow the topper profile; the front has only the window hole.
 arc=topper_arc()
 shell=[(by1,bz0),(by0,bz0),(by0,TOPPER_Z0)]+arc[1:]+[(arc[-1][0],bz1),(by1,bz1)]
 # The lower front rim is left out: it is rebuilt below around the window hole.
 extrude_yz(out,shell,bx0,bx1,'black_chrome',lambda n,p,q:None if p[0]==q[0]==by0 and max(p[1],q[1])<=TOPPER_Z0 else 'black_chrome')
 hx0,hx1=HOLE_X;wz0,wz1=WINDOW_Z
 y=by0-.0015
 front(out,bx0,bx1,bz0,wz0,y,'black_chrome');front(out,bx0,bx1,wz1,TOPPER_Z0,y,'black_chrome')
 front(out,bx0,hx0,wz0,wz1,y,'black_chrome');front(out,hx1,bx1,wz0,wz1,y,'black_chrome')
 inward_box(out,BAY,'lining',skip=('-y',))
 # Baffles just inside the window keep oblique views off the strip ends.
 box(out,BAY[0][0],BAY[0][1],-.36,-.336,wz1,wz1+.006,'lining');box(out,BAY[0][0],BAY[0][1],-.36,-.336,wz0-.006,wz0,'lining')
 # Topper screen on the arc: black chrome margins, emissive artwork in between.
 for (y0,z0),(y1,z1),i in zip(arc,arc[1:],range(len(arc))):
  n=len(arc)-1;v0,v1=1-i/n,1-(i+1)/n;yy0,yy1=y0-.002,y1-.002
  outward=[0,-(z1-z0),(y1-y0)]
  if outward[1]>0:outward=[-v for v in outward]
  for xa,xb,c in ((bx0,-.41,'black_chrome'),(.41,bx1,'black_chrome')):oriented(out,[(xa,yy0,z0),(xb,yy0,z0),(xb,yy1,z1),(xa,yy1,z1)],c,outward)
  oriented(out,[(-.41,yy0,z0),(.41,yy0,z0),(.41,yy1,z1),(-.41,yy1,z1)],'TEX:marquee',outward,[[0,v0],[1,v0],[1,v1],[0,v1]])
 # Hood over the topper with a magenta light line under its lip.
 hood=[(TOPPER_FRONT-.08,2.50),(by1+.005,2.50),(by1+.005,2.56),(TOPPER_FRONT-.07,2.56)]
 extrude_yz(out,hood,-.505,.505,'black_chrome',lambda n,p,q:'black_chrome')
 box(out,-.50,.50,TOPPER_FRONT-.0815,TOPPER_FRONT-.0795,2.502,2.514,'neon_magenta')
 lathe(out,[(0,0),(.12,0),(.125,.008),(.11,.02),(0,.02)],'chrome',40,(0,0,2.56))
 # Sculpted side fins; their front edges are cyan neon strips.
 fin=fin_profile()
 for x0,x1 in ((-.50,-.46),(.46,.50)):
  extrude_yz(out,fin,x0,x1,'black_chrome',lambda n,p,q:('black_chrome',('neon_cyan',.012)) if n[1]<-.6*math.hypot(n[1],n[2]) else 'black_chrome')
  sx=x0 if x0<0 else x1;s=-1 if x0<0 else 1
  box(out,min(sx,sx+s*.004),max(sx,sx+s*.004),-.30,.28,.44,.452,'neon_magenta')    # side light line
  box(out,min(sx,sx+s*.003),max(sx,sx+s*.003),-.30,.28,.47,.474,'satin')
  for yy in (-.26,.24):box(out,min(sx,sx+s*.004),max(sx,sx+s*.004),yy-.006,yy+.006,.50,2.30,'satin')   # side rails
  box(out,min(sx,sx+s*.004),max(sx,sx+s*.004),-.26,.24,2.30,2.312,'satin')
 # Reel bezel: chrome frame with a black inner bevel, neon outline, payline chevrons.
 wx0,wx1=WINDOW_X;F=.055
 box(out,wx0-F,wx0,-.40,-.355,wz0-F,wz1+F,'chrome');box(out,wx1,wx1+F,-.40,-.355,wz0-F,wz1+F,'chrome')
 box(out,wx0,wx1,-.40,-.355,wz0-F,wz0,'chrome');box(out,wx0,wx1,-.40,-.355,wz1,wz1+F,'chrome')
 e=.014  # inner bevel: from the frame front down to the window edge
 outer=[(wx0-e,wz0-e),(wx1+e,wz0-e),(wx1+e,wz1+e),(wx0-e,wz1+e)];inner=[(wx0,wz0),(wx1,wz0),(wx1,wz1),(wx0,wz1)]
 for i in range(4):
  j=(i+1)%4;mx=(inner[i][0]+inner[j][0])/2;mz=(inner[i][1]+inner[j][1])/2
  n=[-mx if inner[i][0]==inner[j][0] else 0,-.3,PZ-mz if inner[i][1]==inner[j][1] else 0]
  oriented(out,[(outer[i][0],-.4005,outer[i][1]),(outer[j][0],-.4005,outer[j][1]),(inner[j][0],-.38,inner[j][1]),(inner[i][0],-.38,inner[i][1])],'black_chrome',n)
 for x0,x1,z0,z1 in ((wx0-F-.006,wx0-F,wz0-F-.006,wz1+F+.006),(wx1+F,wx1+F+.006,wz0-F-.006,wz1+F+.006),(wx0-F,wx1+F,wz0-F-.006,wz0-F),(wx0-F,wx1+F,wz1+F,wz1+F+.006)):
  box(out,x0,x1,-.398,-.36,z0,z1,'neon_cyan')
 for x in (-.11,.11):box(out,x-.012,x+.012,-.372,-.338,wz0-.01,wz1+.01,'black_chrome')   # reel mullions
 for side in (-1,1):   # payline chevrons pointing at the centre line
  xo=(wx1+F/2)*side;t=.018
  tri_facing(out,(xo+side*t,-.4012,PZ+t),(xo-side*t*.9,-.4012,PZ),(xo+side*t,-.4012,PZ-t),'payline',[0,-1,0])
 # Paytable screen in a chrome frame.
 x0,x1,z0,z1=PAYTABLE
 box(out,x0-.018,x1+.018,-.375,-.36,z0-.018,z1+.012,'chrome')
 front(out,x0,x1,z0,z1,-.3765,'TEX:paytable',[[0,1],[1,1],[1,0],[0,0]])
 # Console: slanted black chrome deck, neon underline, glowing buttons.
 dz0,dz1,dy=DECK
 extrude_yz(out,[(-.36,dz0),(dy,dz0),(dy,1.035),(-.36,dz1)],-.44,.44,'black_chrome',lambda n,p,q:'satin' if n[1]<-.9*math.hypot(n[1],n[2]) else 'black_chrome')
 box(out,-.44,.44,dy-.004,dy,dz0-.008,dz0,'neon_cyan')
 def on_deck(parts,x,t):
  """Place deck-local parts (flat on z=0) at x and fraction t up the slope."""
  y=dy+(-.36-dy)*t;z=1.035+(dz1-1.035)*t
  rot_x(parts,-DECK_SLOPE)
  out.extend(transform(parts,lambda px,py,pz:(px+x,py+y,pz+z)))
 spin=[];lathe(spin,[(0,0),(.05,0),(.05,.006),(0,.006)],'chrome',40);lathe(spin,[(0,.006),(.04,.006),(.04,.016),(.034,.022),(0,.024)],'button_spin',40)
 on_deck(spin,.30,.5)
 for x,c in ((-.32,'button_bet'),(-.22,'button_bet'),(-.12,'button_bet'),(.06,'button_max')):
  b=[];box(b,-.04,.04,-.025,.025,0,.004,'chrome');box(b,-.034,.034,-.02,.02,.004,.013,c);on_deck(b,x,.5)
 # Belly artwork in a chrome frame.
 box(out,-.43,.43,-.375,-.36,.785,.99,'chrome');front(out,-.41,.41,.80,.975,-.3765,'TEX:belly',[[0,1],[1,1],[1,0],[0,0]])
 # Coin chute with a chrome hood, and the lit tray.
 box(out,-.16,.16,-.38,-.36,.665,.785,'chrome');front(out,-.13,.13,.68,.77,-.3805,'void')
 box(out,-.16,.16,-.43,-.36,.772,.785,'chrome')
 box(out,-.31,.31,-.52,-.36,.545,.57,'tray_glow')
 box(out,-.32,.32,-.535,-.515,.54,.64,'chrome');box(out,-.32,.32,-.538,-.535,.55,.556,'neon_cyan')
 for x in (-.315,.315):box(out,x-.007,x+.007,-.535,-.36,.54,.62,'chrome')
 # Lower door: fluted black chrome with a satin frame.
 box(out,-.42,.42,-.372,-.36,.15,.165,'satin');box(out,-.42,.42,-.372,-.36,.50,.515,'satin')
 n=16;w=.8/n
 for i in range(n):
  xa=-.4+i*w;xm=xa+w/2;xb=xa+w
  oriented(out,[(xa,-.366,.165),(xm,-.375,.165),(xm,-.375,.50),(xa,-.366,.50)],'black_chrome',[-.4,-1,0])
  oriented(out,[(xm,-.375,.165),(xb,-.366,.165),(xb,-.366,.50),(xm,-.375,.50)],'black_chrome',[.4,-1,0])
 # Lever hub through the right fin, with a chrome side plate.
 px,py,pz=LAYOUT['leverPivot']
 lathe_x(out,[(0,0),(.115,0),(.115,.012),(.105,.02),(0,.02)],'black_chrome',.50,py,pz)
 lathe_x(out,[(.088,.0195),(.098,.0195),(.098,.0215),(.088,.0215),(.088,.0195)],'neon_magenta',.50,py,pz)
 lathe_x(out,[(0,0),(.05,0),(.05,.06),(.044,.075),(.028,.08),(0,.08)],'chrome',.50,py,pz)
 return out

def symbol_strip(strip,symbols):
 out=[];w=LAYOUT['reelWidth'];entries=[strip[-1]]+strip+strip[:2];assert len(entries)==ENTRIES
 for i,name in enumerate(entries):
  k=symbols.index(name);col,row=k%2,k//2;u0,u1=col*.5+.002,col*.5+.498;v0,v1=row*.25+.002,row*.25+.248
  z=-i*P
  front(out,-w/2,w/2,z-P/2,z+P/2,0,'TEX:symbols',[[u0,v1],[u1,v1],[u1,v0],[u0,v0]])
 return out

def lever(angle):
 arm=[];L=LAYOUT['leverLength']
 g.lathe(arm,[(0,-.01),(.03,-.01),(.03,.04),(.021,.06),(.019,.14),(.026,.15),(.026,.17),(.019,.18),(.016,L-.07),(.024,L-.06),(.031,L-.05),(.031,L-.04),(0,L-.04)],'chrome',32)
 base.sphere(g,arm,(0,0,L),.045,'knob')
 a=math.radians(angle);px,py,pz=LAYOUT['leverPivot']
 # Pull towards the player: the top swings from +Z to -Y about the X axis.
 return transform(arm,lambda x,y,z:(px+x,py+y*math.cos(a)-z*math.sin(a),pz+y*math.sin(a)+z*math.cos(a)))

def lamp(color):
 """Faceted beacon crystal on the hood."""
 out=[];g.lathe(out,[(0,0),(.075,0),(.085,.03),(.07,.075),(.035,.1),(0,.11)],color,8)
 return transform(out,lambda x,y,z:(x,y,z+2.58))

def coin():
 out=[];g.lathe(out,[(0,-.004),(.025,-.004),(.027,-.0025),(.027,.0025),(.025,.004),(.02,.004),(.019,.0028),(0,.0028)],'gold',32);return out

def models(symbols,strips):
 m={'slot_cabinet':cabinet()}
 for r in range(3):m[f'slot_strip_{r+1}']=symbol_strip(strips[r],symbols)
 for i,a in enumerate(LAYOUT['leverAngles']):m[f'slot_lever_{i}']=lever(a)
 m['slot_lamp_off']=lamp('lamp_off');m['slot_lamp_on']=lamp('lamp_on');m['slot_coin']=coin()
 return m


# Artwork --------------------------------------------------------------------
CYAN,MAGENTA,GOLD,RED,VIOLET=(34,230,255),(255,46,158),(255,190,80),(255,52,72),(150,70,255)
INK=(6,8,16)

def radial(size,inner,outer,center=(.38,.32),power=1.0):
 """RGBA radial gradient disc colours (for glossy spheres)."""
 import numpy as np
 w,h=size;yy,xx=np.mgrid[0:h,0:w];cx,cy=center[0]*w,center[1]*h
 t=np.clip(np.hypot(xx-cx,yy-cy)/(max(w,h)*.85),0,1)**power
 a=np.array(inner,float);b=np.array(outer,float)
 arr=(a[None,None,:]*(1-t[...,None])+b[None,None,:]*t[...,None]).astype('uint8')
 return Image.fromarray(np.concatenate([arr,np.full((h,w,1),255,'uint8')],2),'RGBA')

def fill(image,mask,src,at=(0,0)):
 """Paint `src` (RGBA image or colour) through L `mask` at `at`."""
 if not isinstance(src,Image.Image):src=Image.new('RGBA',mask.size,tuple(src)+(255,))
 layer=src.copy();layer.putalpha(mask);image.alpha_composite(layer,at)

def poly_mask(size,points,ss=4):
 return art.shape_mask(size,lambda d,s:d.polygon([(x*s,y*s) for x,y in points],fill=255),ss)

def neon_layer(size,draw,color,width):
 """A transparent layer with `draw(d)` stroked in `color`."""
 im=Image.new('RGBA',size,(0,0,0,0));draw(ImageDraw.Draw(im,'RGBA'),color,width);return im

def draw_symbol(cell,name):
 """Original neon symbols on a dark cell (any size; designed on 600x256)."""
 W,H=cell.size;k=H/256;cx,cy=W/2,H/2
 def P(x,y):return (cx+x*k,cy+y*k)
 def glow_mask(mask,color,radius=10,strength=1.4,at=(0,0)):
  layer=Image.new('RGBA',cell.size,(0,0,0,0));fill(layer,mask,color,at)
  halo=layer.filter(ImageFilter.GaussianBlur(radius*k));a=halo.getchannel('A').point(lambda v:min(255,int(v*strength)));halo.putalpha(a);cell.alpha_composite(halo)
 if name=='seven':
  pts=[P(-62,-86),P(70,-86),P(70,-62),P(-6,92),P(-44,92),P(24,-54),P(-62,-54)]
  m=poly_mask(cell.size,pts);glow_mask(m,RED,14,1.6)
  fill(cell,m,art.gradient(cell.size,(255,96,120),(200,0,70)))
  inner=poly_mask(cell.size,[P(-52,-78),P(60,-78),P(60,-64),P(-2,82),P(-30,82),P(30,-62),P(-52,-62)])
  edge=Image.new('L',cell.size,0);edge.paste(m);edge=Image.fromarray(__import__('numpy').clip(__import__('numpy').asarray(m,int)-__import__('numpy').asarray(inner,int),0,255).astype('uint8'))
  fill(cell,edge,GOLD)
  fill(cell,poly_mask(cell.size,[P(-56,-82),P(64,-82),P(62,-76),P(-54,-76)]),(255,236,200))
 elif name=='diamond':
  top=-70;mid=-30;bot=88;wd=92
  facets=[([P(-wd,mid),P(-52,top),P(-14,mid)],(150,240,255)),([P(-52,top),P(0,top),P(-14,mid)],(210,250,255)),([P(0,top),P(52,top),P(14,mid)],(120,220,250)),
   ([P(52,top),P(wd,mid),P(14,mid)],(70,190,240)),([P(-14,mid),P(0,top),P(14,mid)],(255,255,255)),
   ([P(-wd,mid),P(-14,mid),P(0,bot)],(40,170,230)),([P(-14,mid),P(14,mid),P(0,bot)],(110,215,250)),([P(14,mid),P(wd,mid),P(0,bot)],(20,120,200))]
  whole=poly_mask(cell.size,[P(-wd,mid),P(-52,top),P(52,top),P(wd,mid),P(0,bot)]);glow_mask(whole,CYAN,14,1.5)
  for pts,c in facets:fill(cell,poly_mask(cell.size,pts),c)
  d=ImageDraw.Draw(cell,'RGBA')
  for a,b in ((P(-wd,mid),P(wd,mid)),(P(-52,top),P(-14,mid)),(P(52,top),P(14,mid)),(P(-14,mid),P(0,bot)),(P(14,mid),P(0,bot))):d.line((a,b),fill=(230,252,255,180),width=max(1,int(2*k)))
 elif name=='chip':
  r=84;m=art.shape_mask(cell.size,lambda d,s:d.ellipse((s*(cx-r*k),s*(cy-r*k),s*(cx+r*k),s*(cy+r*k)),fill=255));glow_mask(m,MAGENTA,12,1.3)
  fill(cell,m,(200,20,110))
  for i in range(8):
   a=math.radians(i*45+22.5)
   pts=[P(r*math.cos(a+da)*f,r*math.sin(a+da)*f) for da,f in ((-.17,1),(.17,1),(.17,.72),(-.17,.72))]
   fill(cell,poly_mask(cell.size,pts),(250,240,250))
  ring=art.shape_mask(cell.size,lambda d,s:d.ellipse((s*(cx-58*k),s*(cy-58*k),s*(cx+58*k),s*(cy+58*k)),fill=255))
  fill(cell,ring,(20,8,24));fill(cell,art.shape_mask(cell.size,lambda d,s:d.ellipse((s*(cx-58*k),s*(cy-58*k),s*(cx+58*k),s*(cy+58*k)),outline=255,width=int(5*k*s))),CYAN)
  art.hud_text(cell,'77',cx,cy,int(54*k),CYAN+(255,),weight=.2,glow_color=CYAN,glow_radius=5*k)
 elif name=='bar':
  plate=art.shape_mask(cell.size,lambda d,s:d.rounded_rectangle((s*(cx-118*k),s*(cy-50*k),s*(cx+118*k),s*(cy+50*k)),radius=int(14*k*s),fill=255))
  glow_mask(plate,CYAN,12,1.0);fill(cell,plate,art.gradient(cell.size,(70,76,92),(14,16,22)))
  fill(cell,art.shape_mask(cell.size,lambda d,s:d.rounded_rectangle((s*(cx-118*k),s*(cy-50*k),s*(cx+118*k),s*(cy+50*k)),radius=int(14*k*s),outline=255,width=int(5*k*s))),CYAN)
  art.hud_text(cell,'BAR',cx+2*k,cy,int(62*k),(240,252,255,255),tracking=1.4,weight=.2,glow_color=CYAN,glow_radius=6*k)
 elif name=='bell':
  outline=[P(-80,62),P(-64,44),P(-54,-20),P(-30,-62),P(0,-74),P(30,-62),P(54,-20),P(64,44),P(80,62)]
  m=poly_mask(cell.size,outline);glow_mask(m,GOLD,12,1.3)
  fill(cell,m,art.gradient(cell.size,(255,224,140),(196,120,20),horizontal=True))
  fill(cell,poly_mask(cell.size,[P(-30,-58),P(-8,-68),P(-30,40),P(-50,40)]),(255,244,200))
  fill(cell,poly_mask(cell.size,[P(-84,60),P(84,60),P(84,74),P(-84,74)]),(170,100,10))
  fill(cell,art.shape_mask(cell.size,lambda d,s:d.ellipse((s*(cx-16*k),s*(cy+66*k),s*(cx+16*k),s*(cy+96*k)),fill=255)),(230,160,40))
  fill(cell,art.shape_mask(cell.size,lambda d,s:d.ellipse((s*(cx-10*k),s*(cy-90*k),s*(cx+10*k),s*(cy-70*k)),fill=255)),(230,160,40))
 elif name=='grape':
  hexes=[]
  for row,(n,y) in enumerate(((4,-46),(3,-6),(2,34),(1,72))):
   for i in range(n):hexes.append((-(n-1)*22+i*44,y))
  allm=Image.new('L',cell.size,0)
  for x,y in hexes:
   pts=[P(x+21*math.cos(math.radians(60*j+30)),y+21*math.sin(math.radians(60*j+30))) for j in range(6)];hm=poly_mask(cell.size,pts)
   allm=Image.fromarray(__import__('numpy').maximum(__import__('numpy').asarray(allm),__import__('numpy').asarray(hm)))
  glow_mask(allm,VIOLET,12,1.4)
  for x,y in hexes:
   pts=[P(x+20*math.cos(math.radians(60*j+30)),y+20*math.sin(math.radians(60*j+30))) for j in range(6)]
   fill(cell,poly_mask(cell.size,pts),radial((W,H),(214,150,255),(90,20,170),center=((cx+(x-8)*k)/W,(cy+(y-8)*k)/H),power=.6))
   fill(cell,poly_mask(cell.size,[P(x-11,y-12),P(x-3,y-15),P(x-8,y-6)]),(240,220,255))
  fill(cell,poly_mask(cell.size,[P(4,-70),P(64,-98),P(40,-64)]),(40,220,160))
  ImageDraw.Draw(cell,'RGBA').line((P(0,-64),P(10,-86)),fill=(40,220,160,255),width=int(6*k))
 elif name=='lemon':
  pts=[P(-96,0),P(-74,-30),P(-36,-54),P(18,-58),P(62,-40),P(88,-12),P(100,0),P(88,14),P(60,42),P(16,58),P(-36,54),P(-74,30)]
  m=poly_mask(cell.size,pts);glow_mask(m,(255,230,40),12,1.3)
  fill(cell,m,art.gradient(cell.size,(255,246,120),(230,170,0)))
  fill(cell,poly_mask(cell.size,[P(-96,0),P(-74,-30),P(-36,-54),P(-20,-20),P(-50,4)]),(255,252,190))
  fill(cell,poly_mask(cell.size,[P(16,58),P(60,42),P(88,14),P(40,10)]),(214,150,0))
 elif name=='cherry':
  d=ImageDraw.Draw(cell,'RGBA');green=(40,230,150,255)
  stem=Image.new('RGBA',cell.size,(0,0,0,0));sd=ImageDraw.Draw(stem,'RGBA')
  sd.line((P(-48,26),P(-6,-56),P(30,-82)),fill=green,width=int(8*k),joint='curve');sd.line((P(50,30),P(16,-52),P(30,-82)),fill=green,width=int(8*k),joint='curve')
  art.glow(cell,stem,6*k,1.2)
  fill(cell,poly_mask(cell.size,[P(30,-82),P(84,-96),P(66,-70)]),(40,230,150))
  for x,y in ((-48,40),(50,44)):
   r=44;m=art.shape_mask(cell.size,lambda d,s,x=x,y=y:d.ellipse((s*(cx+(x-r)*k),s*(cy+(y-r)*k),s*(cx+(x+r)*k),s*(cy+(y+r)*k)),fill=255))
   glow_mask(m,RED,12,1.2);fill(cell,m,radial((W,H),(255,140,150),(170,0,30),center=((cx+(x-14)*k)/W,(cy+(y-16)*k)/H),power=.7))
   fill(cell,art.shape_mask(cell.size,lambda d,s,x=x,y=y:d.ellipse((s*(cx+(x-24)*k),s*(cy+(y-28)*k),s*(cx+(x-8)*k),s*(cy+(y-14)*k)),fill=255)),(255,230,235))
 else:raise ValueError(name)

def symbol_cell(name,size=(512,256),background=True):
 """One reel entry; drawn on a 2.35:1 canvas (the entry's real shape) then fitted to the cell."""
 W,H=600,256
 if background:
  cell=art.gradient((W,H),(18,20,34),(6,7,14));d=ImageDraw.Draw(cell,'RGBA')
  for y in range(0,H,4):d.line((0,y,W,y),fill=(255,255,255,6))
  d.line((0,1,W,1),fill=(40,48,70,255),width=3);d.line((0,H-2,W,H-2),fill=(40,48,70,255),width=3)
 else:cell=Image.new('RGBA',(W,H),(0,0,0,0))
 draw_symbol(cell,name)
 return cell.resize(size,Image.Resampling.LANCZOS)

def city(size,seed,base_y,height,color,lit=((255,190,80),(34,230,255),(255,46,158)),density=.16):
 """Original skyline silhouette with lit windows, as an RGBA layer."""
 import random
 W,H=size;rng=random.Random(seed);im=Image.new('RGBA',size,(0,0,0,0));d=ImageDraw.Draw(im,'RGBA');x=-10
 while x<W:
  w=rng.randint(int(W*.025),int(W*.07));h=rng.randint(int(height*.3),height)
  d.rectangle((x,base_y-h,x+w,base_y),fill=color+(255,))
  if rng.random()<.35:d.rectangle((x+w//2-2,base_y-h-rng.randint(10,40),x+w//2+2,base_y-h),fill=color+(255,))
  for wy in range(base_y-h+8,base_y-6,11):
   for wx in range(x+4,x+w-4,9):
    if rng.random()<density:c=rng.choice(lit);d.rectangle((wx,wy,wx+3,wy+4),fill=c+(170,))
  x+=w+rng.randint(2,10)
 return im

def marquee():
 """Curved topper: 0.82 x 0.72 m screen (drawn at that ratio, fitted to 1024 square)."""
 import numpy as np
 W,H=1170,1024;im=art.gradient((W,H),(30,8,58),(8,4,22));d=ImageDraw.Draw(im,'RGBA')
 hy=720
 # Rising sun: slatted disc, gold to magenta, sitting on the horizon.
 R=230;sun=art.gradient((2*R,2*R),(255,214,110),(255,40,150));sm=np.asarray(art.shape_mask((2*R,2*R),lambda dd,s:dd.ellipse((0,0,2*R*s,2*R*s),fill=255))).copy()
 for k2,y in enumerate(range(int(R*1.0),2*R,22)):sm[y:y+4+k2*2,:]=0
 sm[hy-(hy-R)+0:,:]=sm[hy-(hy-R)+0:,:]
 layer=Image.new('RGBA',(W,H),(0,0,0,0));fill(layer,Image.fromarray(sm),sun,(W//2-R,hy-R+20))
 layer=layer.crop((0,0,W,hy));full=Image.new('RGBA',(W,H),(0,0,0,0));full.alpha_composite(layer);art.glow(im,full,24,.9)
 im.alpha_composite(city((W,H),78,hy,170,(22,10,44),density=.10))
 im.alpha_composite(city((W,H),77,hy,110,(8,4,18),density=.14))
 # Perspective floor grid.
 d=ImageDraw.Draw(im,'RGBA');d.rectangle((0,hy,W,H),fill=(10,4,22,255))
 for i in range(-16,17):d.line((W/2+i*24,hy,W/2+i*200,H),fill=(255,46,158,120),width=3)
 for j in range(1,12):y=hy+(H-hy)*(j/11)**1.8;d.line((0,y,W,y),fill=(255,46,158,int(60+80*j/11)),width=2)
 hz=Image.new('RGBA',(W,H),(0,0,0,0));ImageDraw.Draw(hz,'RGBA').rectangle((0,hy-2,W,hy+2),fill=(255,120,200,255));art.glow(im,hz,8,1.2)
 # Title block.
 art.hud_text(im,'LUCKY',W/2,168,160,(236,252,255,255),tracking=1.6,weight=.17,slant=.12,glow_color=CYAN,glow_radius=18,glow_strength=1.8)
 art.hud_text(im,'CIRCUIT',W/2,352,132,(255,232,244,255),tracking=1.8,weight=.17,slant=.12,glow_color=MAGENTA,glow_radius=18,glow_strength=1.8)
 d=ImageDraw.Draw(im,'RGBA');d.line((W/2-440,262,W/2+440,262),fill=CYAN+(255,),width=4)
 for x in (W/2-440,W/2+440):d.polygon([(x-12,262),(x,250),(x+12,262),(x,274)],fill=CYAN+(255,))
 art.hud_text(im,'THREE SEVENS PAY x200',W/2,440,40,GOLD+(255,),tracking=1.6,weight=.18,glow_color=GOLD,glow_radius=8)
 # Frame.
 d.rectangle((10,10,W-11,H-11),outline=(255,46,158,255),width=8);d.rectangle((28,28,W-29,H-29),outline=(34,230,255,160),width=3)
 for x,y in ((28,28),(W-29,28),(28,H-29),(W-29,H-29)):d.rectangle((x-10,y-10,x+10,y+10),fill=(34,230,255,255))
 return im.resize((1024,1024),Image.Resampling.LANCZOS)

def belly():
 """Lower belly glass, 0.82 x 0.175 m (fitted to 1024x256)."""
 W,H=1200,256;im=art.gradient((W,H),(10,10,22),(22,6,34));d=ImageDraw.Draw(im,'RGBA')
 # Circuit traces.
 import random
 rng=random.Random(4)
 for _ in range(40):
  x=rng.randint(0,W);y=rng.choice([30,60,196,226]);L=rng.randint(40,160);c=rng.choice([CYAN,MAGENTA])
  d.line((x,y,x+L,y,x+L+20,y+(20 if y<128 else -20)),fill=c+(90,),width=2);d.ellipse((x-4,y-4,x+4,y+4),outline=c+(150,),width=2)
 art.hud_text(im,'CIRCUIT SERIES · 77',W/2,104,58,(240,252,255,255),tracking=1.8,weight=.15,glow_color=CYAN,glow_radius=8)
 art.hud_text(im,'HIGH LIMIT  ·  1 TO 1,000 PER PULL',W/2,178,30,GOLD+(255,),tracking=1.6,weight=.17)
 d.rectangle((4,4,W-5,H-5),outline=MAGENTA+(255,),width=5)
 return im.resize((1024,256),Image.Resampling.LANCZOS)

def paytable(symbols,table):
 """Paytable screen, 0.84 x 0.21 m (2048x512): three of a kind, then the fruit rules."""
 W,H=2048,512;im=art.gradient((W,H),(10,14,30),(3,4,10));d=ImageDraw.Draw(im,'RGBA')
 d.rectangle((6,6,W-7,H-7),outline=CYAN+(255,),width=6)
 art.hud_text(im,'THREE OF A KIND ON THE CENTER LINE PAYS',W/2,42,34,CYAN+(255,),tracking=1.8,weight=.17)
 order=sorted(table['three'],key=lambda k:(-table['three'][k],symbols.index(k)))
 cw=W/4
 for i,name in enumerate(order):
  col,row=i%4,i//4;x0=col*cw;y0=78+row*156
  icon=symbol_cell(name,(300,140),background=False);im.alpha_composite(icon,(int(x0+10),int(y0+4)))
  if col:d.line((x0,y0+24,x0,y0+124),fill=(34,230,255,60),width=2)
  art.hud_text(im,'x'+str(table['three'][name]),x0+cw-34,y0+74,72,(255,236,200,255),anchor='rm',tracking=1.2,weight=.19,glow_color=GOLD,glow_radius=8)
 d.line((40,398,W-40,398),fill=(34,230,255,120),width=2)
 rules=[('CHERRY CHERRY ANY','x'+str(table['twoCherries'])),('ANY 3 FRUIT','x'+str(table['mixedFruit'])),('CHERRY ON REEL 1','x'+str(table['oneCherry']))]
 for i,(label,pay) in enumerate(rules):
  x=W*(i+.5)/3;lw=art.text_size(label,36,1.3,.17)[0];pw=art.text_size(pay,50,1.2,.19)[0];x0=x-(lw+28+pw)/2
  art.hud_text(im,label,x0,455,36,(220,232,250,255),anchor='lm',tracking=1.3,weight=.17)
  art.hud_text(im,pay,x0+lw+28,455,50,MAGENTA+(255,),anchor='lm',tracking=1.2,weight=.19,glow_color=MAGENTA,glow_radius=6)
  if i:d.line((W*i/3,420,W*i/3,490),fill=(34,230,255,90),width=2)
 return im

def artwork(symbols):
 result={}
 atlas=Image.new('RGBA',(1024,1024),INK+(255,))
 for k,name in enumerate(symbols):
  col,row=k%2,k//2;atlas.alpha_composite(symbol_cell(name),(col*512,row*256))
 result['slot_symbols']=atlas
 result['slot_marquee']=marquee()
 result['slot_belly']=belly()
 result['slot_paytable']=paytable(symbols,pays())
 return result

# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so the cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V=True
def cooked(image):return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image

def encode_texture(directory,name,image,template):
 image=Image.alpha_composite(Image.new('RGBA',image.size,(0,0,0,255)),image.convert('RGBA'));source=RESOURCE/'sources'/(name+'.png');image.save(source)
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
 """metal_base instance: BaseColor (texture or white x colour), roughness,
 metalness and, for emissive keys, Emissive/EmissiveEV/EmissiveColor (the same
 parameters the lab's emissive vehicle lenses use on metal_base)."""
 value,rough,metal,ev=MATERIALS[key];result=ORIGINAL_MATERIAL(base.WHITE)
 if key in TEXTURED:
  texture=base.ref(DEPOT+'\\textures\\'+value+'.xbm');rgb=[1,1,1];tint=(255,255,255)
 else:
  texture=base.ref('engine\\textures\\editor\\white.xbm');tint=tuple(int(value[i:i+2],16) for i in (1,3,5));rgb=[linear(v) for v in tint]
 result['values'][0]['BaseColor']=texture;result['values'][1]['BaseColorScale'].update(X=rgb[0],Y=rgb[1],Z=rgb[2])
 result['values'][2]['RoughnessScale']=rough;result['values'][3]['MetalnessScale']=metal
 if EMISSIVE and ev is not None:
  result['values']+= [{'$type':'rRef:ITexture','Emissive':copy.deepcopy(texture)},{'$type':'Float','EmissiveEV':ev},
   {'$type':'Color','EmissiveColor':{'$type':'Color','Red':tint[0],'Green':tint[1],'Blue':tint[2],'Alpha':255}}]
 return result
base.material=material

def glb(path,faces):
 colors=base.glb(path,faces)
 # Write the explicit atlas/panel UVs over the shared cooker's planar ones.
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
  if key in TEXTURED:m['texture']=images[value]
  else:m['color']=tuple(int(value[i:i+2],16) for i in (1,3,5))
  return m
 return resolve

def previews(geometry,images,strips,symbols):
 """Design renders written to sources/preview_*.png (not shipped in the archive)."""
 def scene(lit=True,lever=0,stops=(7,5,7),coins=3):
  v=art.Preview(preview_resolver(images));v.add(geometry['slot_cabinet'])
  for r in range(3):v.add(geometry[f'slot_strip_{r+1}'],(LAYOUT['reelX'][r],LAYOUT['stripY'],PZ+(stops[r]+1)*P))
  v.add(geometry[f'slot_lever_{lever}'])
  v.add(geometry['slot_lamp_on' if lit else 'slot_lamp_off'])
  for i in range(coins):v.add(geometry['slot_coin'],((-.06,.03,-.01,.07)[i],LAYOUT['trayY'],LAYOUT['trayZ']),(0,47,113,160)[i])
  return v
 out={}
 out['preview_slots_hero']=scene().render((1.75,-3.1,2.0),(.02,0,1.3),fov=46,size=(1000,1300))
 out['preview_slots_player']=scene(lit=False,coins=0).render((0,-1.25,1.36),(0,0,1.3),fov=52,size=(1200,900))
 out['preview_slots_reels']=scene(lit=False,coins=0).render((.05,-1.05,1.45),(0,-.36,1.45),fov=34,size=(1200,900))
 out['preview_slots_lever']=scene(lever=3).render((1.7,-1.55,1.7),(.2,0,1.25),fov=52,size=(1200,900))
 for name,im in out.items():im.save(RESOURCE/'sources'/(name+'.png'),optimize=True)
 return out

def bounds(faces):
 return [min(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)],[max(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)]

def check_layout(geometry,symbols,strips):
 """Geometry invariants the client timeline relies on."""
 (bx0,bx1),(by0,by1),(bz0,bz1)=BODY_BOX;(cx0,cx1),(cy0,cy1),(cz0,cz1)=BAY
 def inside(lo,hi,dx=0,dy=0,dz=0,margin=.002):
  return bx0+margin<=lo[0]+dx and hi[0]+dx<=bx1-margin and by0+margin<=lo[1]+dy and hi[1]+dy<=by1-margin and bz0+margin<=lo[2]+dz and hi[2]+dz<=bz1-margin
 def clear_of_bay(lo,hi,dx=0,dy=0,dz=0):
  return hi[0]+dx<cx0 or lo[0]+dx>cx1 or hi[1]+dy<cy0 or lo[1]+dy>cy1 or hi[2]+dz<cz0 or lo[2]+dz>cz1
 park=LAYOUT['leverPark']
 for i in range(len(LAYOUT['leverAngles'])):
  lo,hi=bounds(geometry[f'slot_lever_{i}'])
  assert inside(lo,hi,*park) and clear_of_bay(lo,hi,*park),('parked lever pose is visible',i,lo,hi)
  assert lo[0]>bx1,('active lever intersects the cabinet',i)
 for name in ('slot_lamp_on','slot_lamp_off'):
  lo,hi=bounds(geometry[name]);assert lo[2]>=bz1+.03 and inside(lo,hi,*LAYOUT['lampPark']) and clear_of_bay(lo,hi,*LAYOUT['lampPark']),name
 lo,hi=bounds(geometry['slot_coin']);cp=LAYOUT['coinPark']
 for x in (-.06,.03,-.01,.07):assert inside([x+lo[0],cp[1]+lo[1],cp[2]+lo[2]],[x+hi[0],cp[1]+hi[1],cp[2]+hi[2]]) and clear_of_bay([x+lo[0],cp[1]+lo[1],cp[2]+lo[2]],[x+hi[0],cp[1]+hi[1],cp[2]+hi[2]])
 # Strips: for every payline position j in [1,STOPS+1) (incl. overshoot wrap)
 # the strip covers the window and stays inside the dark bay.
 w=LAYOUT['reelWidth']
 for r,x in enumerate(LAYOUT['reelX']):
  lo,hi=bounds(geometry[f'slot_strip_{r+1}'])
  assert abs(lo[0]+w/2)<1e-9 and abs(hi[0]-w/2)<1e-9 and lo[1]==hi[1]==0
  assert cx0<x-w/2 and x+w/2<cx1 and cy0<LAYOUT['stripY']<cy1
  for step in range(STOPS*20+1):
   j=1+step/20;zt=PZ+j*P+hi[2];zb=PZ+j*P+lo[2]
   assert cz0<zb and zt<cz1,('strip leaves the bay',r,j)
   assert zb<WINDOW_Z[0]-.005 and zt>WINDOW_Z[1]+.005,('strip does not cover the window',r,j)
  # The strip wraps seamlessly: entries j and j+STOPS show the same symbols.
  entries=[strips[r][-1]]+strips[r]+strips[r][:2]
  for j in range(3):assert entries[j]==entries[j+STOPS]
 # Window: strips' outer edges and divider gaps are behind the bezel.
 assert WINDOW_X[0]>LAYOUT['reelX'][0]-w/2 and WINDOW_X[1]<LAYOUT['reelX'][2]+w/2
 assert HOLE_X[0]>=cx0 and HOLE_X[1]<=cx1 and cz0<WINDOW_Z[0] and WINDOW_Z[1]<cz1


def verify(work,manifest):
 """Independent cooked-file, namespace, package-index and authored-pose checks."""
 spec=importlib.util.spec_from_file_location('archive_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
 archive=work/'archive';verified=work/'verified';packed=(work/'packed/archive.archive').read_bytes()
 entries=checks.archive_entries(packed);files=manifest['files']
 assert len(manifest['models'])==13 and len(manifest['textures'])==len(TEXTURED)==4
 assert len(entries)==len(files)==2*13+4+len(COLLIDERS)
 assert [row['for'] for row in manifest['colliders']]==list(COLLIDERS)
 for row in manifest['colliders']:
  assert row['name']==col.collider_name(row['for']) and row['for'] in COLLIDERS and row['scaleBaked']==col.SCALE
  col.check_collider_entity(next(verified.rglob(row['name']+'.ent.json')),COLLIDERS[row['for']])
 assert set(entries)=={checks.fnv(row['depot']) for row in files}
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
     assert all(math.isfinite(v) for pair in values for v in pair) and len(set(values))>1
     if model['materials'][chunk_index] in TEXTURED:
      assert all(-.001<=v<=1.001 for pair in values for v in pair),(name,'atlas UV out of bounds')
    mats=r['localMaterialBuffer']['materials'];names={e['name']['$value'] for e in r['materialEntries']}
    for key,mat in zip(model['materials'],mats):   # emissive keys keep a non-black Emissive tint through the round trip
     values={k:v for e in mat['values'] for k,v in e.items() if k!='$type'}
     if EMISSIVE and MATERIALS[key][3] is not None:
      assert abs(values['EmissiveEV']-MATERIALS[key][3])<1e-5 and values['Emissive']['DepotPath']['$value']==values['BaseColor']['DepotPath']['$value'],(name,key)
      assert max(values['EmissiveColor'][c] for c in ('Red','Green','Blue'))>0,(name,key)
     else:assert 'Emissive' not in values,(name,key)
    assert all(0<=e['index']<len(mats) for e in r['materialEntries'])
    assert all(c['$value'] in names for a in r['appearances'] for c in a['Data']['chunkMaterials'])
    lo,hi=r['boundingBox']['Min'],r['boundingBox']['Max']
    for i,axis in enumerate(('X','Y','Z')):
     assert math.isfinite(lo[axis]) and math.isfinite(hi[axis]) and lo[axis]<=hi[axis]
     assert abs(lo[axis]-model['bounds']['min'][i])<1e-5 and abs(hi[axis]-model['bounds']['max'][i])<1e-5
 for texture in manifest['textures']:
  r=json.loads(next(verified.rglob(texture['name']+'.xbm.json')).read_text())['Data']['RootChunk']
  assert r['$type']=='CBitmapTexture' and r['width']==texture['width'] and r['height']==texture['height']
  blob=r['renderTextureResource']['renderResourceBlobPC']['Data'];data=base64.b64decode(blob['textureData']['Bytes'])
  assert len(blob['header']['mipMapInfo'])==texture['mips']
  source=RESOURCE/'sources'/(texture['name']+'.png');image=Image.open(source).convert('RGBA')
  assert hashlib.sha256(source.read_bytes()).hexdigest()==texture['sourceSha256']
  assert data[:image.width*image.height*4]==(cooked(image) if texture.get('flipV') else image).tobytes() and all(v==255 for v in data[3::4])
 symbols,strips=reels();assert manifest['symbols']==symbols and manifest['reels']==strips and manifest['layout']==LAYOUT
 check_layout(models(symbols,strips),symbols,strips)
 with zipfile.ZipFile(RESOURCE/'dist/open77_casino_slots.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_casino_slots.archive']
  assert z.read(z.namelist()[0])==packed
 print('VERIFIED: 13 native props (cabinet, 3 strips, 6 lever poses, 2 lamps, coin), 4 opaque mipmapped textures, 30 exact RDAR entries + '+str(len(COLLIDERS))+' collider entity, emissive neon/screens, geometry/bindings/package hashes, parked poses hidden, strips always cover the window inside the bay',flush=True)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path('/tmp/casino-slots-props/build'));p.add_argument('--verify-only',action='store_true');p.add_argument('--preview',action='store_true',help='write sources/*.png and the preview renders, then stop');a=p.parse_args();work=a.work
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 symbols,strips=reels();geometry=models(symbols,strips);check_layout(geometry,symbols,strips)
 if a.preview:
  (RESOURCE/'sources').mkdir(parents=True,exist_ok=True);images=artwork(symbols)
  for name,image in images.items():Image.alpha_composite(Image.new('RGBA',image.size,(0,0,0,255)),image.convert('RGBA')).save(RESOURCE/'sources'/(name+'.png'))
  previews(geometry,images,strips,symbols);print('PREVIEWS written to',RESOURCE/'sources',flush=True);return
 tools=a.lab/'tools';env=os.environ.copy();env['DOTNET_ROOT']=str(tools/'dotnet');env['DOTNET_CLI_HOME']=str(work/'dotnet-home')
 def cli(*args,imports=0):
  result=subprocess.run([str(tools/'dotnet/dotnet'),str(tools/'wolvenkit/WolvenKit.CLI.dll'),*map(str,args)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  if '[ 0: Error' in result.stdout or (result.returncode and not(imports and result.stdout.count('Rebuilt with buffers:')==imports)):print(result.stdout);raise RuntimeError('WolvenKit failed '+str(args))
  print('\n'.join(line for line in result.stdout.splitlines() if 'Success' in line),flush=True)
 schemas=work/'json';raw=work/'raw';tex=work/'texture-json';host=work/'host-schema';template_dir=work/'texture-template'
 for folder in (schemas,raw,tex,host,template_dir,RESOURCE/'sources'):folder.mkdir(parents=True,exist_ok=True)
 donor=json.loads((a.lab/'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_text())
 cli('convert','serialize','/home/dop42/opx_pool_assets/assets/hosts/open77/assets/opx_infinity/pool/ball_01.ent','-o',host);template=json.loads((host/'ball_01.ent.json').read_text())
 # The shared cooker's wood textures only serve as an XBM schema template here.
 base.RESOURCE=work/'texture-template-resource';base.wood_textures(template_dir);base.RESOURCE=RESOURCE
 texture_template=json.loads((template_dir/'wood_ivory.xbm.json').read_text())
 textures=[encode_texture(tex,name,image,texture_template) for name,image in artwork(symbols).items()]
 records=[]
 for i,(name,faces) in enumerate(geometry.items()):
  for f in faces:
   p1,p2,p3=(f[k] for k in ('a','b','c'));normal=base.cross([p2[j]-p1[j] for j in range(3)],[p3[j]-p1[j] for j in range(3)])
   assert sum(x*x for x in normal)>1e-22,(name,f)
  colors=glb(raw/(name+'.mesh.glb'),faces)
  (schemas/(name+'.mesh.json')).write_text(json.dumps(base.mesh_json(donor,colors,faces)))
  (schemas/(name+'.ent.json')).write_text(json.dumps(base.entity_json(template,name,i)))
  lo,hi=bounds(faces)
  records.append({'name':name,'mesh':DEPOT+'\\'+name+'.mesh','entity':DEPOT+'\\'+name+'.ent','triangles':len(faces),'materials':colors,'bounds':{'min':lo,'max':hi}})
 colliders=[]
 for i,(name,boxes) in enumerate(COLLIDERS.items()):
  (schemas/(col.collider_name(name)+'.ent.json')).write_text(json.dumps(col.collider_entity_json(template,boxes,i)))
  colliders.append({'name':col.collider_name(name),'for':name,'entity':DEPOT+'\\'+col.collider_name(name)+'.ent','scaleBaked':col.SCALE,'boxes':[{'size':list(b.size),'center':list(b.center)} for b in boxes]})
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');(target/'textures').mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target);cli('convert','deserialize',tex,'-o',target/'textures');cli('import',*[raw/(name+'.mesh.glb') for name in geometry],'-o',target,'--keep',imports=len(geometry))
 verified=work/'verified';verified.mkdir(exist_ok=True);cli('convert','serialize',archive,'-o',verified);packed=work/'packed';packed.mkdir(exist_ok=True);cli('pack',archive,'-o',packed)
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_casino_slots.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_casino_slots.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 manifest={'version':'2.0.0','style':'Night City black chrome cabinet: cyan neon fins, curved topper, emissive screens and reels','namespace':DEPOT,'models':records,'colliders':colliders,'textures':textures,'files':files,'symbols':symbols,'reels':strips,'layout':LAYOUT,
  'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
