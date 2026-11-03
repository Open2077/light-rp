#!/usr/bin/env python3
"""Cook the original Fortune Wheel (big-six money wheel) native props.

The prop API only moves props and turns them about the vertical axis, so the
vertical rotor is authored as pose meshes: its face has two-fold symmetry, so
27 rotor poses (one per segment of half a turn) cover all 54 rest positions.
Two radial-blur discs stand in at speed, the flapper has four deflection
poses, the two 40x segments get their own orbiting medallions, and chip stacks
come in six heights. Coordinates are board-local unscaled metres and must
match client/core/casino_fortune.lua.

Uses the existing native board-prop cooker as a read-only schema/tool library.
Only this resource and --work receive outputs. Requires Pillow, .NET and
WolvenKit from the inspected local lab.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,struct,subprocess,zipfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageChops
ROOT=Path(__file__).resolve().parents[1]
RESOURCE=ROOT/'resources/assets/models/open77_casino_fortune'
DEPOT='open77\\assets\\op77_lightrp\\casino_fortune'
LAB=ROOT.parent/'dop-tests'
FONT=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()

# Layout shared with the Lua client (unscaled metres, -Y is the player side).
SEGMENTS,POSES=54,27
STEP=360/SEGMENTS
HALF=['S','1','2','1','5','1','2','1','10','1','2','5','1','20','1','2','1','5','2','1','10','1','2','5','1','2','1']
WY,WZ=.10,2.15          # rotor face plane and wheel centre
R_FACE,R_PEG,R_LIP=.66,.625,.665
PEG_LEN,PEG_R=.06,.009
FLAP_PIVOT=(0,.042,WZ+.74)
FLAP_LEN=.15
FLAP_ANGLES=[-6,0,4.5,9]  # overshoot, rest, half kick, full kick (tip toward +X)
MEDALLION_R,MEDAL_RADIUS=.42,.026
FELT=(-.72,.72,-.96,-.44,1.252)  # x0,x1,y0,y1,z
SPOT_X=[-.6+.2*i for i in range(7)];SPOT_Y,PAYOUT_Y=-.68,-.84
SPOTS=['1','2','5','10','20','eye','star']
CHIP_COUNTS=[1,2,3,5,8,12]

# Sentinel colours select textured or flat materials (vertex colours stay white).
FACE,BLUR,FELT_TEX,MARQUEE,MEDALS='#FACE0001','#B1B20001','#FE170001','#3A700001','#3E0A1001'
BLACK=base.BLACK;WOOD=base.WOOD_FRAME
CHROME,BRASS,BULB,LEATHER,DARK='#C9CED6FF','#C79A3BFF','#FFE7A0FF','#8E1B22FF','#17171CFF'
CHIP_COLORS=['#C8282EFF','#1F4FB8FF','#1E8A4AFF','#16161AFF','#7A2FC0FF','#E0A21AFF']
INLAY='#F4F1E8FF'
SEG_COLORS={'1':(242,194,48),'2':(47,184,216),'5':(224,69,123),'10':(125,217,87),'20':(155,92,255),'S':(22,22,28)}
GOLD=(214,170,64)

def layout(i):
 s=HALF[i%27]
 return ('eye' if i==0 else 'star') if s=='S' else s

# ---------------------------------------------------------------- geometry
def sub(a,b):return [a[i]-b[i] for i in range(3)]
def tri(out,a,b,c,color,uv=None,facing=None):
 a,b,c=list(a),list(b),list(c)
 if facing is not None:
  n=base.cross(sub(b,a),sub(c,a))
  if sum(n[i]*facing[i] for i in range(3))<0:
   b,c=c,b
   if uv is not None:uv=[uv[0],uv[2],uv[1]]
 f={'a':a,'b':b,'c':c,'color':color}
 if uv is not None:f['uv']=[list(x) for x in uv]
 out.append(f)

def ylathe(out,profile,color,sides=96,cx=0,cz=0):
 """Lathe about the Y axis: profile (r,h) with h=-y (front is +h), back to front."""
 local=[];g.lathe(local,profile,color,sides)
 for f in local:
  for k in ('a','b','c'):x,y,z=f[k];f[k]=[cx+x,-z,cz+y]
 out.extend(local)

def ball(out,center,r,color,sides=8,rings=4):
 profile=[(0 if i in (0,rings) else r*math.sin(i*math.pi/rings),center[2]-r*math.cos(i*math.pi/rings)) for i in range(rings+1)]
 local=[];
 for (r0,z0),(r1,z1) in zip(profile,profile[1:]):
  for i in range(sides):
   a,b=i*math.tau/sides,(i+1)*math.tau/sides
   p=[r0*math.cos(a),r0*math.sin(a),z0];q=[r0*math.cos(b),r0*math.sin(b),z0]
   s=[r1*math.cos(a),r1*math.sin(a),z1];t=[r1*math.cos(b),r1*math.sin(b),z1]
   if r0==0:g.tri(local,p,t,s,color)
   elif r1==0:g.tri(local,p,q,t,color)
   else:g.quad(local,p,q,t,s,color)
 for f in local:
  # Fresh lists: the lathe shares vertex lists between a quad's two triangles.
  for k in ('a','b','c'):f[k]=[f[k][0]+center[0],f[k][1]+center[1],f[k][2]]
 out.extend(local)

def polar(r,a,y=0):
 """Point on the vertical wheel plane: `a` degrees clockwise from the top seen from the front."""
 t=math.radians(a);return [r*math.sin(t),y,r*math.cos(t)]

def turn(faces,degrees,origin=(0,0,0)):
 """Turn geometry clockwise (seen from the front) about the Y axis through origin."""
 d=math.radians(degrees);c,s=math.cos(d),math.sin(d);out=[]
 for f in faces:
  n=dict(f)
  for k in ('a','b','c'):
   x,y,z=f[k][0]-origin[0],f[k][1],f[k][2]-origin[2]
   n[k]=[origin[0]+x*c+z*s,y,origin[2]-x*s+z*c]
  out.append(n)
 return out

def face_uv(p,segment):
 """Half-texture UV: segments 27..53 reuse 0..26 through the half-turn symmetry."""
 rho=math.hypot(p[0],p[2]);a=math.degrees(math.atan2(p[0],p[2]))+STEP/2
 if segment>=27:a-=180
 a=math.radians(a);x,z=rho*math.sin(a),rho*math.cos(a)
 return [max(0,min(1,x/R_FACE)),.5-z/(2*R_FACE)]

def rotor_base():
 out=[];front=(0,-1,0)
 for i in range(SEGMENTS):
  a0,a1=(i-.5)*STEP,(i+.5)*STEP
  pts=[[0,0,0],polar(R_FACE,a0),polar(R_FACE,a1)]
  tri(out,*pts,FACE,uv=[face_uv(p,i) for p in pts],facing=front)
  # Edge band (hidden behind the drum lip) closes the rotor silhouette.
  e=[polar(R_FACE,a0),polar(R_FACE,a1),polar(R_FACE,a1,.025),polar(R_FACE,a0,.025)]
  n=polar(1,i*STEP)
  tri(out,e[0],e[1],e[2],DARK,facing=n);tri(out,e[0],e[2],e[3],DARK,facing=n)
  # Pegs on the segment boundaries, standing out of the face toward the player.
  c=polar(R_PEG,a1);ring=[]
  for k in range(6):
   t=k*math.tau/6;ring.append((c[0]+PEG_R*math.cos(t),c[2]+PEG_R*math.sin(t)))
  for k in range(6):
   (x0,z0),(x1,z1)=ring[k],ring[(k+1)%6];mid=[(x0+x1)/2-c[0],0,(z0+z1)/2-c[2]]
   q=[[x0,0,z0],[x1,0,z1],[x1,-PEG_LEN,z1],[x0,-PEG_LEN,z0]]
   tri(out,q[0],q[1],q[2],CHROME,facing=mid);tri(out,q[0],q[2],q[3],CHROME,facing=mid)
  for k in range(1,5):
   tri(out,[ring[0][0],-PEG_LEN,ring[0][1]],[ring[k][0],-PEG_LEN,ring[k][1]],[ring[k+1][0],-PEG_LEN,ring[k+1][1]],CHROME,facing=front)
 return out

def blur_disc():
 out=[];front=(0,-1,0)
 for i in range(SEGMENTS):
  a0,a1=(i-.5)*STEP,(i+.5)*STEP
  pts=[[0,0,0],polar(R_FACE,a0),polar(R_FACE,a1)]
  tri(out,*pts,BLUR,uv=[[.5+p[0]/(2*R_FACE),.5-p[2]/(2*R_FACE)] for p in pts],facing=front)
  e=[polar(R_FACE,a0),polar(R_FACE,a1),polar(R_FACE,a1,.025),polar(R_FACE,a0,.025)];n=polar(1,i*STEP)
  tri(out,e[0],e[1],e[2],DARK,facing=n);tri(out,e[0],e[2],e[3],DARK,facing=n)
 return out

def medallion(offset):
 out=[];n=20;front=(0,-1,0);r=MEDAL_RADIUS
 for k in range(n):
  a0,a1=k*360/n,(k+1)*360/n
  pts=[[0,-.006,0],polar(r,a0,-.006),polar(r,a1,-.006)]
  tri(out,*pts,MEDALS,uv=[[offset+.25*p[0]/r,.5-.5*p[2]/r] for p in pts],facing=front)
  e=[polar(r,a0,-.006),polar(r,a1,-.006),polar(r,a1,0),polar(r,a0,0)];nn=polar(1,(a0+a1)/2)
  tri(out,e[0],e[1],e[2],BRASS,facing=nn);tri(out,e[0],e[2],e[3],BRASS,facing=nn)
 return out

def flapper(angle):
 out=[]
 # Tapered leather tongue hanging from the hinge (origin), plus a chrome clamp and pin.
 poly=[(-.016,.0),(.016,.0),(.010,-FLAP_LEN+.008),(.006,-FLAP_LEN),(-.006,-FLAP_LEN),(-.010,-FLAP_LEN+.008)]
 for y,facing in ((-.006,(0,-1,0)),(.006,(0,1,0))):
  for k in range(1,len(poly)-1):
   tri(out,[poly[0][0],y,poly[0][1]],[poly[k][0],y,poly[k][1]],[poly[k+1][0],y,poly[k+1][1]],LEATHER,facing=facing)
 cx=sum(p[0] for p in poly)/len(poly);cz=sum(p[1] for p in poly)/len(poly)
 for k in range(len(poly)):
  (x0,z0),(x1,z1)=poly[k],poly[(k+1)%len(poly)]
  q=[[x0,-.006,z0],[x1,-.006,z1],[x1,.006,z1],[x0,.006,z0]];mid=[(x0+x1)/2-cx,0,(z0+z1)/2-cz]
  tri(out,q[0],q[1],q[2],LEATHER,facing=mid);tri(out,q[0],q[2],q[3],LEATHER,facing=mid)
 g.box(out,0,0,.004,.042,.018,.026,CHROME)
 ylathe(out,[(0,-.012),(.006,-.012),(.006,.012),(0,.012)],BRASS,12,0,.006)
 return turn(out,-angle)  # positive angle: tip swings toward +X

def chips(count):
 out=[]
 for k in range(count):
  z=k*.0082;c=CHIP_COLORS[k%len(CHIP_COLORS)]
  g.lathe(out,[(0,z),(.033,z),(.035,z+.002),(.035,z+.006),(.033,z+.008),(0,z+.008)],c,24)
  # White inlay ring on each chip's top and a few edge spots.
  g.lathe(out,[(.026,z+.0083),(.020,z+.0083)],INLAY,24)
 return out

def stand():
 out=[]
 x0,x1,y0,y1,fz=FELT
 # Floor plinth joining the betting table and the wheel pedestal.
 g.box(out,0,-.40,.03,1.74,1.50,.06,BLACK)
 # Betting table: dark wood cabinet, lacquered top, brass rail, felt layout.
 g.box(out,0,-.70,.63,1.56,.62,1.14,WOOD)
 g.box(out,0,-.70,1.225,1.64,.72,.05,BLACK)
 for y in (-1.055,-.345):g.box(out,0,y,1.258,1.64,.016,.014,BRASS)
 for x in (-.815,.815):g.box(out,x,-.70,1.258,.016,.72,.014,BRASS)
 g.box(out,0,-1.012,.95,1.40,.012,.03,CHIP_COLORS[4]);g.box(out,0,-1.012,.20,1.40,.012,.02,BRASS)
 pts=[[x0,y0,fz],[x1,y0,fz],[x1,y1,fz],[x0,y1,fz]]
 uv=[[(p[0]-x0)/(x1-x0),(y1-p[1])/(y1-y0)] for p in pts]
 tri(out,pts[0],pts[1],pts[2],FELT_TEX,uv=[uv[0],uv[1],uv[2]],facing=(0,0,1));tri(out,pts[0],pts[2],pts[3],FELT_TEX,uv=[uv[0],uv[2],uv[3]],facing=(0,0,1))
 # Wheel pedestal behind the table.
 g.box(out,0,.14,.11,.80,.50,.10,BLACK)
 g.box(out,0,.14,.80,.30,.22,1.40,BLACK)
 for x in (-.15,.15):g.box(out,x,.03,.80,.012,.012,1.30,BRASS)
 # Drum: back panel, outer wall, front lip with an inward flange, inner wall.
 ylathe(out,[(0,-.27),(.80,-.27),(.80,-.05),(R_LIP,-.05),(R_LIP,-.07),(.70,-.07),(.70,-.25),(0,-.25)],BLACK,108,0,WZ)
 ylathe(out,[(.742,-.0495),(.722,-.0495)],BRASS,108,0,WZ)
 ylathe(out,[(.80,-.0495),(.79,-.0495)],BRASS,108,0,WZ)
 # Marquee bulbs around the lip (the top is left clear for the flapper bracket).
 for k in range(40):
  a=k*9+4.5
  if a<14 or a>346:continue
  p=polar(.765,a);ball(out,(p[0],.040,WZ+p[2]),.012,BULB)
 # Static chrome hub cap: rotationally symmetric, so it never needs a pose.
 ylathe(out,[(0,-.098),(.11,-.098),(.105,-.085),(.08,-.062),(.045,-.047),(0,-.042)],CHROME,48,0,WZ)
 ylathe(out,[(.125,-.0985),(.11,-.0985)],BRASS,48,0,WZ)
 # Flapper bracket at twelve o'clock, holding the hinge pin.
 g.box(out,0,.032,WZ+.79,.09,.05,.09,CHROME)
 g.box(out,0,.06,WZ+.86,.05,.03,.08,CHROME)
 # Marquee sign above the drum.
 g.box(out,0,.13,WZ+.95,1.08,.08,.26,BLACK)
 g.box(out,0,.088,WZ+.95,1.10,.006,.28,BRASS)
 mx0,mx1,mz0,mz1=-.5,.5,WZ+.835,WZ+1.065
 pts=[[mx0,.084,mz0],[mx1,.084,mz0],[mx1,.084,mz1],[mx0,.084,mz1]]
 uv=[[(p[0]-mx0)/(mx1-mx0),(mz1-p[2])/(mz1-mz0)] for p in pts]
 tri(out,pts[0],pts[1],pts[2],MARQUEE,uv=[uv[0],uv[1],uv[2]],facing=(0,-1,0));tri(out,pts[0],pts[2],pts[3],MARQUEE,uv=[uv[0],uv[2],uv[3]],facing=(0,-1,0))
 return out

def models():
 result={'fortune_stand':stand()}
 rotor=rotor_base()
 for p in range(POSES):result[f'fortune_disc_{p:02d}']=turn(rotor,p*STEP)
 disc=blur_disc();result['fortune_blur_0']=disc;result['fortune_blur_1']=turn(disc,1.5*STEP)
 for i,a in enumerate(FLAP_ANGLES):result[f'fortune_flapper_{i}']=flapper(a)
 result['fortune_eye']=medallion(.25);result['fortune_star']=medallion(.75)
 for i,n in enumerate(CHIP_COUNTS):result[f'fortune_chips_{i+1}']=chips(n)
 return result

# ---------------------------------------------------------------- artwork
def font(size):return ImageFont.truetype(str(FONT),size)
def rgba(c,a=255):return tuple(c)+(a,)
def shade(c,k):return tuple(max(0,min(255,round(v*k))) for v in c)

def draw_segment(im,cx,cy,rpx,label,a0):
 """One segment spanning [a0,a0+STEP] degrees clockwise from the top."""
 d=ImageDraw.Draw(im);s=rpx/R_FACE
 def box(r):return (cx-r*s,cy-r*s,cx+r*s,cy+r*s)
 col=SEG_COLORS['S' if label in ('eye','star') else label]
 start,end=a0-90,a0+STEP-90
 d.pieslice(box(.60),start,end,fill=rgba(col))
 d.pieslice(box(.40),start,end,fill=rgba(shade(col,.62)))
 d.pieslice(box(.25),start,end,fill=rgba(shade(col,.40)))
 mid=a0+STEP/2
 special=label in ('eye','star')
 text='40' if special else label
 ink=(16,16,20) if label in ('1','2','10') else (250,246,236)
 if special:ink=GOLD
 size=round((.050 if len(text)==1 else .043)*s)
 for r,word,fs in ((.535,text,size),(.468,'x',round(.030*s))):
  w=round(.12*s);lab=Image.new('RGBA',(w,w));dd=ImageDraw.Draw(lab)
  dd.text((w/2,w/2),word,font=font(fs),anchor='mm',fill=rgba(ink))
  lab=lab.rotate(-mid,resample=Image.Resampling.BICUBIC)
  t=math.radians(mid);x=cx+math.sin(t)*r*s;y=cy-math.cos(t)*r*s
  im.alpha_composite(lab,(round(x-w/2),round(y-w/2)))
 if special:
  # Socket under the orbiting medallion, and a gold frame on the segment.
  t=math.radians(mid);x=cx+math.sin(t)*MEDALLION_R*s;y=cy-math.cos(t)*MEDALLION_R*s;r=(MEDAL_RADIUS+.004)*s
  d.ellipse((x-r,y-r,x+r,y+r),fill=rgba((40,34,20)),outline=rgba(GOLD),width=max(2,round(.003*s)))

def draw_frame(im,cx,cy,rpx,angles):
 d=ImageDraw.Draw(im);s=rpx/R_FACE;lw=max(2,round(.0035*s))
 for a in angles:
  t=math.radians(a)
  d.line((cx+math.sin(t)*.13*s,cy-math.cos(t)*.13*s,cx+math.sin(t)*.60*s,cy-math.cos(t)*.60*s),fill=rgba(GOLD),width=lw)
 for r in (.60,.40,.13):d.ellipse((cx-r*s,cy-r*s,cx+r*s,cy+r*s),outline=rgba(GOLD),width=lw)

def face_art(full=False):
 """full=False: the 1024x2048 half texture (segments 0..26, frame turned half a step)."""
 k=2
 if full:
  W=H=1024*k;cx=cy=W/2;rpx=W/2
  im=Image.new('RGBA',(W,H),(18,18,22,255));d=ImageDraw.Draw(im)
  d.ellipse((0,0,W-1,H-1),fill=(18,18,22,255))
  for i in range(SEGMENTS):draw_segment(im,cx,cy,rpx,layout(i),(i-.5)*STEP)
  draw_frame(im,cx,cy,rpx,[(i-.5)*STEP for i in range(SEGMENTS)])
 else:
  W,H=1024*k,2048*k;cx,cy,rpx=0,H/2,W
  im=Image.new('RGBA',(W,H),(18,18,22,255))
  for i in range(27):draw_segment(im,cx,cy,rpx,layout(i),i*STEP)
  draw_frame(im,cx,cy,rpx,[i*STEP for i in range(28)])
 d=ImageDraw.Draw(im);s=rpx/R_FACE
 d.ellipse((cx-.125*s,cy-.125*s,cx+.125*s,cy+.125*s),fill=(30,30,36,255))
 return im.resize((W//k,H//k),Image.Resampling.LANCZOS)

def blur_art():
 src=face_art(True);W=src.width;c=(W/2,W/2);acc=None;n=0
 for k in range(-10,11):
  layer=src.rotate(k*1.25,resample=Image.Resampling.BILINEAR,center=c)
  acc=layer if acc is None else Image.blend(acc,layer,1/(n+1));n+=1
 d=ImageDraw.Draw(acc);s=(W/2)/R_FACE
 for r,w,col in ((R_PEG,PEG_R*2.2,(150,156,166)),(.60,.004,GOLD),(.40,.004,GOLD)):
  d.ellipse((c[0]-r*s,c[1]-r*s,c[0]+r*s,c[1]+r*s),outline=rgba(col),width=max(2,round(w*s)))
 return acc.resize((512,512),Image.Resampling.LANCZOS)

def eye_star(im,box,kind):
 d=ImageDraw.Draw(im);x0,y0,x1,y1=box;cx,cy=(x0+x1)/2,(y0+y1)/2;r=(x1-x0)/2
 def circ(rr,fill):d.ellipse((cx-rr,cy-rr,cx+rr,cy+rr),fill=rgba(fill))
 if kind=='eye':
  for rr,c in ((1,(12,14,18)),(.92,(63,224,208)),(.78,(10,60,64)),(.64,(63,224,208)),(.50,(170,250,240)),(.36,(10,30,34)),(.18,(63,224,208)),(.08,(240,255,252))):circ(r*rr,c)
 else:
  circ(r,(12,10,16));circ(r*.92,(255,63,180))
  pts=[]
  for k in range(32):
   t=math.radians(k*360/32);rr=r*(.86 if k%2==0 else .40)
   pts.append((cx+math.sin(t)*rr,cy-math.cos(t)*rr))
  d.polygon(pts,fill=rgba((255,214,90)));circ(r*.26,(255,63,180));circ(r*.12,(255,246,220))

def medal_art():
 k=2;im=Image.new('RGBA',(512*k,256*k),(12,12,16,255))
 eye_star(im,(0,0,256*k,256*k),'eye');eye_star(im,(256*k,0,512*k,256*k),'star')
 return im.resize((512,256),Image.Resampling.LANCZOS)

def felt_art():
 x0,x1,y0,y1,_=FELT;k=1000;W,H=round((x1-x0)*k),round((y1-y0)*k)
 im=Image.new('RGBA',(W,H),(26,18,40,255));d=ImageDraw.Draw(im)
 for yy in range(0,H,6):d.line((0,yy,W,yy),fill=(30,21,46,255))
 def px(x,y):return ((x-x0)*k,(y1-y)*k)
 d.rectangle((10,10,W-11,H-11),outline=rgba(GOLD),width=4)
 d.text((W/2,40),'FORTUNE WHEEL  ·  WINNERS PAID MULTIPLIER × STAKE + STAKE',font=font(24),anchor='mm',fill=rgba(GOLD))
 for spot,x in zip(SPOTS,SPOT_X):
  cx,cy=px(x,SPOT_Y);col=SEG_COLORS['S' if spot in ('eye','star') else spot]
  d.rounded_rectangle((cx-92,cy-150,cx+92,cy+190),radius=18,fill=rgba(shade(col,.30)),outline=rgba(col),width=5)
  label='40x' if spot in ('eye','star') else spot+'x'
  d.text((cx,cy-112),label,font=font(46),anchor='mm',fill=rgba(col if spot not in ('eye','star') else GOLD))
  d.ellipse((cx-70,cy-70,cx+70,cy+70),outline=rgba(col),width=6)
  d.ellipse((cx-56,cy-56,cx+56,cy+56),outline=rgba(shade(col,.6)),width=2)
  if spot in ('eye','star'):
   eye_star(im,(cx-44,cy-44,cx+44,cy+44),spot)
   d=ImageDraw.Draw(im)
  pays={'eye':'NEON EYE','star':'STARBURST'}.get(spot,'PAYS %s TO 1'%spot)
  d.text((cx,cy+105),pays,font=font(20),anchor='mm',fill=(235,230,220,255))
  if spot in ('eye','star'):d.text((cx,cy+140),'PAYS 40 TO 1',font=font(18),anchor='mm',fill=(200,190,170,255))
 return im.resize((1024,512),Image.Resampling.LANCZOS)

def marquee_art():
 k=2;W,H=1024*k,256*k;im=Image.new('RGBA',(W,H),(14,10,22,255));d=ImageDraw.Draw(im)
 d.rounded_rectangle((12*k,12*k,W-12*k,H-12*k),radius=30*k,outline=(255,63,180,255),width=6*k)
 d.rounded_rectangle((24*k,24*k,W-24*k,H-24*k),radius=24*k,outline=(63,224,208,255),width=3*k)
 for dx,dy,c in ((4,4,(120,20,90)),(0,0,(255,214,90))):
  d.text((W/2+dx*k,H/2+dy*k-10*k),'FORTUNE WHEEL',font=font(84*k),anchor='mm',fill=rgba(c))
 for x in (70*k,W-70*k):
  pts=[]
  for j in range(10):
   t=math.radians(j*36);rr=(34 if j%2==0 else 14)*k;pts.append((x+math.sin(t)*rr,H/2-math.cos(t)*rr))
  d.polygon(pts,fill=(63,224,208,255))
 d.text((W/2,H-44*k),'SPIN  ·  54 SEGMENTS  ·  UP TO 40 TO 1',font=font(26*k),anchor='mm',fill=(235,230,220,255))
 return im.resize((1024,256),Image.Resampling.LANCZOS)

def artwork():
 return {'fortune_face':face_art(),'fortune_blur':blur_art(),'fortune_felt':felt_art(),'fortune_marquee':marquee_art(),'fortune_medals':medal_art()}

TEXTURED={FACE:('fortune_face',.42),BLUR:('fortune_blur',.5),FELT_TEX:('fortune_felt',.95),MARQUEE:('fortune_marquee',.35),MEDALS:('fortune_medals',.25)}
METAL={CHROME:(.18,.92),BRASS:(.30,.78)}
FLAT={BULB,LEATHER,DARK,INLAY,*CHIP_COLORS}

# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so the cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V=True
def cooked(image):return image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image

def encode_texture(directory,name,image,template):
 # Opaque: composite over black so rotated/blurred edges carry no alpha.
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
def flat(color,texture='engine\\textures\\editor\\white.xbm',rough=.6,metal=0.):
 result=ORIGINAL_MATERIAL(base.WHITE);result['values'][0]['BaseColor']=base.ref(texture)
 c=[int(color[i:i+2],16)/255 for i in (1,3,5)] if texture.startswith('engine') else [1,1,1]
 result['values'][1]['BaseColorScale'].update(X=c[0],Y=c[1],Z=c[2]);result['values'][2]['RoughnessScale']=rough;result['values'][3]['MetalnessScale']=metal
 return result
def material(color):
 if color in TEXTURED:name,rough=TEXTURED[color];return flat(color,DEPOT+'\\textures\\'+name+'.xbm',rough)
 if color in METAL:rough,metal=METAL[color];return flat(color,rough=rough,metal=metal)
 if color in FLAT:return flat(color,rough=.35 if color==LEATHER else .5)
 return ORIGINAL_MATERIAL(color)
base.material=material

def glb(path,faces):
 colors=base.glb(path,faces)
 # Keep the explicit artwork UVs after the shared cooker's planar defaults.
 raw=bytearray(path.read_bytes());json_length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+json_length]);binary=28+json_length;groups={}
 for face in faces:groups.setdefault(face['color'],[]).append(face)
 for mi,group in enumerate(groups.values()):
  accessor=doc['accessors'][doc['meshes'][mi]['primitives'][0]['attributes']['TEXCOORD_0']];view=doc['bufferViews'][accessor['bufferView']];start=binary+view.get('byteOffset',0)+accessor.get('byteOffset',0)
  for i,face in enumerate(group):
   if 'uv' in face:
    for j,uv in enumerate(face['uv']):struct.pack_into('<ff',raw,start+(i*3+j)*8,*uv)
 path.write_bytes(raw);return colors

def check_poses(geometry):
 """Authored-pose invariants the Lua client relies on (before cooking)."""
 def pegs(faces):
  caps=[f for f in faces if f['color']==CHROME and abs(f['a'][1]+PEG_LEN)<1e-9 and abs(f['b'][1]+PEG_LEN)<1e-9 and abs(f['c'][1]+PEG_LEN)<1e-9]
  return caps
 for p in range(POSES):
  faces=geometry[f'fortune_disc_{p:02d}']
  # The textured triangle of segment (-p)%54 straddles the top: its centroid is straight up.
  top=(-p)%SEGMENTS;tris=[f for f in faces if f['color']==FACE]
  assert len(tris)==SEGMENTS
  f=tris[top];cx=(f['a'][0]+f['b'][0]+f['c'][0])/3;cz=(f['a'][2]+f['b'][2]+f['c'][2])/3
  assert abs(cx)<1e-9 and cz>0,(p,cx,cz)
  # Pegs sit half a segment either side of the top, where the flapper hangs.
  xs=sorted(round(sum(v[0] for v in (f['a'],f['b'],f['c']))/3,4) for f in pegs(faces) if sum(v[2] for v in (f['a'],f['b'],f['c']))/3>.6)
  assert any(abs(x-R_PEG*math.sin(math.radians(STEP/2)))<.012 for x in xs) and any(abs(x+R_PEG*math.sin(math.radians(STEP/2)))<.012 for x in xs),(p,xs)
  # Two-fold symmetry: the face at rotation p and p+27 shows the same label at the top.
  assert HALF[top%27]==HALF[(top+27)%27]
 for i,a in enumerate(FLAP_ANGLES):
  tips=[v for f in geometry[f'fortune_flapper_{i}'] if f['color']==LEATHER for v in (f['a'],f['b'],f['c'])]
  low=min(tips,key=lambda v:v[2]);assert abs(low[2]+FLAP_LEN*math.cos(math.radians(a)))<.02
  if a>0:assert low[0]>0
 # The flapper tip reaches into the peg ring, in front of the face.
 assert FLAP_PIVOT[2]-FLAP_LEN<WZ+R_PEG-PEG_R and FLAP_PIVOT[1]-.006<WY and FLAP_PIVOT[1]+.006>WY-PEG_LEN

def verify(work,manifest):
 """Independent cooked-file, namespace, package-index and authored-pose checks."""
 spec=importlib.util.spec_from_file_location('archive_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
 archive=work/'archive';verified=work/'verified';packed=(work/'packed/archive.archive').read_bytes()
 entries=checks.archive_entries(packed);files=manifest['files']
 n_models=1+POSES+2+len(FLAP_ANGLES)+2+len(CHIP_COUNTS)
 assert len(manifest['models'])==n_models==42 and len(manifest['textures'])==9
 assert len(entries)==len(files)==2*n_models+9
 assert set(entries)=={checks.fnv(row['depot']) for row in files}
 allowed={row['depot'] for row in files}|set(manifest['materialDependencies'])
 for row in files:
  data=(archive/row['depot'].replace('\\','/')).read_bytes()
  assert data[:4]==b'CR2W' and len(data)==row['bytes'] and hashlib.sha256(data).hexdigest()==row['sha256']
 hashes=set()
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
    hashes.add(r['geometryHash'])
    blob=r['renderResourceBlob']['Data'];chunks=blob['header']['renderChunkInfos'];assert sum(c['numIndices'] for c in chunks)//3==model['triangles']
    pixels=base64.b64decode(blob['renderBuffer']['Bytes'])
    for chunk_index,chunk in enumerate(chunks):
     vertices=chunk['chunkVertices'];layout_=vertices['vertexLayout'];elements=layout_['elements']['Elements']
     for color in (e for e in elements if e['usage']=='PS_Color'):
      stream=color['streamIndex'];offset=vertices['byteOffsets']['Elements'][stream];stride=layout_['slotStrides']['Elements'][stream]
      assert all(pixels[offset+j*stride:offset+j*stride+4]==b'\xff'*4 for j in range(chunk['numVertices']))
     uv=next(e for e in elements if e['usage']=='PS_TexCoord' and e['usageIndex']==0);stream=uv['streamIndex'];offset=vertices['byteOffsets']['Elements'][stream];stride=layout_['slotStrides']['Elements'][stream]
     values=[struct.unpack_from('<ee',pixels,offset+j*stride) for j in range(chunk['numVertices'])]
     assert all(math.isfinite(v) for pair in values for v in pair) and len(set(values))>1
     if model['materials'][chunk_index] in TEXTURED:
      assert all(-.001<=v<=1.001 for pair in values for v in pair),(name,'artwork UV out of bounds')
    mats=r['localMaterialBuffer']['materials'];names={e['name']['$value'] for e in r['materialEntries']}
    assert all(0<=e['index']<len(mats) for e in r['materialEntries'])
    assert all(c['$value'] in names for a in r['appearances'] for c in a['Data']['chunkMaterials'])
    lo,hi=r['boundingBox']['Min'],r['boundingBox']['Max']
    for i,axis in enumerate(('X','Y','Z')):
     assert math.isfinite(lo[axis]) and math.isfinite(hi[axis]) and lo[axis]<hi[axis]
     assert abs(lo[axis]-model['bounds']['min'][i])<1e-5 and abs(hi[axis]-model['bounds']['max'][i])<1e-5
 assert len(hashes)==n_models,'every pose is distinct geometry'
 for texture in manifest['textures']:
  r=json.loads(next(verified.rglob(texture['name']+'.xbm.json')).read_text())['Data']['RootChunk']
  assert r['$type']=='CBitmapTexture' and r['width']==texture['width'] and r['height']==texture['height']
  blob=r['renderTextureResource']['renderResourceBlobPC']['Data'];data=base64.b64decode(blob['textureData']['Bytes'])
  assert len(blob['header']['mipMapInfo'])==texture['mips']
  source=RESOURCE/'sources'/(texture['name']+'.png');image=Image.open(source).convert('RGBA')
  assert hashlib.sha256(source.read_bytes()).hexdigest()==texture['sourceSha256']
  assert data[:image.width*image.height*4]==(cooked(image) if texture.get('flipV') else image).tobytes() and all(v==255 for v in data[3::4])
 by_name={m['name']:m for m in manifest['models']}
 for p in range(POSES):
  b=by_name[f'fortune_disc_{p:02d}']['bounds'];assert max(abs(v) for v in b['min']+b['max'])<=R_FACE+1e-6
 sb=by_name['fortune_stand']['bounds'];assert sb['max'][2]<3.3 and sb['min'][2]==0 and max(abs(sb['min'][0]),sb['max'][0])<.9,sb
 with zipfile.ZipFile(RESOURCE/'dist/open77_casino_fortune.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_casino_fortune.archive']
  assert z.read(z.namelist()[0])==packed
 print(f'VERIFIED: {n_models} native props ({POSES} rotor poses, 2 blur, {len(FLAP_ANGLES)} flapper, 2 medallions, {len(CHIP_COUNTS)} chip stacks, stand), 9 opaque mipmapped textures, {len(files)} exact RDAR entries, geometry/bindings/package hashes',flush=True)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path.home()/'.cache/casino-fortune-build');p.add_argument('--verify-only',action='store_true');a=p.parse_args();work=a.work
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 tools=a.lab/'tools';env=os.environ.copy();env['DOTNET_ROOT']=str(tools/'dotnet');env['DOTNET_CLI_HOME']=str(work/'dotnet-home')
 def cli(*args,imports=0):
  result=subprocess.run([str(tools/'dotnet/dotnet'),str(tools/'wolvenkit/WolvenKit.CLI.dll'),*map(str,args)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  if '[ 0: Error' in result.stdout or (result.returncode and not(imports and result.stdout.count('Rebuilt with buffers:')==imports)):print(result.stdout);raise RuntimeError('WolvenKit failed '+str(args))
  print('\n'.join(line for line in result.stdout.splitlines() if 'Success' in line)[-2000:],flush=True)
 schemas=work/'json';raw=work/'raw';tex=work/'texture-json';host=work/'host-schema'
 for folder in (schemas,raw,tex,host,RESOURCE/'sources',work/'dotnet-home'):folder.mkdir(parents=True,exist_ok=True)
 geometry=models();check_poses(geometry)
 donor=json.loads((a.lab/'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_text())
 cli('convert','serialize','/home/dop42/opx_pool_assets/assets/hosts/open77/assets/opx_infinity/pool/ball_01.ent','-o',host);template=json.loads((host/'ball_01.ent.json').read_text())
 textures=base.wood_textures(tex);texture_template=json.loads((tex/'wood_ivory.xbm.json').read_text())
 for name,image in artwork().items():textures.append(encode_texture(tex,name,image,texture_template))
 records=[]
 for i,(name,faces) in enumerate(geometry.items()):
  for f in faces:
   p1,p2,p3=(f[k] for k in ('a','b','c'));normal=base.cross([p2[j]-p1[j] for j in range(3)],[p3[j]-p1[j] for j in range(3)])
   assert sum(x*x for x in normal)>1e-22,(name,f)
  colors=glb(raw/(name+'.mesh.glb'),faces)
  (schemas/(name+'.mesh.json')).write_text(json.dumps(base.mesh_json(donor,colors,faces)))
  (schemas/(name+'.ent.json')).write_text(json.dumps(base.entity_json(template,name,7700+i)))
  records.append({'name':name,'mesh':DEPOT+'\\'+name+'.mesh','entity':DEPOT+'\\'+name+'.ent','triangles':len(faces),'materials':colors,'bounds':{'min':[min(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)],'max':[max(f[k][j] for f in faces for k in ('a','b','c')) for j in range(3)]}})
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');(target/'textures').mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target);cli('convert','deserialize',tex,'-o',target/'textures');cli('import',*[raw/(name+'.mesh.glb') for name in geometry],'-o',target,'--keep',imports=len(geometry))
 verified=work/'verified';verified.mkdir(exist_ok=True);cli('convert','serialize',archive,'-o',verified);packed=work/'packed';packed.mkdir(exist_ok=True);cli('pack',archive,'-o',packed)
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_casino_fortune.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_casino_fortune.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 manifest={'version':'1.0.0','namespace':DEPOT,'models':records,'textures':textures,'files':files,
  'wheel':{'segments':SEGMENTS,'poses':POSES,'halfLayout':HALF,'faceY':WY,'centreZ':WZ,'faceRadius':R_FACE,'pegRadius':R_PEG,'flapperPivot':FLAP_PIVOT,'flapperAngles':FLAP_ANGLES,'medallionRadius':MEDALLION_R,'chipCounts':CHIP_COUNTS,'spotX':SPOT_X,'spotY':SPOT_Y,'feltZ':FELT[4]},
  'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
