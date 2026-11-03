"""Optional offline geometry/material preview; needs NumPy and Pillow, not the game."""
from pathlib import Path
import importlib.util,math
import numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[5];s=importlib.util.spec_from_file_location('builder',root/'tools/build-board-game-props.py');b=importlib.util.module_from_spec(s);s.loader.exec_module(b)
models=b.model_geometry();folder=b.RESOURCE/'sources';textures={p.stem:np.asarray(Image.open(p).convert('RGB'),float)/255 for p in folder.glob('wood_*.png')}
materials={}
for fs in models.values():
 for f in fs:
  col=f['color']
  if col not in materials:
   vals=b.material(col)['values'];path=vals[0]['BaseColor']['DepotPath']['$value'];name=path.rsplit('\\',1)[-1][:-4];scale=vals[1]['BaseColorScale'];materials[col]=(textures[name],np.array([scale[k] for k in ['X','Y','Z']]))
def unit(v):v=np.array(v,float);return v/np.linalg.norm(v)
eye=unit([.8,-1.5,1.1]);right=unit(np.cross([0,0,1],eye));up=np.cross(eye,right);light=unit([-.5,-.8,1.6])
def render(name,w=200,h=270):
 image=np.zeros((h,w,3),np.uint8);image[:]=[230,225,215];depth=np.full((h,w),-1e8)
 for face in models[name]:
  p=np.array([face[k] for k in ['a','b','c']]);n=np.cross(p[1]-p[0],p[2]-p[0]);n/=np.linalg.norm(n)
  if np.dot(n,eye)<=0:continue
  q=np.stack((p@right*1750+w/2,-p@up*1750+h-35),axis=1);z=p@eye
  lo=np.maximum(np.floor(q.min(0)).astype(int),0);hi=np.minimum(np.ceil(q.max(0)).astype(int),[w-1,h-1])
  if np.any(hi<lo):continue
  xx,yy=np.meshgrid(np.arange(lo[0],hi[0]+1)+.5,np.arange(lo[1],hi[1]+1)+.5)
  den=(q[1,1]-q[2,1])*(q[0,0]-q[2,0])+(q[2,0]-q[1,0])*(q[0,1]-q[2,1])
  if abs(den)<1e-8:continue
  a=((q[1,1]-q[2,1])*(xx-q[2,0])+(q[2,0]-q[1,0])*(yy-q[2,1]))/den
  c=((q[2,1]-q[0,1])*(xx-q[2,0])+(q[0,0]-q[2,0])*(yy-q[2,1]))/den;d=1-a-c
  zz=a*z[0]+c*z[1]+d*z[2];old=depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1];mask=(a>=0)&(c>=0)&(d>=0)&(zz>old)
  if not mask.any():continue
  if abs(n[2])>.75:uv=p[:,[0,1]]*np.array([4,-4])
  elif abs(n[0])>abs(n[1]):uv=p[:,[1,2]]*4
  else:uv=p[:,[0,2]]*4
  u=(a*uv[0,0]+c*uv[1,0]+d*uv[2,0])%1;v=(a*uv[0,1]+c*uv[1,1]+d*uv[2,1])%1
  tex,scale=materials[face['color']];rgb=tex[(v*256).astype(int)%256,(u*256).astype(int)%256];linear=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)*scale*(.36+.64*max(0,np.dot(n,light)))
  rgb=np.where(linear<=.0031308,linear*12.92,1.055*np.maximum(linear,0)**(1/2.4)-.055);rgb=np.clip(rgb*255,0,255).astype(np.uint8)
  area=image[lo[1]:hi[1]+1,lo[0]:hi[0]+1];area[mask]=rgb[mask];old[mask]=zz[mask]
 return Image.fromarray(image)
canvas=Image.new('RGB',(1200,640),(230,225,215));draw=ImageDraw.Draw(canvas)
names=['pawn','rook','knight','bishop','queen','king']
for y,side in enumerate(['white','black']):
 for x,kind in enumerate(names):
  canvas.paste(render('chess_'+side+'_'+kind),(x*200,35+y*300));draw.text((x*200+70,305+y*300),kind.upper(),fill=(53,39,27))
draw.text((20,12),'ORIGINAL CARVED WOOD ASSETS - offline geometry/material preview, not an in-game capture',fill=(53,39,27))
canvas.save(folder/'carved-chess-preview.png');print(folder/'carved-chess-preview.png')
