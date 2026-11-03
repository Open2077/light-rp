#!/usr/bin/env python3
"""Cook original tabletop geometry to native RED4 meshes/entities and preload archive.

Requires WolvenKit 9.1 CLI, .NET and an inspected JSON mesh schema. Inputs are
read-only; all intermediate work is isolated beneath --work. No donor geometry
or gameplay code is shipped. Engine material references match the inspected
OPX custom-vehicle pipeline.

The chess/checkers/Connect Four art (geometry, materials, textures) lives in
tools/board-game-art.py; cooking it needs NumPy and Pillow. This file is also
the shared cooker library of the casino/roulette build scripts: its public
functions (load_generator, sphere, glb, material, mesh_json, entity_json,
wood_textures, ref, cross, ...) keep their behaviour for them. Additions:
faces may carry explicit 'uv' (honoured by glb), `cy:` material keys resolve
through the art table, and encode_texture cooks any Pillow image.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,random,shutil,struct,subprocess,zipfile,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RESOURCE=ROOT/'resources/assets/models/open77_board_games'
LAB=ROOT.parent/'dop-tests'
DEPOT='open77\\assets\\op77_lightrp\\board_games'
WHITE,BLACK,NATURAL='#FAF8F2FF','#10100FFF','#8C592FFF'
BOARD_LIGHT,BOARD_DARK,WOOD_FRAME='#D5B68BFF','#4A2C1AFF','#5A3822FF'
BLUE,RED,YELLOW='#2159BFFF','#C92C2CFF','#EDC525FF'
WHITE_TEXTURE='engine\\textures\\editor\\white.xbm'
# The engine samples rows bottom-up relative to our UVs (seen in game: text
# upside down), so cooked bytes are flipped vertically; sources/ keeps the
# drawing upright. Set FLIP_V=False to cook the image as drawn.
FLIP_V=True
_ART=None

def load_art():
 """tools/board-game-art.py, loaded once (geometry needs only the stdlib)."""
 global _ART
 if _ART is None:
  s=importlib.util.spec_from_file_location('board_game_art',ROOT/'tools/board-game-art.py');_ART=importlib.util.module_from_spec(s);s.loader.exec_module(_ART)
 return _ART

def load_collision():
 s=importlib.util.spec_from_file_location('collision_props',ROOT/'tools/collision_props.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m

def load_generator():
 s=importlib.util.spec_from_file_location('tabletop',ROOT/'tools/generate-board-game-models.py');g=importlib.util.module_from_spec(s);s.loader.exec_module(g)
 lathe=g.lathe
 def detailed(out,profile,color,sides=24):return lathe(out,profile,color,max(24,sides))
 g.lathe=detailed
 g.IVORY,g.DARK=WHITE,BLACK
 g.LIGHT_SQUARE,g.DARK_SQUARE,g.FRAME=BOARD_LIGHT,BOARD_DARK,WOOD_FRAME
 g.CONNECT_BLUE,g.CONNECT_RED,g.CONNECT_YELLOW=BLUE,RED,YELLOW
 return g

def turned_base(g,out,c):
 g.lathe(out,[(0,0),(.031,0),(.034,.002),(.034,.006),(.032,.010),(.029,.012),(.029,.015),(.025,.018),(.023,.020),(0,.020)],c)

def sphere(g,out,center,r,c):
 profile=[]
 for i in range(13):
  a=-math.pi/2+i*math.pi/12
  profile.append((0 if i in (0,12) else r*math.cos(a),center[2]+r*math.sin(a)))
 local=[];g.lathe(local,profile,c)
 for f in local:
  for k in ('a','b','c'):f[k][0]+=center[0];f[k][1]+=center[1]
 out.extend(local)

def triangulate(poly):
 """Ear clipping keeps the concave horse muzzle/neck silhouette intact."""
 ids=list(range(len(poly)));result=[]
 area=sum(poly[i][0]*poly[(i+1)%len(poly)][1]-poly[(i+1)%len(poly)][0]*poly[i][1] for i in ids)
 if area<0:ids.reverse()
 def side(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
 while len(ids)>3:
  for i,b in enumerate(ids):
   a,c=ids[i-1],ids[(i+1)%len(ids)]
   if side(poly[a],poly[b],poly[c])<=1e-12:continue
   if any(side(poly[a],poly[b],poly[p])>=-1e-12 and side(poly[b],poly[c],poly[p])>=-1e-12 and side(poly[c],poly[a],poly[p])>=-1e-12 for p in ids if p not in (a,b,c)):continue
   result.append((a,b,c));ids.pop(i);break
  else:raise ValueError('invalid horse profile')
 result.append(tuple(ids));return result

def wooden_piece(g,kind,side,game):
 out=[];c=WHITE if side=='white' else BLACK
 if game=='connect4':return g.piece(kind,side,game)
 if game=='checkers':
  def chip(z,r):
   g.lathe(out,[(0,z),(r-.002,z),(r,z+.002),(r,z+.004),(r-.001,z+.005),(r-.001,z+.007),(r,z+.008),(r,z+.011),(r-.002,z+.014),(0,z+.014)],c)
  chip(0,.032)
  if kind=='king':
   chip(.015,.029)
   g.lathe(out,[(.020,.029),(.022,.029),(.022,.031),(.020,.031),(.020,.029)],c)
  return out
 turned_base(g,out,c)
 if kind=='pawn':
  g.lathe(out,[(.023,.020),(.016,.025),(.011,.040),(.016,.044),(.016,.047),(0,.047)],c)
  sphere(g,out,(0,0,.062),.017,c)
 elif kind=='rook':
  g.lathe(out,[(.023,.020),(.020,.027),(.017,.056),(.025,.061),(.030,.064),(.030,.074),(0,.074)],c)
  for i in range(6):
   a=i*math.tau/6;g.box(out,.024*math.cos(a),.024*math.sin(a),.081,.010,.010,.016,c)
 elif kind=='knight':
  profile=[(-.018,.019),(-.021,.045),(-.026,.067),(-.021,.087),(-.012,.104),(-.006,.087),(.010,.083),(.029,.062),(.027,.052),(.014,.052),(.001,.062),(.007,.040),(.016,.019)]
  if sum(profile[i][0]*profile[(i+1)%len(profile)][1]-profile[(i+1)%len(profile)][0]*profile[i][1] for i in range(len(profile)))<0:profile.reverse()
  cy=sum(p[0] for p in profile)/len(profile);cz=sum(p[1] for p in profile)/len(profile)
  inner=[(cy+(y-cy)*.90,cz+(z-cz)*.94) for y,z in profile]
  def ring(x,p):return [[x,y,z] for y,z in p]
  rings=[ring(-.014,inner),ring(-.011,profile),ring(.011,profile),ring(.014,inner)]
  for a,b,cidx in triangulate(inner):
   g.tri(out,rings[0][cidx],rings[0][b],rings[0][a],c)
   g.tri(out,rings[-1][a],rings[-1][b],rings[-1][cidx],c)
  for ra,rb in zip(rings,rings[1:]):
   for i in range(len(profile)):j=(i+1)%len(profile);g.quad(out,ra[i],ra[j],rb[j],rb[i],c)
  # Small dark carved eyes make the horse head readable, without gold accents.
  for x in (-.0135,.0135):sphere(g,out,(x,.004,.076),.0008,BLACK)
 elif kind=='bishop':
  g.lathe(out,[(.023,.020),(.015,.029),(.010,.055),(.022,.060),(.022,.064),(.014,.068),(.020,.079),(.014,.095),(0,.108)],c)
 elif kind=='queen':
  g.lathe(out,[(.023,.020),(.017,.028),(.011,.060),(.022,.068),(.022,.073),(.016,.077),(.018,.087),(0,.087)],c)
  n=56
  for i in range(n):
   a,b=i*math.tau/n,(i+1)*math.tau/n
   def p(angle,r,z):return [r*math.cos(angle),r*math.sin(angle),z]
   za=.098+.006*math.cos(a*7);zb=.098+.006*math.cos(b*7)
   g.quad(out,p(a,.027,.085),p(b,.027,.085),p(b,.027,zb),p(a,.027,za),c)
   g.quad(out,p(b,.018,.085),p(a,.018,.085),p(a,.018,za),p(b,.018,zb),c)
   g.quad(out,p(a,.018,za),p(a,.027,za),p(b,.027,zb),p(b,.018,zb),c)
   g.quad(out,p(b,.018,.085),p(b,.027,.085),p(a,.027,.085),p(a,.018,.085),c)
  sphere(g,out,(0,0,.103),.008,c)
 elif kind=='king':
  g.lathe(out,[(.023,.020),(.016,.030),(.011,.064),(.025,.073),(.025,.078),(.018,.083),(.014,.092),(0,.096)],c)
  g.box(out,0,0,.106,.009,.009,.036,c);g.box(out,0,0,.112,.031,.009,.009,c)
 return out

def wooden_geometry():
 """The previous carved-wood set (kept for reference and reuse)."""
 g=load_generator();models={'chess_board':g.board(8),'checkers_board':g.board(10)}
 # Real perforated frame with front/back skins and cylindrical aperture walls.
 out=[];blue=g.CONNECT_BLUE;n=24
 for row in range(1,7):
  for col in range(1,8):
   cx,cz=(col-4)*.14,(6.5-row)*.14+.04
   def p(a,r,y):return [cx+r*math.cos(a),y,cz+r*math.sin(a)]
   for i in range(n):
    a,b=i*math.tau/n,(i+1)*math.tau/n
    ra=.07/max(abs(math.cos(a)),abs(math.sin(a)));rb=.07/max(abs(math.cos(b)),abs(math.sin(b)))
    for y in (-.018,.018):
     points=[p(a,ra,y),p(b,rb,y),p(b,.055,y),p(a,.055,y)]
     if y>0:points.reverse()
     g.quad(out,*points,blue)
    g.quad(out,p(a,.055,-.018),p(a,.055,.018),p(b,.055,.018),p(b,.055,-.018),blue)
 for x in (-.51,.51):g.box(out,x,0,.47,.04,.06,.90,blue);g.box(out,x,0,.02,.12,.28,.04,g.FRAME)
 for z in (.035,.9):g.box(out,0,0,z,1.06,.06,.025,blue)
 models['connect4_board']=out
 for game,kinds in [('chess',['pawn','rook','knight','bishop','queen','king']),('checkers',['man','king']),('connect4',['disc'])]:
  for side in ('white','black'):
   for kind in kinds:
    faces=wooden_piece(g,kind,side,game)
    models[game+'_'+side+'_'+kind]=faces
 return models

def model_geometry():
 """Every model of the open77_board_games pack (Night City art), checked."""
 art=load_art();models=art.models();art.check(models);return models

# Board bases get a mesh-less collider entity beside them (tools/COLLISION.md).
# Boxes are board-local metres before the 0.65 client scale.
def collider_boxes(col):
 return {'chess_board':[col.Box.between((-.56,-.56,-.036),(.56,.56,.0115))],
  'checkers_board':[col.Box.between((-.56,-.56,-.036),(.56,.56,.0115))],
  'connect4_board':[col.Box.between((-.54,-.04,0),(.54,.04,.976)),col.Box.between((-.558,-.15,0),(-.466,.15,.016)),col.Box.between((.466,-.15,0),(.558,.15,.016))]}

def normalize(v):
 n=math.sqrt(sum(x*x for x in v));return [x/n for x in v]
def cross(a,b):return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]

def wood_textures(directory):
 """Original quarter-sawn grain, cooked as gamma-tagged RGBA textures with mips."""
 sources=RESOURCE/'sources';sources.mkdir(parents=True,exist_ok=True)
 records=[]
 for index,(name,base,strength) in enumerate([('wood_ivory',(245,245,239),.025),('wood_ebony',(19,17,15),.11),('wood_natural',(140,89,47),.20),('wood_grain',(220,220,220),.105)]):
  rng=random.Random(7700+index);size=256;pixels=[]
  for y in range(size):
   for x in range(size):
    # The phase is periodic on both axes, avoiding a visible tile boundary.
    u,v=x/size,y/size
    warp=1.5*math.sin(v*math.tau)+.45*math.sin(v*math.tau*3)
    broad=math.sin(u*math.tau*17+warp)
    fine=math.sin(u*math.tau*53+.4*math.sin(v*math.tau*2))
    pore=max(0,math.sin(u*math.tau*89+warp*.5))**18
    grain=.52*broad+.16*fine-.34*pore+.12*rng.uniform(-1,1)
    pixels.append(tuple(max(0,min(255,round(c*(1+strength*grain)))) for c in base)+(255,))
  raw=b''.join(bytes(p) for p in pixels)
  def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
  scan=b''.join(b'\0'+raw[y*size*4:(y+1)*size*4] for y in range(size))
  png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',size,size,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan,9))+chunk(b'IEND',b'')
  (sources/(name+'.png')).write_bytes(png)
  mips=[];data=bytearray();w=h=size;level=pixels
  while True:
   block=b''.join(bytes(p) for p in level)
   mips.append({'$type':'rendRenderTextureBlobMipMapInfo','layout':{'$type':'rendRenderTextureBlobMemoryLayout','rowPitch':w*4,'slicePitch':len(block)},'placement':{'$type':'rendRenderTextureBlobPlacement','offset':len(data),'size':len(block)}});data.extend(block)
   if w==h==1:break
   nw,nh=max(1,w//2),max(1,h//2)
   level=[tuple(round(sum(level[min(h-1,y*2+dy)*w+min(w-1,x*2+dx)][c] for dy in (0,1) for dx in (0,1))/4) for c in range(4)) for y in range(nh) for x in range(nw)];w,h=nw,nh
  header={'$type':'rendRenderTextureBlobHeader','flags':1,'histogramData':[],'mipMapInfo':mips,'sizeInfo':{'$type':'rendRenderTextureBlobSizeInfo','width':size,'height':size,'depth':1},'textureInfo':{'$type':'rendRenderTextureBlobTextureInfo','dataAlignment':8,'mipCount':len(mips),'sliceCount':1,'sliceSize':len(data),'textureDataSize':len(data),'type':'TEXTYPE_2D'},'version':2}
  setup={'$type':'STextureGroupSetup','compression':'TCM_None','group':'TEXG_Generic_Color','hasMipchain':1,'isGamma':1,'isStreamable':0,'allowTextureDowngrade':0,'rawFormat':'TRF_TrueColor'}
  root={'$type':'CBitmapTexture','cookingPlatform':'PLATFORM_PC','width':size,'height':size,'depth':1,'setup':setup,'histBiasAddCoef':{'$type':'Vector3','X':0,'Y':0,'Z':0},'histBiasMulCoef':{'$type':'Vector3','X':1,'Y':1,'Z':1},'renderResourceBlob':None,'renderTextureResource':{'$type':'rendRenderTextureResource','renderResourceBlobPC':{'HandleId':'0','Data':{'$type':'rendRenderTextureBlobPC','header':header,'textureData':{'BufferId':'0','Flags':131072,'Bytes':base64.b64encode(data).decode()}}}}}
  obj={'Header':{'WolvenKitVersion':'9.1.0','WKitJsonVersion':'0.0.9','GameVersion':2310,'DataType':'CR2W'},'Data':{'Version':195,'BuildVersion':0,'RootChunk':root}}
  (directory/(name+'.xbm.json')).write_text(json.dumps(obj,separators=(',',':')))
  records.append({'name':name,'depot':DEPOT+'\\textures\\'+name+'.xbm','width':size,'height':size,'mips':len(mips),'bytes':len(data),'sourceSha256':hashlib.sha256(png).hexdigest()})
 return records
def encode_texture(directory,name,image,sources=None):
 """Cook a Pillow image to <directory>/<name>.xbm.json (gamma RGBA, TCM_None,
 full mip chain, FLIP_V) and save the upright source PNG in `sources`."""
 from PIL import Image
 image=image.convert('RGBA');sources=Path(sources or RESOURCE/'sources');sources.mkdir(parents=True,exist_ok=True)
 source=sources/(name+'.png');image.save(source)
 width,height=image.size;data=bytearray();mips=[];level=image.transpose(Image.Transpose.FLIP_TOP_BOTTOM) if FLIP_V else image
 while True:
  block=level.tobytes();w,h=level.size
  mips.append({'$type':'rendRenderTextureBlobMipMapInfo','layout':{'$type':'rendRenderTextureBlobMemoryLayout','rowPitch':w*4,'slicePitch':len(block)},'placement':{'$type':'rendRenderTextureBlobPlacement','offset':len(data),'size':len(block)}});data.extend(block)
  if (w,h)==(1,1):break
  level=level.resize((max(1,w//2),max(1,h//2)),Image.Resampling.BOX)
 header={'$type':'rendRenderTextureBlobHeader','flags':1,'histogramData':[],'mipMapInfo':mips,'sizeInfo':{'$type':'rendRenderTextureBlobSizeInfo','width':width,'height':height,'depth':1},'textureInfo':{'$type':'rendRenderTextureBlobTextureInfo','dataAlignment':8,'mipCount':len(mips),'sliceCount':1,'sliceSize':len(data),'textureDataSize':len(data),'type':'TEXTYPE_2D'},'version':2}
 setup={'$type':'STextureGroupSetup','compression':'TCM_None','group':'TEXG_Generic_Color','hasMipchain':1,'isGamma':1,'isStreamable':0,'allowTextureDowngrade':0,'rawFormat':'TRF_TrueColor'}
 root={'$type':'CBitmapTexture','cookingPlatform':'PLATFORM_PC','width':width,'height':height,'depth':1,'setup':setup,'histBiasAddCoef':{'$type':'Vector3','X':0,'Y':0,'Z':0},'histBiasMulCoef':{'$type':'Vector3','X':1,'Y':1,'Z':1},'renderResourceBlob':None,'renderTextureResource':{'$type':'rendRenderTextureResource','renderResourceBlobPC':{'HandleId':'0','Data':{'$type':'rendRenderTextureBlobPC','header':header,'textureData':{'BufferId':'0','Flags':131072,'Bytes':base64.b64encode(data).decode()}}}}}
 obj={'Header':{'WolvenKitVersion':'9.1.0','WKitJsonVersion':'0.0.9','GameVersion':2310,'DataType':'CR2W'},'Data':{'Version':195,'BuildVersion':0,'RootChunk':root}}
 (Path(directory)/(name+'.xbm.json')).write_text(json.dumps(obj,separators=(',',':')))
 return {'name':name,'flipV':FLIP_V,'depot':DEPOT+'\\textures\\'+name+'.xbm','width':width,'height':height,'mips':len(mips),'bytes':len(data),'sourceSha256':hashlib.sha256(source.read_bytes()).hexdigest()}

def art_textures(directory):
 """Cook every texture of the Night City art (sources saved upright)."""
 return [encode_texture(directory,name,image) for name,image in sorted(load_art().textures().items())]

def glb(path,faces):
 groups={}
 for face in faces:groups.setdefault(face['color'],[]).append(face)
 doc={'asset':{'version':'2.0','generator':'LightRP original tabletop native-prop builder'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'buffers':[{}],'bufferViews':[],'accessors':[]};data=bytearray()
 def add(values,kind,width,integer=False):
  values=list(values);data.extend(b'\0'*((-len(data))%4));start=len(data)
  flat=[x for v in values for x in v] if width>1 else values
  data.extend(struct.pack('<'+('I' if integer else 'f')*len(flat),*flat));view=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':start,'byteLength':len(data)-start})
  acc={'bufferView':view,'componentType':5125 if integer else 5126,'count':len(values),'type':kind}
  if kind=='VEC3':acc.update(min=[min(v[i] for v in values) for i in range(3)],max=[max(v[i] for v in values) for i in range(3)])
  doc['accessors'].append(acc);return len(doc['accessors'])-1
 for index,(color,triangles) in enumerate(groups.items()):
  points=[];normals=[];tangents=[];uv=[];prepared=[];neighbors={}
  for face in triangles:
   # RED4 Z-up -> glTF Y-up: (X,Z,-Y), determinant +1.
   pts=[[face[k][0],face[k][2],-face[k][1]] for k in ('a','b','c')]
   n=normalize(cross([pts[1][i]-pts[0][i] for i in range(3)],[pts[2][i]-pts[0][i] for i in range(3)]))
   prepared.append((pts,n))
   for p in pts:neighbors.setdefault(tuple(round(v,7) for v in p),[]).append(n)
  for face_index,(pts,n) in enumerate(prepared):
   explicit=triangles[face_index].get('uv')
   for corner,p in enumerate(pts):
    adjacent=[v for v in neighbors[tuple(round(x,7) for x in p)] if sum(v[i]*n[i] for i in range(3))>.75]
    smooth=normalize([sum(v[i] for v in adjacent) for i in range(3)])
    tangent=normalize(cross(smooth,[0,1,0] if abs(smooth[1])<.9 else [1,0,0]))
    points.append(p);normals.append(smooth);tangents.append(tangent+[1])
    if explicit:uv.append([float(explicit[corner][0]),float(explicit[corner][1])])
    elif abs(n[1])>.75:uv.append([p[0]*4,p[2]*4])
    elif abs(n[0])>abs(n[2]):uv.append([-p[2]*4,p[1]*4])
    else:uv.append([p[0]*4,p[1]*4])
  attrs={'POSITION':add(points,'VEC3',3),'NORMAL':add(normals,'VEC3',3),'TANGENT':add(tangents,'VEC4',4),'TEXCOORD_0':add(uv,'VEC2',2),'COLOR_0':add([[1]*4]*len(points),'VEC4',4),'COLOR_1':add([[1]*4]*len(points),'VEC4',4)}
  label=f'submesh_{index:02d}_LOD_1';doc['meshes'].append({'name':label,'primitives':[{'attributes':attrs,'indices':add(range(len(points)),'SCALAR',1,True),'mode':4}]});doc['nodes'].append({'name':label,'mesh':index});doc['scenes'][0]['nodes'].append(index)
 doc['buffers'][0]['byteLength']=len(data);j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);data.extend(b'\0'*((-len(data))%4));payload=struct.pack('<II',len(j),0x4e4f534a)+j+struct.pack('<II',len(data),0x004e4942)+data
 path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(struct.pack('<III',0x46546c67,2,len(payload)+12)+payload)
 return list(groups)
def cn(value):return {'$type':'CName','$storage':'string','$value':value}
def ref(value):return {'DepotPath':{'$type':'ResourcePath','$storage':'string','$value':value},'Flags':'Default'}
def art_material(key):
 """A `cy:` art material: pack texture or engine white, linear colour scale."""
 texture,colour,rough,metal=load_art().MATERIALS[key]
 def linear(value):
  value=value/255
  return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
 c=[linear(int(colour[i:i+2],16)) for i in (1,3,5)]
 def v(name,typ,value):return {'$type':typ,name:value}
 path=DEPOT+'\\textures\\'+texture+'.xbm' if texture else WHITE_TEXTURE
 return {'$type':'CMaterialInstance','baseMaterial':ref('engine\\materials\\metal_base.remt'),'values':[v('BaseColor','rRef:ITexture',ref(path)),v('BaseColorScale','Vector4',{'$type':'Vector4','X':c[0],'Y':c[1],'Z':c[2],'W':1}),v('RoughnessScale','Float',rough),v('MetalnessScale','Float',metal)],'enableMask':0,'resourceVersion':4,'cookingPlatform':'PLATFORM_PC'}
def material(color):
 if isinstance(color,str) and color.startswith('cy:'):return art_material(color)
 if color==WHITE:texture='wood_ivory';c=[1,1,1]
 elif color==BLACK:texture='wood_ebony';c=[1,1,1]
 else:
  texture='wood_natural' if color in (NATURAL,WOOD_FRAME,BOARD_DARK) else 'wood_grain'
  base=(140,89,47) if texture=='wood_natural' else (220,220,220)
  def linear(value):
   value=value/255
   return value/12.92 if value<=.04045 else ((value+.055)/1.055)**2.4
  c=[linear(int(color[i:i+2],16))/linear(b) for i,b in zip((1,3,5),base)]
 def v(name,typ,value):return {'$type':typ,name:value}
 return {'$type':'CMaterialInstance','baseMaterial':ref('engine\\materials\\metal_base.remt'),'values':[v('BaseColor','rRef:ITexture',ref(DEPOT+'\\textures\\'+texture+'.xbm')),v('BaseColorScale','Vector4',{'$type':'Vector4','X':c[0],'Y':c[1],'Z':c[2],'W':1}),v('RoughnessScale','Float',.67),v('MetalnessScale','Float',0)],'enableMask':0,'resourceVersion':4,'cookingPlatform':'PLATFORM_PC'}
def mesh_json(donor,colors,faces):
 obj=copy.deepcopy(donor);r=obj['Data']['RootChunk'];mats=[material(c) for c in colors]
 r['localMaterialBuffer']['materials']=mats;r['localMaterialBuffer']['rawData']['Data']['Files']=[{'Version':195,'BuildVersion':0,'RootChunk':m} for m in mats];r['localMaterialBuffer']['rawDataHeaders']=[]
 r['materialEntries']=[{'$type':'CMeshMaterialEntry','index':i,'isLocalInstance':1,'name':cn(f'tabletop_{i}')} for i in range(len(mats))]
 r['appearances']=[{'HandleId':'100','Data':{'$type':'meshMeshAppearance','name':cn('default'),'chunkMaterials':[cn(f'tabletop_{i}') for i in range(len(mats))],'tags':[]}}]
 for key in ('boneNames','boneRigMatrices','boneVertexEpsilons','floatTrackNames','lodBoneMask','externalMaterials','inplaceResources','localMaterialInstances','preloadExternalMaterials','preloadLocalMaterialInstances','parameters'):r[key]=[]
 r['objectType']='ROT_Static'
 r['geometryHash']=str(int.from_bytes(hashlib.sha256(json.dumps(faces,separators=(',',':')).encode()).digest()[:8],'little'))
 projected=[0.,0.,0.]
 for face in faces:
  a,b,c=(face[k] for k in ('a','b','c'))
  normal=cross([b[i]-a[i] for i in range(3)],[c[i]-a[i] for i in range(3)])
  for i in range(3):projected[i]+=abs(normal[i])/2
 r['surfaceAreaPerAxis']={'$type':'Vector3',**dict(zip(('X','Y','Z'),projected))}
 r['isShadowMesh']=0;r['isPlayerShadowMesh']=0
 return obj

def entity_json(template,name,index):
 obj=copy.deepcopy(template);r=obj['Data']['RootChunk'];ident=str(8200000000000000000+index)
 transform={'$type':'WorldTransform','Orientation':{'$type':'Quaternion','i':0,'j':0,'k':0,'r':1},'Position':{'$type':'WorldPosition',**{a:{'$type':'FixedPoint','Bits':0} for a in ('x','y','z')}}}
 component={'$type':'entMeshComponent','name':cn('tabletop_mesh'),'id':ident,'isEnabled':1,'isReplicable':0,'mesh':ref(DEPOT+'\\'+name+'.mesh'),'meshAppearance':cn('default'),'chunkMask':'18446744073709551615','localTransform':transform,'castShadows':'Always','castLocalShadows':'Always','forceLODLevel':-1,'LODMode':'AlwaysVisible','renderingPlane':'RPl_Scene','renderSceneLayerMask':'Default','parentTransform':None}
 entity={'$type':'entEntity'}
 r['entity']={'HandleId':'1','Data':copy.deepcopy(entity)};r['components']=[copy.deepcopy(component)]
 r['compiledData']['Data']['Chunks']=[copy.deepcopy(entity),copy.deepcopy(component)];r['compiledData']['Data']['CruidDict']={'0':'0','1':ident}
 r['appearances']=[];r['defaultAppearance']=cn('default');r['resolvedDependencies']=[];r['includes']=[];r['inplaceResources']=[]
 return obj

def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--lab',type=Path,default=LAB);parser.add_argument('--work',type=Path,default=Path('/tmp/board-game-props/build'));args=parser.parse_args()
 lab=args.lab;work=args.work;tools=lab/'tools';env=os.environ.copy();env['DOTNET_ROOT']=str(tools/'dotnet');env['DOTNET_CLI_HOME']='/tmp/board-game-dotnet'
 def cli(*words,imports=0):
  result=subprocess.run([str(tools/'dotnet/dotnet'),str(tools/'wolvenkit/WolvenKit.CLI.dll'),*map(str,words)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  if '[ 0: Error' in result.stdout or (result.returncode and not(imports and result.stdout.count('Rebuilt with buffers:')==imports)):
   print(result.stdout);raise RuntimeError('WolvenKit command failed '+str(words))
  print('\n'.join(x for x in result.stdout.splitlines() if 'Success' in x),flush=True)
 donor=json.loads((lab/'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_text())
 hostdir=work/'host-schema';hostdir.mkdir(parents=True,exist_ok=True)
 host=Path('/home/dop42/opx_pool_assets/assets/hosts/open77/assets/opx_infinity/pool/ball_01.ent')
 cli('convert','serialize',host,'-o',hostdir)
 template=json.loads((hostdir/'ball_01.ent.json').read_text())
 # Stale cooked files from an earlier build would be packed too: start clean.
 for stale in ('raw','json','texture-json','archive','verified','packed'):shutil.rmtree(work/stale,ignore_errors=True)
 models=model_geometry();raw=work/'raw';schemas=work/'json';schemas.mkdir(parents=True,exist_ok=True)
 texture_schemas=work/'texture-json';texture_schemas.mkdir(parents=True,exist_ok=True)
 for old in list((RESOURCE/'sources').glob('cy_*.png')):old.unlink()
 textures=art_textures(texture_schemas)
 col=load_collision();colliders=[]
 for i,(name,boxes) in enumerate(collider_boxes(col).items()):
  (schemas/(col.collider_name(name)+'.ent.json')).write_text(json.dumps(col.collider_entity_json(template,boxes,i)))
  colliders.append({'name':col.collider_name(name),'for':name,'entity':DEPOT+'\\'+col.collider_name(name)+'.ent','scaleBaked':col.SCALE,'boxes':[{'size':list(b.size),'center':list(b.center)} for b in boxes]})
 records=[]
 for index,(name,faces) in enumerate(models.items()):
  colors=glb(raw/(name+'.mesh.glb'),faces)
  (schemas/(name+'.mesh.json')).write_text(json.dumps(mesh_json(donor,colors,faces)))
  (schemas/(name+'.ent.json')).write_text(json.dumps(entity_json(template,name,index)))
  records.append({'name':name,'mesh':DEPOT+'\\'+name+'.mesh','entity':DEPOT+'\\'+name+'.ent','triangles':len(faces),'materials':colors,'bounds':{'min':[min(t[k][i] for t in faces for k in ('a','b','c')) for i in range(3)],'max':[max(t[k][i] for t in faces for k in ('a','b','c')) for i in range(3)]}})
 archive=work/'archive';target=archive/DEPOT.replace('\\','/');target.mkdir(parents=True,exist_ok=True)
 cli('convert','deserialize',schemas,'-o',target)
 (target/'textures').mkdir(exist_ok=True)
 cli('convert','deserialize',texture_schemas,'-o',target/'textures')
 cli('import',*[raw/(name+'.mesh.glb') for name in models],'-o',target,'--keep',imports=len(models))
 verified=work/'verified';verified.mkdir(parents=True,exist_ok=True);cli('convert','serialize',archive,'-o',verified)
 packed=work/'packed';packed.mkdir(parents=True,exist_ok=True);cli('pack',archive,'-o',packed)
 source=packed/'archive.archive';assert source.read_bytes()[:4]==b'RDAR'
 output=RESOURCE/'dist/open77_board_games.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_board_games.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,source.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 art=load_art()
 manifest={'version':'2.0.0','style':'original Night City art: lacquered gunmetal and carbon boards with chrome bevels and neon inlays; pearl/chrome vs onyx/gunmetal chess and checkers with cyan/magenta accents; gunmetal Connect Four frame with red and yellow machined discs','namespace':DEPOT,'models':records,'textures':textures,'colliders':colliders,'pieceHeights':art.PIECE_HEIGHTS,'checkerHeights':art.CHECKER_HEIGHTS,'materials':{k:{'texture':v[0],'color':v[1],'roughness':v[2],'metalness':v[3]} for k,v in art.MATERIALS.items()},'files':files,'archiveSha256':hashlib.sha256(source.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'sourceMeshSchemaSha256':hashlib.sha256((lab/'donor/oni-json/v_sportbike13_methodd_oni__ext01_body_01.mesh.json').read_bytes()).hexdigest(),'materialDependencies':['engine\\materials\\metal_base.remt',WHITE_TEXTURE]}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('COOKED',len(models),'native meshes/entities,',len(colliders),'colliders,',len(textures),'textures,',output.stat().st_size,'ZIP bytes',flush=True)
 # Verify the package, the index and the WolvenKit round trip of this build.
 s=importlib.util.spec_from_file_location('board_game_prop_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(s);s.loader.exec_module(checks)
 checks.verify(work)
if __name__=='__main__':main()
