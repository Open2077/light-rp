#!/usr/bin/env python3
"""Cook the original blackjack table, 52 cards + back/turn poses and chip stacks.

Uses the native board-prop cooker (tools/build-board-game-props.py) as a
read-only schema/tool library, the same way build-tabletop-extra-props.py does.
Only this resource and --work receive outputs. Requires Pillow for the original
felt, card and chip artwork, plus .NET and WolvenKit from the local lab.

Coordinates are unscaled metres (the client renders every prop at 0.65). The
table origin is the floor under the centre of the felt arc; the felt is at
Z=1.35, players sit around the arc at -Y and the dealer stands at +Y.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,random,struct,subprocess,zipfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
RESOURCE=ROOT/'resources/assets/models/open77_casino_blackjack'
DEPOT='open77\\assets\\op77_lightrp\\casino_blackjack'
LAB=ROOT.parent/'dop-tests'
FONT=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
FONT_REGULAR=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()

# Layout shared with client/core/casino_blackjack.lua.
FZ=1.35;FELT_R=1.00;RAIL_R=1.12;DEALER_EDGE=.14;APRON=.26
SEAT_ANGLES=[54,18,-18,-54]
SEAT_R=.80;CARD_R=.55
CARD_W,CARD_H,CARD_T=.100,.130,.0016
CHIP_R,CHIP_T=.030,.0052
RANKS='A23456789TJQK';SUITS='SHDC'
DENOMS=[(1,4,'#E9E6DEFF','#2C5DAAFF'),(5,4,'#B71F2BFF','#F2EFE8FF'),(25,3,'#1E7B3CFF','#F2EFE8FF'),
        (100,4,'#1A1A1EFF','#F2EFE8FF'),(500,1,'#5E2D8CFF','#F2EFE8FF'),(1000,10,'#D9901EFF','#1A1A1EFF')]
# Material keys: textured keys name an atlas; plain colours are untextured.
TEX={'TEX:felt':'bj_felt','TEX:cards':'bj_cards','TEX:chips':'bj_chips'}
CARD_EDGE='#EDEAE1FF';LEATHER='#241915FF';METAL='#1B1D22FF';SMOKE='#1C2029FF';NEON='#16C2D4FF';BRASS='#B79048FF'
PLAIN={CARD_EDGE:(.55,0),LEATHER:(.55,0),METAL:(.38,.65),SMOKE:(.22,.1),NEON:(.3,0),BRASS:(.3,.78)}
for _,_,c,s in DENOMS:PLAIN.setdefault(c,(.45,0));PLAIN.setdefault(s,(.45,0))
WOOD=base.WOOD_FRAME

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
def box(out,x0,x1,y0,y1,z0,z1,color):g.box(out,(x0+x1)/2,(y0+y1)/2,(z0+z1)/2,x1-x0,y1-y0,z1-z0,color)

# --- Card atlas: 13 ranks x 4 suits, back at row 4 -------------------------
ATLAS_W,ATLAS_H,CELL_W,CELL_H=2048,1024,157,204
def cell_uv(col,row):
 x0,y0=col*CELL_W+1.5,row*CELL_H+1.5;x1,y1=(col+1)*CELL_W-1.5,(row+1)*CELL_H-1.5
 return x0/ATLAS_W,y0/ATLAS_H,x1/ATLAS_W,y1/ATLAS_H
def card_cell(code):return RANKS.index(code[0]),SUITS.index(code[1])
BACK_CELL=(0,4)
def card_faces(top,bottom,edge=CARD_EDGE):
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

# --- Chip stacks --------------------------------------------------------------
CHIP_CELL=170
def chip_uv(index,x,y):
 col,row=index%3,index//3;cx,cy=(col*CHIP_CELL+85)/512,(row*CHIP_CELL+85)/512;r=80/512
 return [cx+x/CHIP_R*r,cy-y/CHIP_R*r]
def chip_stack(index,count):
 out=[];_,_,color,stripe=DENOMS[index];n=24
 for i in range(count):
  z0,z1=i*CHIP_T,(i+1)*CHIP_T
  for j in range(n):
   a,b=j*math.tau/n,(j+1)*math.tau/n
   c=stripe if (j+i)%3==0 else color
   p=[[CHIP_R*math.cos(a),CHIP_R*math.sin(a),z0],[CHIP_R*math.cos(b),CHIP_R*math.sin(b),z0],[CHIP_R*math.cos(b),CHIP_R*math.sin(b),z1],[CHIP_R*math.cos(a),CHIP_R*math.sin(a),z1]]
   oriented(out,p,c,[math.cos((a+b)/2),math.sin((a+b)/2),0])
 top=count*CHIP_T
 for j in range(n):
  a,b=j*math.tau/n,(j+1)*math.tau/n
  pa=[CHIP_R*math.cos(a),CHIP_R*math.sin(a),top];pb=[CHIP_R*math.cos(b),CHIP_R*math.sin(b),top]
  tri(out,[0,0,top],pa,pb,'TEX:chips',[chip_uv(index,0,0),chip_uv(index,pa[0],pa[1]),chip_uv(index,pb[0],pb[1])])
  tri(out,[0,0,0],[pb[0],pb[1],0],[pa[0],pa[1],0],color)
 return out

# --- The table ------------------------------------------------------------------
def felt_uv(x,y):return [(x+1.04)/2.08,(.16-y)/1.20]
def arc(r,steps=72):return [(r*math.cos(math.pi+math.pi*i/steps),r*math.sin(math.pi+math.pi*i/steps)) for i in range(steps+1)]
def fan(out,outline,z,color,center,down=False,uvf=None):
 for p,q in zip(outline,outline[1:]+outline[:1]):
  pts=[[center[0],center[1],z],[p[0],p[1],z],[q[0],q[1],z]]
  uv=[uvf(*pt[:2]) for pt in pts] if uvf else None
  n=cross([pts[1][i]-pts[0][i] for i in range(3)],[pts[2][i]-pts[0][i] for i in range(3)])
  if (n[2]<0)!=down:pts=pts[::-1];uv=uv[::-1] if uv else None
  tri(out,*pts,color,uv)
def sweep(out,path,profile,color,center):
 """Sweep a (radial offset, z) profile along a path of (x,y,outward-x,outward-y)."""
 for (x0,y0,nx0,ny0),(x1,y1,nx1,ny1) in zip(path,path[1:]):
  for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
   p=[[x0+nx0*r0,y0+ny0*r0,z0],[x1+nx1*r0,y1+ny1*r0,z0],[x1+nx1*r1,y1+ny1*r1,z1],[x0+nx0*r1,y0+ny0*r1,z1]]
   mid=[sum(v[i] for v in p)/4 for i in range(3)]
   cx=(x0+x1)/2+(nx0+nx1)/2*center[0];cy=(y0+y1)/2+(ny0+ny1)/2*center[0]
   oriented(out,p,color,[mid[0]-cx,mid[1]-cy,mid[2]-center[1]])
def table():
 out=[]
 outline=arc(FELT_R)+[(FELT_R,DEALER_EDGE),(-FELT_R,DEALER_EDGE)]
 fan(out,outline,FZ,'TEX:felt',(0,-.35),uvf=felt_uv)
 # Padded leather rail around the arc and up both straight sides.
 profile=[(0,FZ-.005),(0,FZ+.022),(.018,FZ+.043),(.055,FZ+.052),(.095,FZ+.043),(.12,FZ+.018),(.12,FZ-.07)]
 path=[(x,y,x/FELT_R,y/FELT_R) for x,y in arc(FELT_R)]
 sweep(out,path,profile,LEATHER,(.06,FZ))
 for side in (-1,1):sweep(out,[(side*FELT_R,0,side,0),(side*FELT_R,APRON,side,0)],profile,LEATHER,(.06,FZ))
 # Dealer apron, underside and the brass trim line under the rail.
 box(out,-RAIL_R,RAIL_R,DEALER_EDGE,APRON,FZ-.08,FZ+.03,WOOD)
 bottom=arc(RAIL_R)+[(RAIL_R,APRON),(-RAIL_R,APRON)]
 fan(out,bottom,FZ-.08,WOOD,(0,-.35),down=True)
 sweep(out,[(x,y,x/RAIL_R,y/RAIL_R) for x,y in arc(RAIL_R-.02)],[(0,FZ-.08),(.02,FZ-.08),(.02,FZ-.07)],BRASS,(-.5,FZ))
 # Pedestal: column, foot and a neon kick strip.
 box(out,-.16,.16,-.48,-.22,.05,FZ-.08,METAL)
 box(out,-.46,.46,-.62,-.08,0,.05,METAL)
 box(out,-.47,.47,-.63,-.07,.012,.022,NEON)
 # Card shoe on the dealer's left (+X): smoked body, ramp, card stack, top card.
 box(out,.60,.80,-.10,.16,FZ,FZ+.085,SMOKE)
 oriented(out,[[.61,-.10,FZ+.03],[.79,-.10,FZ+.03],[.79,-.145,FZ+.004],[.61,-.145,FZ+.004]],SMOKE,[0,-.5,1])
 box(out,.648,.752,-.104,-.06,FZ+.03,FZ+.07,CARD_EDGE)
 u0,v0,u1,v1=cell_uv(*BACK_CELL)
 oriented(out,[[.65,-.142,FZ+.0062],[.75,-.142,FZ+.0062],[.75,-.104,FZ+.0302],[.65,-.104,FZ+.0302]],'TEX:cards',[0,-.5,1],[[u0,v1],[u1,v1],[u1,v1-(v1-v0)*.35],[u0,v1-(v1-v0)*.35]])
 box(out,.60,.80,.155,.165,FZ+.06,FZ+.09,NEON)
 # Discard tray on the dealer's right (-X) with a few spent cards.
 box(out,-.79,-.61,-.08,.14,FZ,FZ+.006,SMOKE)
 for x0,x1,y0,y1 in ((-.79,-.78,-.08,.14),(-.62,-.61,-.08,.14),(-.79,-.61,.13,.14),(-.79,-.61,-.08,-.07)):box(out,x0,x1,y0,y1,FZ,FZ+.05,SMOKE)
 box(out,-.75,-.65,-.035,.095,FZ+.006,FZ+.022,CARD_EDGE)
 oriented(out,[[-.75,-.035,FZ+.0222],[-.65,-.035,FZ+.0222],[-.65,.095,FZ+.0222],[-.75,.095,FZ+.0222]],'TEX:cards',[0,0,1],[[u0,v1],[u1,v1],[u1,v0],[u0,v0]])
 # Chip rack in front of the dealer: six channels of chip rolls.
 box(out,-.33,.33,-.005,.135,FZ,FZ+.012,METAL)
 for x0 in (-.33,.32):box(out,x0,x0+.01,-.005,.135,FZ,FZ+.045,METAL)
 for k,(_,_,color,_) in enumerate(reversed(DENOMS)):
  roll=[];g.lathe(roll,[(0,-.06),(.027,-.06),(.027,.06),(0,.06)],color,24)
  x=-.275+k*.11
  for f in roll:
   for key in ('a','b','c'):
    a,b,c=f[key];f[key]=[a+x,-c+.065,b+FZ+.03]
  out.extend(roll)
 return out

def models():
 result={'blackjack_table':table()}
 for s in SUITS:
  for r in RANKS:result['bj_card_'+(r+s).lower()]=card_faces(card_cell(r+s),BACK_CELL)
 result['bj_card_back']=card_faces(BACK_CELL,BACK_CELL)
 result['bj_card_turn']=turned_card()
 for i,(denom,most,_,_) in enumerate(DENOMS):
  for n in range(1,most+1):result[f'bj_chips_{denom}_{n}']=chip_stack(i,n)
 return result

# --- Original artwork -----------------------------------------------------------
def font(size,regular=False):return ImageFont.truetype(str(FONT_REGULAR if regular else FONT),size)
def rgb(c):return tuple(int(c[i:i+2],16) for i in (1,3,5))+(255,)
SUIT_GLYPH={'S':'\u2660','H':'\u2665','D':'\u2666','C':'\u2663'}
RED,INK=(186,22,40,255),(21,22,26,255)
def glyph(text,size,fill,regular=False):
 f=font(size,regular);box=f.getbbox(text);im=Image.new('RGBA',(box[2]-box[0]+4,box[3]-box[1]+4));ImageDraw.Draw(im).text((2-box[0],2-box[1]),text,font=f,fill=fill);return im
def paste_center(im,piece,x,y,rotate=0):
 if rotate:piece=piece.rotate(rotate,resample=Image.Resampling.BICUBIC,expand=True)
 im.alpha_composite(piece,(round(x-piece.width/2),round(y-piece.height/2)))
PIPS={2:[(.5,.2),(.5,.8)],3:[(.5,.2),(.5,.5),(.5,.8)],4:[(.3,.2),(.7,.2),(.3,.8),(.7,.8)],
 5:[(.3,.2),(.7,.2),(.5,.5),(.3,.8),(.7,.8)],6:[(.3,.2),(.7,.2),(.3,.5),(.7,.5),(.3,.8),(.7,.8)],
 7:[(.3,.2),(.7,.2),(.5,.35),(.3,.5),(.7,.5),(.3,.8),(.7,.8)],8:[(.3,.2),(.7,.2),(.5,.35),(.3,.5),(.7,.5),(.5,.65),(.3,.8),(.7,.8)],
 9:[(.3,.2),(.7,.2),(.3,.4),(.7,.4),(.5,.5),(.3,.6),(.7,.6),(.3,.8),(.7,.8)],
 10:[(.3,.2),(.7,.2),(.5,.3),(.3,.4),(.7,.4),(.3,.6),(.7,.6),(.5,.7),(.3,.8),(.7,.8)]}
def card_face(code,S=4):
 w,h=CELL_W*S,CELL_H*S;im=Image.new('RGBA',(w,h),(244,241,232,255));d=ImageDraw.Draw(im)
 rank,suit=code[0],code[1];color=RED if suit in 'HD' else INK;label='10' if rank=='T' else rank
 d.rectangle((3*S,3*S,w-3*S,h-3*S),outline=(196,190,176,255),width=S)
 corner=glyph(label,22*S if label!='10' else 19*S,color);pip=glyph(SUIT_GLYPH[suit],17*S,color,True)
 for flip in (False,True):
  layer=Image.new('RGBA',(w,h));paste_center(layer,corner,18*S,20*S);paste_center(layer,pip,18*S,42*S)
  if flip:layer=layer.rotate(180)
  im.alpha_composite(layer)
 if rank in '23456789T':
  n=10 if rank=='T' else int(rank);big=glyph(SUIT_GLYPH[suit],(30 if n<7 else 24)*S,color,True)
  for x,y in PIPS[n]:
   cx,cy=w*(.18+.64*x),h*(.12+.76*y);paste_center(im,big,cx,cy,180 if y>.55 else 0)
 elif rank=='A':
  paste_center(im,glyph(SUIT_GLYPH[suit],86*S,color,True),w/2,h/2)
  d.ellipse((w/2-58*S,h/2-58*S,w/2+58*S,h/2+58*S),outline=(22,194,212,255),width=2*S)
 else:
  # Original court cards: a neon-trimmed panel, a geometric crest and the rank.
  accent={'J':(22,194,212,255),'Q':(216,48,122,255),'K':(217,144,30,255)}[rank]
  x0,y0,x1,y1=34*S,40*S,w-34*S,h-40*S
  d.rectangle((x0,y0,x1,y1),fill=(30,33,44,255),outline=accent,width=3*S)
  cx=(x0+x1)/2
  crest={'J':[(cx-28*S,y0+38*S),(cx,y0+12*S),(cx+28*S,y0+38*S),(cx,y0+28*S)],
         'Q':[(cx-28*S,y0+38*S),(cx-17*S,y0+14*S),(cx,y0+28*S),(cx+17*S,y0+14*S),(cx+28*S,y0+38*S)],
         'K':[(cx-30*S,y0+38*S),(cx-30*S,y0+14*S),(cx-13*S,y0+27*S),(cx,y0+9*S),(cx+13*S,y0+27*S),(cx+30*S,y0+14*S),(cx+30*S,y0+38*S)]}[rank]
  d.polygon(crest,fill=accent)
  paste_center(im,glyph(label,44*S,(244,241,232,255)),cx,(y0+y1)/2+4*S)
  suit_small=glyph(SUIT_GLYPH[suit],18*S,RED if suit in 'HD' else (244,241,232,255),True)
  paste_center(im,suit_small,cx,y1-14*S)
  for i in range(4):d.line((x0+5*S,y1-6*S-i*4*S,x0+13*S+i*4*S,y1-6*S),fill=accent,width=S)
 return im.resize((CELL_W,CELL_H),Image.Resampling.LANCZOS)
def card_back(S=4):
 w,h=CELL_W*S,CELL_H*S;im=Image.new('RGBA',(w,h),(18,26,51,255));d=ImageDraw.Draw(im)
 d.rectangle((5*S,5*S,w-5*S,h-5*S),outline=(216,48,122,255),width=3*S)
 step=14*S
 for x in range(-h,w+h,step):
  d.line((x,10*S,x+h,h+10*S),fill=(24,92,118,255),width=S);d.line((x,h-10*S,x+h,-10*S),fill=(24,92,118,255),width=S)
 d.rectangle((5*S,5*S,w-5*S,h-5*S),outline=(216,48,122,255),width=3*S)
 cx,cy=w/2,h/2;hexagon=[(cx+34*S*math.cos(math.radians(60*i+30)),cy+34*S*math.sin(math.radians(60*i+30))) for i in range(6)]
 d.polygon(hexagon,fill=(18,26,51,255),outline=(216,48,122,255),width=3*S)
 inner=[(cx+20*S*math.cos(math.radians(60*i)),cy+20*S*math.sin(math.radians(60*i))) for i in range(6)]
 d.polygon(inner,fill=(22,194,212,255))
 # Frame the lattice inside the border so the card edge stays clean.
 frame=Image.new('RGBA',(w,h),(0,0,0,0));fd=ImageDraw.Draw(frame)
 fd.rectangle((0,0,w,5*S),fill=(18,26,51,255));fd.rectangle((0,h-5*S,w,h),fill=(18,26,51,255));fd.rectangle((0,0,5*S,h),fill=(18,26,51,255));fd.rectangle((w-5*S,0,w,h),fill=(18,26,51,255))
 im.alpha_composite(frame)
 return im.resize((CELL_W,CELL_H),Image.Resampling.LANCZOS)
def card_atlas():
 im=Image.new('RGBA',(ATLAS_W,ATLAS_H),(18,26,51,255))
 for code in [r+s for s in SUITS for r in RANKS]:
  col,row=card_cell(code);im.alpha_composite(card_face(code),(col*CELL_W,row*CELL_H))
 im.alpha_composite(card_back(),(BACK_CELL[0]*CELL_W,BACK_CELL[1]*CELL_H))
 return im
def chip_atlas():
 im=Image.new('RGBA',(512,512),(30,30,30,255));d=ImageDraw.Draw(im)
 for i,(denom,_,color,stripe) in enumerate(DENOMS):
  col,row=i%3,i//3;cx,cy=col*CHIP_CELL+85,row*CHIP_CELL+85;r=82
  d.ellipse((cx-r,cy-r,cx+r,cy+r),fill=rgb(color))
  for k in range(8):
   a=math.radians(k*45+22.5);pts=[]
   for da,rr in ((-.16,r+2),(.16,r+2),(.16,r-16),(-.16,r-16)):pts.append((cx+rr*math.cos(a+da),cy+rr*math.sin(a+da)))
   d.polygon(pts,fill=rgb(stripe))
  d.ellipse((cx-56,cy-56,cx+56,cy+56),fill=(240,236,226,255),outline=rgb(color if denom!=1 else stripe),width=4)
  label='1K' if denom==1000 else str(denom);size=46 if len(label)<3 else 36
  text=rgb(stripe) if denom==1 else rgb(color) if denom!=100 else (26,26,30,255)
  paste_center(im,glyph(label,size,text),cx,cy)
 return im
def felt():
 """Felt print at 1 px/mm over x -1.04..1.04, y 0.16..-1.04, then resized."""
 W,H=2080,1200;rng=random.Random(7721);base_color=(14,62,54)
 noise=Image.effect_noise((W//4,H//4),18).resize((W,H),Image.Resampling.BICUBIC)
 im=Image.new('RGBA',(W,H),base_color+(255,))
 shade=Image.merge('RGBA',[noise.point(lambda v:max(0,min(255,base_color[0]+(v-128)//10))),noise.point(lambda v:max(0,min(255,base_color[1]+(v-128)//8))),noise.point(lambda v:max(0,min(255,base_color[2]+(v-128)//9))),Image.new('L',(W,H),255)])
 im=shade;d=ImageDraw.Draw(im)
 def px(x,y):return ((x+1.04)*1000,(.16-y)*1000)
 GOLD,CYAN=(212,170,92,255),(70,214,224,255)
 def ring(x,y,r,color,width):cx,cy=px(x,y);d.ellipse((cx-r*1000,cy-r*1000,cx+r*1000,cy+r*1000),outline=color,width=width)
 # Outer pinstripe along the rail, and the dealer zone line.
 for r,width in ((.965,5),(.945,2)):
  cx,cy=px(0,0);d.arc((cx-r*1000,cy-r*1000,cx+r*1000,cy+r*1000),0,180,fill=GOLD,width=width)
 for seat,angle in enumerate(SEAT_ANGLES):
  a=math.radians(angle);ux,uy=math.sin(a),-math.cos(a)
  ring(SEAT_R*ux,SEAT_R*uy,.078,GOLD,6);ring(SEAT_R*ux,SEAT_R*uy,.064,GOLD,2)
  label=glyph(str(seat+1),34,GOLD);x,y=px((SEAT_R+.115)*ux,(SEAT_R+.115)*uy);paste_center(im,label,x,y,angle)
  # Card box: a thin outline where the hand is dealt.
  corners=[]
  for sx,sy in ((-1,-1),(1,-1),(1,1),(-1,1)):
   lx,ly=sx*(CARD_W/2+.012)+.09*(sx>0),sy*(CARD_H/2+.012)
   corners.append(px(CARD_R*ux+lx*math.cos(a)-ly*math.sin(a),CARD_R*uy+lx*math.sin(a)+ly*math.cos(a)))
  d.line(corners+corners[:1],fill=(52,150,150,255),width=2)
 def arc_text(text,r,size,color,center=270):
  pieces=[glyph(ch,size,color) if ch!=' ' else None for ch in text]
  widths=[(p.width-4 if p else size*.35)/1000 for p in pieces];total=sum(widths)
  pos=-total/2
  for p,wd in zip(pieces,widths):
   a=math.radians(center)+(pos+wd/2)/r;pos+=wd
   if p:
    x,y=px(r*math.cos(a),r*math.sin(a));paste_center(im,p,x,y,math.degrees(a)-270)
 arc_text('BLACKJACK PAYS 3 TO 2',.40,40,GOLD)
 arc_text('DEALER STANDS ON SOFT 17',.675,30,CYAN)
 limits=glyph('TABLE LIMITS  5 \u2013 5,000',24,(200,200,190,255),True);x,y=px(0,-.135);paste_center(im,limits,x,y)
 for i in range(2):
  x,y=px(0,-.08+i*0);d.line((x-260,y,x+260,y),fill=GOLD,width=2)
 return im.resize((2048,1024),Image.Resampling.LANCZOS)
def artwork():return {'bj_felt':felt(),'bj_cards':card_atlas(),'bj_chips':chip_atlas()}

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
def material(color):
 if color in TEX:
  result=ORIGINAL_MATERIAL(base.WHITE)
  result['values'][0]['BaseColor']=base.ref(DEPOT+'\\textures\\'+TEX[color]+'.xbm');result['values'][1]['BaseColorScale'].update(X=1,Y=1,Z=1)
  result['values'][2]['RoughnessScale']={'TEX:felt':.95,'TEX:cards':.6,'TEX:chips':.5}[color]
  return result
 if color in PLAIN:
  rough,metal=PLAIN[color];result=ORIGINAL_MATERIAL(base.WHITE);result['values'][0]['BaseColor']=base.ref('engine\\textures\\editor\\white.xbm')
  c=[linear(int(color[i:i+2],16)) for i in (1,3,5)];result['values'][1]['BaseColorScale'].update(X=c[0],Y=c[1],Z=c[2]);result['values'][2]['RoughnessScale']=rough;result['values'][3]['MetalnessScale']=metal
  return result
 return ORIGINAL_MATERIAL(color)
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

EXPECTED_MODELS=1+52+2+sum(most for _,most,_,_ in DENOMS)
EXPECTED_TEXTURES=4+len(TEX)
def verify(work,manifest):
 """Independent cooked-file, namespace, package-index, atlas and authored-pose checks."""
 spec=importlib.util.spec_from_file_location('archive_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
 archive=work/'archive';verified=work/'verified';packed=(work/'packed/archive.archive').read_bytes()
 entries=checks.archive_entries(packed);files=manifest['files']
 assert len(manifest['models'])==EXPECTED_MODELS and len(manifest['textures'])==EXPECTED_TEXTURES
 assert len(entries)==len(files)==EXPECTED_MODELS*2+EXPECTED_TEXTURES
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
 for denom,most,_,_ in DENOMS:
  for n in range(1,most+1):assert abs(by_name[f'bj_chips_{denom}_{n}']['bounds']['max'][2]-n*CHIP_T)<1e-6
 t=by_name['blackjack_table']['bounds'];assert abs(t['min'][2])<1e-9 and FZ<t['max'][2]<FZ+.1 and abs(t['max'][0]-RAIL_R)<1e-6
 with zipfile.ZipFile(RESOURCE/'dist/open77_casino_blackjack.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_casino_blackjack.archive']
  assert z.read(z.namelist()[0])==packed
 print(f'VERIFIED: {EXPECTED_MODELS} native props, {EXPECTED_TEXTURES} opaque mipmapped textures, {len(files)} exact RDAR entries, geometry/atlas UVs/poses/package hashes',flush=True)

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path('/tmp/casino-blackjack-props/build'));p.add_argument('--verify-only',action='store_true');p.add_argument('--art-only',action='store_true',help='write sources/*.png and stop');a=p.parse_args();work=a.work
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 if a.art_only:
  (RESOURCE/'sources').mkdir(parents=True,exist_ok=True)
  for name,image in artwork().items():image.save(RESOURCE/'sources'/(name+'.png'),optimize=True)
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
 textures=base.wood_textures(tex);texture_template=json.loads((tex/'wood_ivory.xbm.json').read_text())
 for name,image in artwork().items():textures.append(encode_texture(tex,name,image,texture_template))
 geometry=models();records=[]
 for i,(name,faces) in enumerate(geometry.items()):
  for f in faces:
   p1,p2,p3=(f[k] for k in ('a','b','c'));normal=base.cross([p2[j]-p1[j] for j in range(3)],[p3[j]-p1[j] for j in range(3)])
   assert sum(x*x for x in normal)>1e-22,(name,f)
  colors=glb(raw/(name+'.mesh.glb'),faces)
  (schemas/(name+'.mesh.json')).write_text(json.dumps(base.mesh_json(donor,colors,faces)))
  (schemas/(name+'.ent.json')).write_text(json.dumps(base.entity_json(template,name,i)))
  records.append({'name':name,'mesh':DEPOT+'\\'+name+'.mesh','entity':DEPOT+'\\'+name+'.ent','triangles':len(faces),'materials':colors,'bounds':{'min':[min(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)],'max':[max(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)]}})
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');(target/'textures').mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target);cli('convert','deserialize',tex,'-o',target/'textures');cli('import',*[raw/(name+'.mesh.glb') for name in geometry],'-o',target,'--keep',imports=len(geometry))
 verified=work/'verified';verified.mkdir(exist_ok=True);cli('convert','serialize',archive,'-o',verified);packed=work/'packed';packed.mkdir(exist_ok=True);cli('pack',archive,'-o',packed)
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_casino_blackjack.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_casino_blackjack.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 layout={'feltZ':FZ,'feltRadius':FELT_R,'railRadius':RAIL_R,'seatAngles':dict(zip(['white','black','white2','black2'],SEAT_ANGLES)),'seatRadius':SEAT_R,'cardRadius':CARD_R,
  'card':{'width':CARD_W,'height':CARD_H,'thickness':CARD_T},'chip':{'radius':CHIP_R,'thickness':CHIP_T},'chipStacks':{str(d):most for d,most,_,_ in DENOMS}}
 manifest={'version':'1.0.0','namespace':DEPOT,'models':records,'textures':textures,'files':files,'layout':layout,'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=1)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
