#!/usr/bin/env python3
"""Cook original roulette, double-six dominoes and authored card-tower poses.

Uses the existing native board-prop cooker as a read-only schema/tool library.
Only this resource and --work receive outputs. Requires Pillow for original
number/card artwork, .NET and WolvenKit from the inspected local lab.
"""
import argparse,base64,copy,hashlib,importlib.util,json,math,os,random,struct,subprocess,zipfile
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
RESOURCE=ROOT/'resources/assets/models/open77_tabletop_extra'
DEPOT='open77\\assets\\op77_lightrp\\tabletop_extra'
LAB=ROOT.parent/'dop-tests'
ORDER=[0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26]
REDS={1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36}
GREEN,RED,BLACK,BRASS,BALL='#174C32FF','#A82025FF','#12110FFF','#B79048FF','#FFFFFDFF'
NUMBER,CARD_FRONT,CARD_BACK='#242424FF','#FCFCF5FF','#8E1820FF'
FONT=Path('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf')
spec=importlib.util.spec_from_file_location('native_boards',ROOT/'tools/build-board-game-props.py');base=importlib.util.module_from_spec(spec);spec.loader.exec_module(base)
base.RESOURCE=RESOURCE;base.DEPOT=DEPOT
g=base.load_generator()


def quad(out,points,c,uv=None):
 for ids in ((0,1,2),(0,2,3)):
  f={'a':points[ids[0]],'b':points[ids[1]],'c':points[ids[2]],'color':c}
  if uv is not None:f['uv']=[uv[i] for i in ids]
  out.append(f)

def ring(out,profile,c,sides=128):g.lathe(out,profile,c,sides)

def bevel_box(out,w,h,z,t,c,bevel=.002):
 """Closed rectangular solid with chamfered top/bottom edges and rounded corners."""
 corner=min(w,h)*.10;n=8;rings=[]
 for zz,shrink in ((z,bevel),(z+bevel,0),(z+t-bevel,0),(z+t,bevel)):
  row=[]
  for cx,cy,start in ((w/2-corner,h/2-corner,0),(-w/2+corner,h/2-corner,90),(-w/2+corner,-h/2+corner,180),(w/2-corner,-h/2+corner,270)):
   for i in range(n+1):
    a=math.radians(start+i*90/n);rr=max(.00005,corner-shrink)
    row.append([cx+rr*math.cos(a),cy+rr*math.sin(a),zz])
  rings.append(row)
 for a,b in zip(rings,rings[1:]):
  for i in range(len(a)):j=(i+1)%len(a);quad(out,[a[i],a[j],b[j],b[i]],c)
 for i in range(len(rings[0])):
  j=(i+1)%len(rings[0]);g.tri(out,[0,0,z],rings[0][j],rings[0][i],c);g.tri(out,[0,0,z+t],rings[-1][i],rings[-1][j],c)

def carpet_board():
 out=[];bevel_box(out,1,.75,-.028,.028,base.WOOD_FRAME,.004)
 # Inset felt top with a narrow, visible wooden rim.
 quad(out,[[-.47,-.345,.001],[.47,-.345,.001],[.47,.345,.001],[-.47,.345,.001]],GREEN)
 return out

def roulette_table():
 out=[]
 ring(out,[(0,-.045),(.39,-.045),(.414,-.034),(.42,-.020),(.42,-.002),(.409,.008),(.395,.008),(.388,0),(0,0)],base.WOOD_FRAME)
 # Static bowl/ball race surrounds the independent moving rotor.
 ring(out,[(.320,.001),(.323,.001),(.342,.014),(.37,.049),(.389,.057),(.397,.048),(.397,.032),(.390,.022),(.376,.020),(.35,.003),(.320,.001)],base.NATURAL)
 ring(out,[(.397,.008),(.409,.008),(.409,.010),(.397,.010),(.397,.008)],GREEN)
 ring(out,[(.388,.055),(.391,.055),(.391,.058),(.388,.058),(.388,.055)],BRASS)
 return out

def roulette_wheel():
 out=[]
 ring(out,[(0,0),(.315,0),(.32,.003),(.32,.014),(.316,.017),(.290,.017),(.290,.016),(.235,.016),(.226,.022),(.20,.039),(.12,.063),(0,.066)],base.NATURAL)
 # Accurate 37-pocket color order, with full annular top artwork for the labels.
 for i,number in enumerate(ORDER):
  start=(i-.5)*math.tau/37;end=(i+.5)*math.tau/37
  color=GREEN if number==0 else RED if number in REDS else BLACK
  def p(r,a,z):return [r*math.sin(a),r*math.cos(a),z]
  # Clockwise angular order means reverse these top faces for +Z winding.
  quad(out,[p(.235,start,.0162),p(.235,end,.0162),p(.290,end,.0162),p(.290,start,.0162)],color)
  faces=[]
  for j in range(3):
   a=start+(end-start)*j/3;b=start+(end-start)*(j+1)/3
   pts=[p(.290,a,.0173),p(.290,b,.0173),p(.319,b,.0173),p(.319,a,.0173)]
   uv=[[.5+x/.64,.5-y/.64] for x,y,z in pts];quad(out,pts,NUMBER,uv)
  # Narrow metal dividers extend only across the recessed pocket ring.
  a=start;ux,uy=math.sin(a),math.cos(a);tx,ty=math.cos(a),-math.sin(a)
  pts=[]
  for z in (.016,.028):
   for r,t in ((.235,-.00065),(.290,-.00065),(.290,.00065),(.235,.00065)):
    pts.append([r*ux+t*tx,r*uy+t*ty,z])
  for face in ((0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)):quad(out,[pts[k] for k in face],BRASS)
 ring(out,[(.231,.017),(.235,.017),(.235,.023),(.231,.023),(.231,.017)],BRASS)
 ring(out,[(0,.063),(.027,.063),(.030,.071),(.024,.078),(.012,.082),(.010,.112),(0,.114)],BRASS,64)
 # Traditional four-spoke rotor handle, each with a turned wooden grip.
 for a in (0,math.pi/2,math.pi,3*math.pi/2):
  part=[];g.box(part,0,.070,.087,.008,.12,.008,BRASS)
  # The grip is a small smooth sphere from the native helper.
  base.sphere(g,part,(0,.124,.087),.012,base.NATURAL)
  for f in part:
   for key in ('a','b','c'):
    x,y,z=f[key];f[key]=[x*math.cos(a)-y*math.sin(a),x*math.sin(a)+y*math.cos(a),z]
  out.extend(part)
 return out

PIPS={0:[],1:[(0,0)],2:[(-1,-1),(1,1)],3:[(-1,-1),(0,0),(1,1)],4:[(-1,-1),(-1,1),(1,-1),(1,1)],5:[(-1,-1),(-1,1),(0,0),(1,-1),(1,1)],6:[(-1,-1),(-1,0),(-1,1),(1,-1),(1,0),(1,1)]}
def domino(a,b):
 out=[];bevel_box(out,.026,.052,0,.008,base.WHITE,.00075)
 # Dark fine inlay separates the two halves without an oversized black stripe.
 g.box(out,0,0,.00804,.021,.00048,.00010,BLACK)
 for number,cy in ((a,-.013),(b,.013)):
  for px,py in PIPS[number]:
   cx,yy=px*.006,cy+py*.006
   for i in range(24):
    aa=i*math.tau/24;bb=(i+1)*math.tau/24
    g.tri(out,[cx,yy,.00813],[cx+.0017*math.cos(aa),yy+.0017*math.sin(aa),.00813],[cx+.0017*math.cos(bb),yy+.0017*math.sin(bb),.00813],BLACK)
 return out

def card():
 out=[];x,y,z=.044,.0315,.00025;radius=.0026;outline=[]
 for cx,cy,start in ((x-radius,y-radius,0),(-x+radius,y-radius,90),(-x+radius,-y+radius,180),(x-radius,-y+radius,270)):
  for i in range(9):
   a=math.radians(start+i*90/8);outline.append([cx+radius*math.cos(a),cy+radius*math.sin(a)])
 def uv(p,back=False):return [.5+(p[1]/.063 if back else -p[1]/.063),.5-p[0]/.088]
 for i,a in enumerate(outline):
  bb=outline[(i+1)%len(outline)]
  out.append({'a':[0,0,z],'b':[a[0],a[1],z],'c':[bb[0],bb[1],z],'color':CARD_FRONT,'uv':[uv([0,0]),uv(a),uv(bb)]})
  out.append({'a':[0,0,-z],'b':[bb[0],bb[1],-z],'c':[a[0],a[1],-z],'color':CARD_BACK,'uv':[uv([0,0],True),uv(bb,True),uv(a,True)]})
  quad(out,[[a[0],a[1],-z],[bb[0],bb[1],-z],[bb[0],bb[1],z],[a[0],a[1],z]],base.WHITE)
 return out

def leaned_card(angle,side):
 out=copy.deepcopy(card());a=math.radians(angle);sign=1 if side=='left' else -1
 for f in out:
  for key in ('a','b','c'):
   x,y,z=f[key];x+=.044
   f[key]=[sign*(x*math.cos(a)-z*math.sin(a)),y,x*math.sin(a)+z*math.cos(a)]
  if sign<0:
   f['b'],f['c']=f['c'],f['b']
   if 'uv' in f:f['uv'][1],f['uv'][2]=f['uv'][2],f['uv'][1]
 return out

def models():
 result={'roulette_table':roulette_table(),'roulette_wheel':roulette_wheel(),'dominos_board':carpet_board(),'cardtower_board':[]}
 bevel_box(result['cardtower_board'],1,.75,-.025,.025,base.NATURAL,.003)
 ball=[];base.sphere(g,ball,(0,0,0),.009,BALL);result['roulette_ball']=ball
 for a in range(7):
  for b in range(a,7):result[f'domino_{a}_{b}']=domino(a,b)
 result['playing_card']=card();result['playing_card_flat']=card()
 angle=math.degrees(math.acos(.026/.088))
 for side in ('left','right'):
  result['playing_card_lean_'+side]=leaned_card(angle,side)
  for step in range(1,6):result[f'playing_card_lean_{side}_fall_{step}']=leaned_card(angle*(1-step/5),side)
 return result


def font(size):return ImageFont.truetype(str(FONT),size)
def spade(draw,cx,cy,size,fill):
 # A smooth original four-Bezier spade silhouette, rather than a stock icon.
 curves=[((0,-.65),(-.14,-.42),(-.64,-.10),(-.50,.20)),
         ((-.50,.20),(-.40,.45),(-.10,.40),(0,.18)),
         ((0,.18),(.10,.40),(.40,.45),(.50,.20)),
         ((.50,.20),(.64,-.10),(.14,-.42),(0,-.65))]
 points=[]
 for a,b,c,d in curves:
  for i in range(17):
   t=i/16;s=1-t
   xx=s*s*s*a[0]+3*s*s*t*b[0]+3*s*t*t*c[0]+t*t*t*d[0]
   yy=s*s*s*a[1]+3*s*s*t*b[1]+3*s*t*t*c[1]+t*t*t*d[1]
   points.append((cx+xx*size,cy+yy*size))
 draw.polygon(points,fill=fill)
 draw.polygon([(cx,cy+.10*size),(cx-.07*size,cy+.39*size),(cx-.16*size,cy+.54*size),(cx+.16*size,cy+.54*size),(cx+.07*size,cy+.39*size)],fill=fill)

def artwork():
 result={}
 im=Image.new('RGBA',(1024,1024),(45,30,19,255));d=ImageDraw.Draw(im)
 for i,num in enumerate(ORDER):
  a=(i-.5)*360/37;b=(i+.5)*360/37;c=(31,100,61,255) if num==0 else (153,28,31,255) if num in REDS else (22,20,18,255)
  d.pieslice((0,0,1023,1023),start=a-90,end=b-90,fill=c)
  # 2-digit labels use a true atlas, not a floating UI overlay.
  label=Image.new('RGBA',(90,90));dd=ImageDraw.Draw(label);dd.text((45,45),str(num),font=font(23),anchor='mm',fill=(247,239,214,255))
  angle=i*360/37;label=label.rotate(-angle,resample=Image.Resampling.BICUBIC)
  x=512+math.sin(math.radians(angle))*488;y=512-math.cos(math.radians(angle))*488
  im.alpha_composite(label,(round(x-45),round(y-45)))
 result['roulette_numbers']=im
 im=Image.new('RGBA',(512,768),(247,245,234,255));d=ImageDraw.Draw(im)
 d.rounded_rectangle((8,8,503,759),radius=25,outline=(204,199,182,255),width=2)
 d.text((37,27),'A',font=font(70),fill=(19,18,16,255));spade(d,61,133,35,(19,18,16,255));spade(d,256,387,167,(19,18,16,255))
 corner=Image.new('RGBA',(100,170));dd=ImageDraw.Draw(corner);dd.text((11,0),'A',font=font(70),fill=(19,18,16,255));spade(dd,36,106,35,(19,18,16,255));im.alpha_composite(corner.rotate(180),(405,590));result['card_face']=im
 im=Image.new('RGBA',(512,768),(244,235,216,255));d=ImageDraw.Draw(im)
 d.rounded_rectangle((22,22,489,745),radius=23,fill=(144,25,34,255),outline=(122,20,27,255),width=4)
 d.rounded_rectangle((36,36,475,731),radius=15,outline=(242,211,177,255),width=3)
 for y in range(50,725,22):
  for x in range(48,470,22):d.polygon([(x,y-7),(x+7,y),(x,y+7),(x-7,y)],outline=(219,149,130,255),width=1)
 d.ellipse((170,294,342,474),fill=(144,25,34,255),outline=(242,211,177,255),width=4);d.ellipse((181,305,331,463),outline=(242,211,177,255),width=2);spade(d,256,385,80,(242,211,177,255));result['card_back']=im
 rng=random.Random(77177);im=Image.new('RGBA',(256,256));px=[]
 for y in range(256):
  for x in range(256):
   v=.90+.06*math.cos(x*math.pi)+.04*math.cos(y*math.pi)+rng.uniform(-.05,.05);px.append((round(25*v),round(76*v),round(48*v),255))
 im.putdata(px);result['felt_green']=im
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

def material(color):
 if color in (NUMBER,CARD_FRONT,CARD_BACK,GREEN):
  name={NUMBER:'roulette_numbers',CARD_FRONT:'card_face',CARD_BACK:'card_back',GREEN:'felt_green'}[color]
  result=ORIGINAL_MATERIAL(base.WHITE)
  result['values'][0]['BaseColor']=base.ref(DEPOT+'\\textures\\'+name+'.xbm');result['values'][1]['BaseColorScale'].update(X=1,Y=1,Z=1)
  result['values'][2]['RoughnessScale']=.9 if color==GREEN else .42 if color in (CARD_FRONT,CARD_BACK) else .5
  return result
 if color in (BRASS,BALL):
  result=ORIGINAL_MATERIAL(base.WHITE);result['values'][0]['BaseColor']=base.ref('engine\\textures\\editor\\white.xbm')
  c=[int(color[i:i+2],16)/255 for i in (1,3,5)];result['values'][1]['BaseColorScale'].update(X=c[0],Y=c[1],Z=c[2]);result['values'][2]['RoughnessScale']=.30 if color==BRASS else .16;result['values'][3]['MetalnessScale']=.78 if color==BRASS else 0
  return result
 return ORIGINAL_MATERIAL(color)
base.material=material

def glb(path,faces):
 colors=base.glb(path,faces)
 # Preserve explicit UVs for labels and both authored card faces, after the
 # shared cooker has generated positions, smoothed normals and white COLOR0/1.
 raw=bytearray(path.read_bytes());json_length=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+json_length]);binary=28+json_length;groups={}
 for face in faces:groups.setdefault(face['color'],[]).append(face)
 for mi,group in enumerate(groups.values()):
  accessor=doc['accessors'][doc['meshes'][mi]['primitives'][0]['attributes']['TEXCOORD_0']];view=doc['bufferViews'][accessor['bufferView']];start=binary+view.get('byteOffset',0)+accessor.get('byteOffset',0)
  for i,face in enumerate(group):
   if 'uv' in face:
    for j,uv in enumerate(face['uv']):struct.pack_into('<ff',raw,start+(i*3+j)*8,*uv)
 path.write_bytes(raw);return colors


def verify(work,manifest):
 """Independent cooked-file, namespace, package-index and authored-pose checks."""
 spec=importlib.util.spec_from_file_location('archive_checks',ROOT/'tools/test-board-game-props.py');checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(checks)
 archive=work/'archive';verified=work/'verified';packed=(work/'packed/archive.archive').read_bytes()
 entries=checks.archive_entries(packed);files=manifest['files']
 assert len(entries)==len(files)==102 and len(manifest['models'])==47 and len(manifest['textures'])==8
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
     if model['materials'][chunk_index] in (NUMBER,CARD_FRONT,CARD_BACK):
      assert all(-.001<=v<=1.001 for pair in values for v in pair),(name,'atlas/card UV out of bounds')
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
  assert data[:image.width*image.height*4]==image.tobytes() and all(v==255 for v in data[3::4])
 by_name={m['name']:m for m in manifest['models']}
 assert set(ORDER)==set(range(37)) and len(ORDER)==37
 for a in range(7):
  for b in range(a,7):assert f'domino_{a}_{b}' in by_name
 assert abs(by_name['roulette_ball']['bounds']['max'][2]-.009)<1e-6
 for side,sign in (('left',1),('right',-1)):
  model=by_name['playing_card_lean_'+side];assert abs(model['bounds']['max'][2]-manifest['cardLeanHeight'])<.0003
  final=by_name[f'playing_card_lean_{side}_fall_5']['bounds']
  assert abs((final['min'][0]+final['max'][0])/2-sign*.044)<1e-6
 assert manifest['cardFallAngles'][0]>72 and manifest['cardFallAngles'][-1]==0
 with zipfile.ZipFile(RESOURCE/'dist/open77_tabletop_extra.zip') as z:
  assert z.testzip() is None and z.namelist()==['archive/pc/mod/0_open77_tabletop_extra.archive']
  assert z.read(z.namelist()[0])==packed
 print('VERIFIED: 47 native props, 8 opaque mipmapped textures, 102 exact RDAR entries, geometry/bindings/poses/package hashes',flush=True)


def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--lab',type=Path,default=LAB);p.add_argument('--work',type=Path,default=Path('/tmp/tabletop-extra-props/build'));p.add_argument('--verify-only',action='store_true');a=p.parse_args();work=a.work
 if a.verify_only:
  verify(work,json.loads((RESOURCE/'asset-manifest.json').read_text()));return
 tools=a.lab/'tools';env=os.environ.copy();env['DOTNET_ROOT']=str(tools/'dotnet');env['DOTNET_CLI_HOME']='/tmp/tabletop-extra-dotnet'
 def cli(*args,imports=0):
  result=subprocess.run([str(tools/'dotnet/dotnet'),str(tools/'wolvenkit/WolvenKit.CLI.dll'),*map(str,args)],env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
  if '[ 0: Error' in result.stdout or (result.returncode and not(imports and result.stdout.count('Rebuilt with buffers:')==imports)):print(result.stdout);raise RuntimeError('WolvenKit failed '+str(args))
  print('\n'.join(line for line in result.stdout.splitlines() if 'Success' in line),flush=True)
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
 cooked=packed/'archive.archive';assert cooked.read_bytes()[:4]==b'RDAR';output=RESOURCE/'dist/open77_tabletop_extra.zip';output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  info=zipfile.ZipInfo('archive/pc/mod/0_open77_tabletop_extra.archive',(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o100644<<16;z.writestr(info,cooked.read_bytes())
 files=[{'depot':str(p.relative_to(archive)).replace('/','\\'),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size} for p in sorted(archive.rglob('*')) if p.is_file()]
 manifest={'version':'1.0.0','namespace':DEPOT,'models':records,'textures':textures,'files':files,'rouletteOrder':ORDER,'roulettePocketRadius':.27,'rouletteBallCenterZ':.025,'cardLeanHorizontal':.026,'cardLeanHeight':math.sqrt(.088**2-.026**2),'cardFallAngles':[math.degrees(math.acos(.026/.088))*(1-step/5) for step in range(6)],'archiveSha256':hashlib.sha256(cooked.read_bytes()).hexdigest(),'zipSha256':hashlib.sha256(output.read_bytes()).hexdigest(),'buildWork':str(work),'materialDependencies':['engine\\materials\\metal_base.remt','engine\\textures\\editor\\white.xbm']}
 (RESOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('COOKED',len(records),'models,',len(textures),'textures,',len(files),'native files, ZIP',output.stat().st_size,'bytes',flush=True)
 verify(work,manifest)
if __name__=='__main__':main()
