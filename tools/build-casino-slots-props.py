#!/usr/bin/env python3
"""Cook the original slot machine: cabinet, three reel strips, lever poses, lamp, coin.

Uses the existing native board-prop cooker as a read-only schema/tool library.
Only this resource and --work receive outputs. Requires Pillow (original symbol,
marquee and belly artwork), lupa (reads the reel strips from the shared rules),
.NET and WolvenKit from the inspected local lab.

Props turn about Z only, so every moving part is a separate prop: the reels are
flat symbol strips that slide vertically behind the bezel window, the lever is
six authored pose meshes and the lamp a lit/unlit pair. Inactive poses park
inside the closed cabinet, away from the reel bay that the window shows.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,struct,subprocess,zipfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]
RESOURCE=ROOT/'resources/assets/models/open77_casino_slots'
DEPOT='open77\\assets\\op77_lightrp\\casino_slots'
LAB=ROOT.parent/'dop-tests'
FONT=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()

# Palette. Textured materials use sentinel colors that never appear elsewhere.
BODY,TRIM,CHROME,LINING='#1A1C24FF','#2A2D36FF','#C8CDD6FF','#0B0B0EFF'
MAGENTA,CYAN,PAYLINE,DARK='#E0218AFF','#19D3E6FF','#FF2A3AFF','#050506FF'
KNOB,AMBER,LAMP_OFF,LAMP_ON,GOLD='#D11A2AFF','#F2A516FF','#4A1416FF','#FFE89AFF','#E6B84AFF'
ATLAS,MARQUEE,BELLY='#FEFEFDFF','#FEFEFCFF','#FEFEFBFF'
TEXTURED={ATLAS:'slot_symbols',MARQUEE:'slot_marquee',BELLY:'slot_belly'}
SURFACE={BODY:(.35,.55),TRIM:(.4,.6),CHROME:(.18,.92),LINING:(.95,0),MAGENTA:(.3,0),CYAN:(.3,0),PAYLINE:(.3,0),DARK:(.95,0),
 KNOB:(.22,0),AMBER:(.3,0),LAMP_OFF:(.2,0),LAMP_ON:(.08,0),GOLD:(.25,.85)}

# Layout in unscaled board-local metres (the client renders everything at 0.65).
# The front faces -Y; the lever is on the player's right (+X). Mirrored by
# client/core/casino_slots.lua (L) and checked by tools/test-casino-slots-client.py.
STOPS=12;ENTRIES=STOPS+3
LAYOUT={'paylineZ':1.33,'pitch':.085,'stripY':-.33,'reelX':[-.22,0,.22],'reelWidth':.20,
 'leverAngles':[0,17,34,51,68,85],'leverPivot':[.55,0,1.35],'leverLength':.45,
 'leverPark':[-.14,.16,0],'lampPark':[0,.15,-.32],
 'chuteY':-.37,'chuteZ':.73,'trayY':-.44,'trayZ':.574,'coinPark':[0,.2,.4]}
BODY_BOX=((-.46,.46),(-.36,.36),(.12,2.52))
BAY=((-.34,.34),(-.36,-.24),(.15,2.51))     # dark reel bay behind the window
P=LAYOUT['pitch'];PZ=LAYOUT['paylineZ']
WINDOW_X=(-.31,.31);WINDOW_Z=(PZ-1.3*P,PZ+1.3*P) # 2.6 visible rows
HOLE_X=(-.325,.325)


def reels():
 lua=LuaRuntime(unpack_returned_tuples=True)
 lua.execute('LightRpBoardGames={};LightRpItems={}')
 lua.execute((ROOT/'resources/gamemodes/op77_lightrp/shared/casino_slots.lua').read_text())
 S=lua.globals().LightRpCasinoSlots
 assert S.STOPS==STOPS
 symbols=[S.SYMBOLS[i+1] for i in range(len(S.SYMBOLS))]
 strips=[[S.REELS[r+1][i+1] for i in range(STOPS)] for r in range(3)]
 return symbols,strips


def quad(out,points,c,uv=None):
 for ids in ((0,1,2),(0,2,3)):
  f={'a':list(points[ids[0]]),'b':list(points[ids[1]]),'c':list(points[ids[2]]),'color':c}
  if uv is not None:f['uv']=[uv[i] for i in ids]
  out.append(f)

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

def cylinder_x(out,x0,x1,y,z,r,c,sides=24):
 """A closed cylinder along +X (lathe along Z, then turned)."""
 tmp=[];g.lathe(tmp,[(0,0),(r,0),(r,x1-x0),(0,x1-x0)],c,sides)
 out.extend(transform(tmp,lambda px,py,pz:(x0+pz,y+py,z-px)))

def cabinet():
 out=[];(bx0,bx1),(by0,by1),(bz0,bz1)=BODY_BOX
 box(out,-.49,.49,-.40,.40,0,bz0,TRIM)                       # plinth
 box(out,-.40,.40,-.405,-.40,.03,.07,MAGENTA)                # plinth neon strip
 # Closed body shell; the front has only the window hole.
 quad(out,[(bx0,by1,bz0),(bx0,by0,bz0),(bx0,by0,bz1),(bx0,by1,bz1)],BODY)   # left  (-X)
 quad(out,[(bx1,by0,bz0),(bx1,by1,bz0),(bx1,by1,bz1),(bx1,by0,bz1)],BODY)   # right (+X)
 quad(out,[(bx1,by1,bz0),(bx0,by1,bz0),(bx0,by1,bz1),(bx1,by1,bz1)],BODY)   # back  (+Y)
 quad(out,[(bx0,by0,bz1),(bx1,by0,bz1),(bx1,by1,bz1),(bx0,by1,bz1)],BODY)   # top   (+Z)
 hx0,hx1=HOLE_X;wz0,wz1=WINDOW_Z
 front(out,bx0,bx1,bz0,wz0,by0,BODY);front(out,bx0,bx1,wz1,bz1,by0,BODY)
 front(out,bx0,hx0,wz0,wz1,by0,BODY);front(out,hx1,bx1,wz0,wz1,by0,BODY)
 inward_box(out,BAY,LINING,skip=('-y',))
 # Baffles just inside the window keep oblique views off the strip ends.
 box(out,BAY[0][0],BAY[0][1],-.36,-.336,wz1,wz1+.006,LINING);box(out,BAY[0][0],BAY[0][1],-.36,-.336,wz0-.006,wz0,LINING)
 # Chrome bezel; its inner edge is the visible window (strip edges stay hidden).
 wx0,wx1=WINDOW_X
 box(out,wx0-.06,wx0,-.40,-.355,wz0-.06,wz1+.06,CHROME);box(out,wx1,wx1+.06,-.40,-.355,wz0-.06,wz1+.06,CHROME)
 box(out,wx0,wx1,-.40,-.355,wz0-.06,wz0,CHROME);box(out,wx0,wx1,-.40,-.355,wz1,wz1+.06,CHROME)
 for x in (-.11,.11):box(out,x-.015,x+.015,-.375,-.338,wz0-.01,wz1+.01,TRIM)   # reel dividers
 for x in (wx0-.02,wx1+.02):box(out,x-.012,x+.012,-.405,-.398,PZ-.008,PZ+.008,PAYLINE)  # payline marks
 box(out,-.46,.46,-.39,-.36,wz0-.14,wz0-.06,BODY);box(out,-.46,.46,-.39,-.36,wz1+.06,wz1+.16,BODY)
 # Button deck with spin button and three bet buttons.
 box(out,-.46,.46,-.50,-.36,1.0,1.07,TRIM);box(out,-.46,.46,-.505,-.50,1.0,1.07,CHROME)
 spin=[];g.lathe(spin,[(0,0),(.035,0),(.035,.018),(.03,.025),(0,.027)],KNOB,24);out.extend(transform(spin,lambda x,y,z:(x+.3,y-.43,z+1.07)))
 for x in (-.3,-.2,-.1):box(out,x-.035,x+.035,-.46,-.40,1.07,1.085,AMBER)
 # Belly artwork, coin chute and tray.
 box(out,-.42,.42,-.375,-.36,.79,.99,CHROME);front(out,-.40,.40,.80,.98,-.378,BELLY,[[0,1],[1,1],[1,0],[0,0]])
 front(out,-.12,.12,.68,.78,-.362,DARK);box(out,-.14,.14,-.42,-.36,.78,.80,CHROME)
 box(out,-.30,.30,-.50,-.36,.55,.57,TRIM);box(out,-.31,.31,-.51,-.49,.55,.64,CHROME)
 for x in (-.305,.305):box(out,x-.005,x+.005,-.51,-.36,.55,.62,CHROME)
 # Marquee with original artwork (2:1), frame and top cap.
 box(out,-.46,.46,-.39,-.36,1.74,2.36,BODY);box(out,-.44,.44,-.396,-.39,1.81,2.27,CHROME)
 front(out,-.42,.42,1.83,2.25,-.398,MARQUEE,[[0,1],[1,1],[1,0],[0,0]])
 box(out,-.47,.47,-.40,.37,2.52,2.56,CHROME);box(out,-.47,.47,-.405,-.395,2.36,2.40,MAGENTA)
 lamp_base=[];g.lathe(lamp_base,[(0,0),(.11,0),(.11,.02),(0,.02)],CHROME,32);out.extend(transform(lamp_base,lambda x,y,z:(x,y,z+2.56)))
 # Neon edges and side accents.
 for x in (-.465,.465):box(out,x-.008,x+.008,-.37,-.355,.15,2.50,MAGENTA)
 box(out,-.466,-.46,-.30,.30,.40,.42,CYAN);box(out,.46,.466,-.30,.30,.40,.42,CYAN)
 # Lever hub and side plate (the arm is a separate prop).
 px,py,pz=LAYOUT['leverPivot']
 box(out,.46,.47,-.12,.12,pz-.15,pz+.15,CHROME);cylinder_x(out,.46,.57,py,pz,.045,CHROME)
 return out

def symbol_strip(strip,symbols):
 out=[];w=LAYOUT['reelWidth'];entries=[strip[-1]]+strip+strip[:2];assert len(entries)==ENTRIES
 for i,name in enumerate(entries):
  k=symbols.index(name);col,row=k%2,k//2;u0,u1=col*.5+.002,col*.5+.498;v0,v1=row*.25+.002,row*.25+.248
  z=-i*P
  front(out,-w/2,w/2,z-P/2,z+P/2,0,ATLAS,[[u0,v1],[u1,v1],[u1,v0],[u0,v0]])
 return out

def lever(angle):
 arm=[];L=LAYOUT['leverLength']
 g.lathe(arm,[(0,-.01),(.03,-.01),(.03,.03),(.016,.04),(.016,L-.03),(0,L-.03)],CHROME,24)
 base.sphere(g,arm,(0,0,L),.045,KNOB)
 a=math.radians(angle);px,py,pz=LAYOUT['leverPivot']
 # Pull towards the player: the top swings from +Z to -Y about the X axis.
 return transform(arm,lambda x,y,z:(px+x,py+y*math.cos(a)-z*math.sin(a),pz+y*math.sin(a)+z*math.cos(a)))

def lamp(color):
 out=[];prof=[(0,0)]+[(.09*math.cos(math.radians(d)),.11*math.sin(math.radians(d))) for d in range(0,91,10)]
 prof[-1]=(0,.11);g.lathe(out,prof,color,32)
 return transform(out,lambda x,y,z:(x,y,z+2.58))

def coin():
 out=[];g.lathe(out,[(0,-.004),(.025,-.004),(.027,-.002),(.027,.002),(.025,.004),(0,.004)],GOLD,24);return out

def models(symbols,strips):
 m={'slot_cabinet':cabinet()}
 for r in range(3):m[f'slot_strip_{r+1}']=symbol_strip(strips[r],symbols)
 for i,a in enumerate(LAYOUT['leverAngles']):m[f'slot_lever_{i}']=lever(a)
 m['slot_lamp_off']=lamp(LAMP_OFF);m['slot_lamp_on']=lamp(LAMP_ON);m['slot_coin']=coin()
 return m


# Artwork --------------------------------------------------------------------
def font(size):return ImageFont.truetype(str(FONT),size)
def draw_symbol(d,name,cx,cy,s):
 """Original vector-style symbols drawn in a cell of height ~s."""
 def circle(x,y,r,fill,outline=None,width=0):d.ellipse((x-r,y-r,x+r,y+r),fill=fill,outline=outline,width=width)
 if name=='cherry':
  d.line((cx-.22*s,cy+.1*s,cx+.05*s,cy-.33*s),fill=(48,120,38),width=int(s*.05));d.line((cx+.2*s,cy+.12*s,cx+.05*s,cy-.33*s),fill=(48,120,38),width=int(s*.05))
  d.polygon([(cx+.05*s,cy-.33*s),(cx+.32*s,cy-.40*s),(cx+.2*s,cy-.25*s)],fill=(70,160,50))
  for x in (-.22,.2):circle(cx+x*s,cy+.2*s,.17*s,(200,20,36),(110,8,18),3);circle(cx+x*s-.06*s,cy+.14*s,.04*s,(255,170,170))
 elif name=='lemon':
  d.ellipse((cx-.36*s,cy-.24*s,cx+.36*s,cy+.24*s),fill=(250,214,40),outline=(170,130,10),width=4)
  d.polygon([(cx-.44*s,cy),(cx-.33*s,cy-.07*s),(cx-.33*s,cy+.07*s)],fill=(250,214,40));d.polygon([(cx+.44*s,cy),(cx+.33*s,cy-.07*s),(cx+.33*s,cy+.07*s)],fill=(250,214,40))
  circle(cx-.12*s,cy-.09*s,.05*s,(255,245,170))
 elif name=='grape':
  for i,(x,y) in enumerate([(-.16,-.14),(0,-.14),(.16,-.14),(-.08,.0),(.08,.0),(-.16,.0),(.16,0),(0,.14),(-.08,.27),(.08,.27),(0,.14)]):
   circle(cx+x*s,cy+y*s,.1*s,(120,40,160),(60,12,90),3)
  d.polygon([(cx,cy-.26*s),(cx+.26*s,cy-.42*s),(cx+.12*s,cy-.22*s)],fill=(70,160,50))
 elif name=='bell':
  d.polygon([(cx-.3*s,cy+.22*s),(cx-.2*s,cy+.12*s),(cx-.17*s,cy-.18*s),(cx,cy-.33*s),(cx+.17*s,cy-.18*s),(cx+.2*s,cy+.12*s),(cx+.3*s,cy+.22*s)],fill=(236,180,40),outline=(140,95,10))
  d.rectangle((cx-.32*s,cy+.2*s,cx+.32*s,cy+.27*s),fill=(200,140,20));circle(cx,cy+.32*s,.07*s,(200,140,20));circle(cx,cy-.36*s,.05*s,(200,140,20))
 elif name=='bar':
  d.rounded_rectangle((cx-.42*s,cy-.2*s,cx+.42*s,cy+.2*s),radius=int(.08*s),fill=(20,20,24),outline=(230,230,235),width=5)
  d.text((cx,cy),'BAR',font=font(int(.3*s)),anchor='mm',fill=(240,240,245))
 elif name=='chip':
  for i in range(5):
   o=(-.24+i*.12)*s;d.rectangle((cx+o-.025*s,cy-.4*s,cx+o+.025*s,cy+.4*s),fill=(220,180,70));d.rectangle((cx-.4*s,cy+o-.025*s,cx+.4*s,cy+o+.025*s),fill=(220,180,70))
  d.rectangle((cx-.3*s,cy-.3*s,cx+.3*s,cy+.3*s),fill=(18,70,52),outline=(220,180,70),width=4)
  d.text((cx,cy),'77',font=font(int(.26*s)),anchor='mm',fill=(25,211,230))
 elif name=='diamond':
  pts=[(cx-.36*s,cy-.1*s),(cx-.2*s,cy-.3*s),(cx+.2*s,cy-.3*s),(cx+.36*s,cy-.1*s),(cx,cy+.36*s)]
  d.polygon(pts,fill=(60,200,235),outline=(10,90,130));d.line((cx-.36*s,cy-.1*s,cx+.36*s,cy-.1*s),fill=(10,90,130),width=3)
  for x in (-.2,.2):d.line((cx+x*s,cy-.3*s,cx+x*.5*s,cy-.1*s),fill=(10,90,130),width=3);d.line((cx+x*.5*s,cy-.1*s,cx,cy+.36*s),fill=(10,90,130),width=3)
  d.polygon([(cx-.15*s,cy-.25*s),(cx-.05*s,cy-.25*s),(cx-.12*s,cy-.14*s)],fill=(220,250,255))
 elif name=='seven':
  d.text((cx+4,cy+4),'7',font=font(int(.85*s)),anchor='mm',fill=(90,0,10))
  d.text((cx,cy),'7',font=font(int(.85*s)),anchor='mm',fill=(225,25,40),stroke_width=4,stroke_fill=(255,215,80))
 else:raise ValueError(name)

def artwork(symbols):
 result={}
 atlas=Image.new('RGBA',(1024,1024),(0,0,0,255))
 for k,name in enumerate(symbols):
  col,row=k%2,k//2;x0,y0=col*512,row*256;cell=Image.new('RGBA',(512,256),(246,240,226,255));d=ImageDraw.Draw(cell)
  for y in range(256):
   shade=int(10*abs(y-128)/128);d.line((0,y,511,y),fill=(246-shade,240-shade,226-shade,255))
  d.line((0,1,511,1),fill=(170,160,140,255),width=3);d.line((0,254,511,254),fill=(170,160,140,255),width=3)
  draw_symbol(d,name,256,128,230);atlas.alpha_composite(cell,(x0,y0))
 result['slot_symbols']=atlas
 m=Image.new('RGBA',(1024,512),(12,10,24,255));d=ImageDraw.Draw(m)
 for y in range(512):d.line((0,y,1023,y),fill=(12+int(30*y/512),10,24+int(40*y/512),255))
 for i in range(0,1024,32):d.line((i,0,i-200,512),fill=(40,20,70,255),width=2)
 d.rounded_rectangle((24,24,1000,488),radius=40,outline=(224,33,138,255),width=10);d.rounded_rectangle((44,44,980,468),radius=30,outline=(25,211,230,255),width=4)
 d.text((512,190),'LUCKY',font=font(150),anchor='mm',fill=(255,232,154,255),stroke_width=6,stroke_fill=(224,33,138,255))
 d.text((512,350),'CIRCUIT',font=font(120),anchor='mm',fill=(25,211,230,255),stroke_width=5,stroke_fill=(10,40,70,255))
 for x in (110,914):d.text((x,260),'7',font=font(160),anchor='mm',fill=(225,25,40,255),stroke_width=5,stroke_fill=(255,215,80,255))
 result['slot_marquee']=m
 b=Image.new('RGBA',(1024,256),(20,18,30,255));d=ImageDraw.Draw(b)
 d.rectangle((6,6,1017,249),outline=(224,33,138,255),width=6)
 icons=Image.new('RGBA',(1024,256),(0,0,0,0))
 pays=[('seven','200'),('diamond','100'),('chip','50'),('bar','30'),('bell','18'),('grape','10')]
 for i,(name,pay) in enumerate(pays):
  x=90+i*168;cell=Image.new('RGBA',(160,160),(246,240,226,255));dd=ImageDraw.Draw(cell);draw_symbol(dd,name,80,80,130)
  cell=cell.resize((100,100),Image.Resampling.LANCZOS);icons.alpha_composite(cell,(x-50,30))
  d.text((x,190),'x'+pay,font=font(44),anchor='mm',fill=(255,232,154,255))
 b.alpha_composite(icons)
 result['slot_belly']=b
 return result

def encode_texture(directory,name,image,template):
 image=image.convert('RGBA');source=RESOURCE/'sources'/(name+'.png');image.save(source)
 width,height=image.size;data=bytearray();mips=[];level=image
 while True:
  block=level.tobytes();w,h=level.size;mips.append({'$type':'rendRenderTextureBlobMipMapInfo','layout':{'$type':'rendRenderTextureBlobMemoryLayout','rowPitch':w*4,'slicePitch':len(block)},'placement':{'$type':'rendRenderTextureBlobPlacement','offset':len(data),'size':len(block)}});data.extend(block)
  if (w,h)==(1,1):break
  level=level.resize((max(1,w//2),max(1,h//2)),Image.Resampling.BOX)
 obj=copy.deepcopy(template);r=obj['Data']['RootChunk'];r['width']=width;r['height']=height
 blob=r['renderTextureResource']['renderResourceBlobPC']['Data'];header=blob['header'];header['mipMapInfo']=mips;header['sizeInfo']['width']=width;header['sizeInfo']['height']=height
 header['textureInfo'].update(mipCount=len(mips),sliceSize=len(data),textureDataSize=len(data));blob['textureData']['Bytes']=base64.b64encode(data).decode()
 (directory/(name+'.xbm.json')).write_text(json.dumps(obj,separators=(',',':')))
 return {'name':name,'depot':DEPOT+'\\textures\\'+name+'.xbm','width':width,'height':height,'mips':len(mips),'bytes':len(data),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest()}

ORIGINAL_MATERIAL=base.material
def linear(v):
 v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def material(color):
 result=ORIGINAL_MATERIAL(base.WHITE)
 if color in TEXTURED:
  result['values'][0]['BaseColor']=base.ref(DEPOT+'\\textures\\'+TEXTURED[color]+'.xbm');result['values'][1]['BaseColorScale'].update(X=1,Y=1,Z=1)
  result['values'][2]['RoughnessScale']=.45;result['values'][3]['MetalnessScale']=0
  return result
 rough,metal=SURFACE[color]
 result['values'][0]['BaseColor']=base.ref('engine\\textures\\editor\\white.xbm')
 c=[linear(int(color[i:i+2],16)) for i in (1,3,5)];result['values'][1]['BaseColorScale'].update(X=c[0],Y=c[1],Z=c[2])
 result['values'][2]['RoughnessScale']=rough;result['values'][3]['MetalnessScale']=metal
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
 assert len(manifest['models'])==13 and len(manifest['textures'])==3
 assert len(entries)==len(files)==2*13+3
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
  assert data[:image.width*image.height*4]==image.tobytes() and all(v==255 for v in data[3::4])
 symbols,strips=reels();assert manifest['symbols']==symbols and manifest['reels']==strips and manifest['layout']==LAYOUT
 check_layout(models(symbols,strips),symbols,strips)
 with zipfile.ZipFile(RESOURCE/'dist/open77_casino_slots.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_casino_slots.archive']
  assert z.read(z.namelist()[0])==packed
 print('VERIFIED: 13 native props (cabinet, 3 strips, 6 lever poses, 2 lamps, coin), 3 opaque mipmapped textures, 29 exact RDAR entries, geometry/bindings/package hashes, parked poses hidden, strips always cover the window inside the bay',flush=True)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path('/tmp/casino-slots-props/build'));p.add_argument('--verify-only',action='store_true');a=p.parse_args();work=a.work
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 symbols,strips=reels();geometry=models(symbols,strips);check_layout(geometry,symbols,strips)
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
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');(target/'textures').mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target);cli('convert','deserialize',tex,'-o',target/'textures');cli('import',*[raw/(name+'.mesh.glb') for name in geometry],'-o',target,'--keep',imports=len(geometry))
 verified=work/'verified';verified.mkdir(exist_ok=True);cli('convert','serialize',archive,'-o',verified);packed=work/'packed';packed.mkdir(exist_ok=True);cli('pack',archive,'-o',packed)
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_casino_slots.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_casino_slots.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 manifest={'version':'1.0.0','namespace':DEPOT,'models':records,'textures':textures,'files':files,'symbols':symbols,'reels':strips,'layout':LAYOUT,
  'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
