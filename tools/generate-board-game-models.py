#!/usr/bin/env python3
"""Build deterministic metre-scale triangulated tabletop models; no external tools.

Runtime is Open77.debugDraw (solid triangles), not props/create or RED4 meshes.
OBJ sources share exactly the same coordinates and can be edited in a DCC.
"""
from pathlib import Path
import argparse
import json
import math

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'resources/gamemodes/op77_lightrp'
IVORY, DARK = '#EDE4CEFF', '#263641FF'
LIGHT_SQUARE, DARK_SQUARE, FRAME = '#CDB995FF', '#495663FF', '#171F2AFF'
GOLD = '#D9A75EFF'
CONNECT_BLUE, CONNECT_RED, CONNECT_YELLOW = '#1261C9FF', '#F04D4DFF', '#FFD34DFF'


def tri(out, a, b, c, color):
    out.append(dict(a=a, b=b, c=c, color=color))


def quad(out, a, b, c, d, color):
    tri(out, a, b, c, color)
    tri(out, a, c, d, color)


def box(out, x, y, z, sx, sy, sz, color):
    p = [[x + a*sx/2, y + b*sy/2, z + c*sz/2]
         for c in (-1, 1) for b in (-1, 1) for a in (-1, 1)]
    for face in ((0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)):
        quad(out, *(p[i] for i in face), color)


def lathe(out, profile, color, sides=4):
    # Profile from bottom centre, along outer silhouette, to top centre.
    for (r0,z0), (r1,z1) in zip(profile,profile[1:]):
        for i in range(sides):
            a,b = 2*math.pi*i/sides, 2*math.pi*(i+1)/sides
            p=[r0*math.cos(a),r0*math.sin(a),z0]
            q=[r0*math.cos(b),r0*math.sin(b),z0]
            r=[r1*math.cos(b),r1*math.sin(b),z1]
            s=[r1*math.cos(a),r1*math.sin(a),z1]
            if r0 == 0: tri(out,p,r,s,color)
            elif r1 == 0: tri(out,p,q,r,color)
            else: quad(out,p,q,r,s,color)


def board(n):
    out=[]
    box(out,0,0,-.018,1.12,1.12,.036,FRAME)
    for row in range(n):
        for col in range(n):
            x,y=-.5+col/n,-.5+row/n
            quad(out,[x,y,.001],[x+1/n,y,.001],[x+1/n,y+1/n,.001],[x,y+1/n,.001],
                 DARK_SQUARE if (row+col)%2 == 1 else LIGHT_SQUARE)
    # Gold orientation ticks: white home edge, black home edge.
    for y in (-.53,.53): box(out,0,y,.002,.12,.008,.004,GOLD)
    return out


def connect_board():
    """Perforated vertical grid: local XZ, front faces towards negative Y."""
    out = []
    # A square annulus around each circular slot leaves the slot genuinely open.
    # Shared square edges meet; octagons avoid spending vertices on invisible detail.
    for row in range(1, 7):
        for col in range(1, 8):
            cx, cz = (col-4)*.14, (6.5-row)*.14+.04
            outer, inner = [], []
            for i in range(8):
                angle = i*math.pi/4
                dx, dz = math.cos(angle), math.sin(angle)
                edge = .07/max(abs(dx),abs(dz))
                outer.append([cx+edge*dx,-.018,cz+edge*dz])
                inner.append([cx+.055*dx,-.018,cz+.055*dz])
            for i in range(8):
                j = (i+1)%8
                quad(out,outer[i],outer[j],inner[j],inner[i],CONNECT_BLUE)
    # Frame and two stable feet, leaving the circular slots unobstructed.
    for x in (-.51,.51):
        box(out,x,0,.47,.04,.06,.90,CONNECT_BLUE)
        box(out,x,0,.02,.12,.28,.04,FRAME)
    box(out,0,0,.035,1.06,.06,.025,CONNECT_BLUE)
    box(out,0,0,.9,1.06,.06,.025,CONNECT_BLUE)
    return out


def piece(kind, side, game):
    out=[]; color=IVORY if side=='white' else DARK
    if game=='connect4':
        color = CONNECT_RED if side=='white' else CONNECT_YELLOW
        # Build a centred cylinder, then rotate its axis from Z into Y.
        lathe(out,[(0,-.025),(.052,-.025),(.052,.025),(0,.025)],color,8)
        for triangle in out:
            for key in ('a','b','c'):
                x,y,z=triangle[key]
                triangle[key]=[x,-z,y]
        return out
    if game=='checkers':
        lathe(out,[(0,0),(.032,0),(.032,.014),(0,.014)],color,6)
        if kind=='king':
            lathe(out,[(0,.015),(.029,.015),(.029,.029),(0,.029)],color,5)
            lathe(out,[(0,.030),(.018,.030)],GOLD,5)
        return out
    lathe(out,[(0,0),(.034,0),(.034,.012),(.024,.019)],color)
    if kind=='pawn':
        lathe(out,[(.024,.019),(.012,.040),(.021,.053),(.015,.069),(0,.074)],color)
    elif kind=='rook':
        lathe(out,[(.024,.019),(.018,.055),(.030,.062),(.030,.074),(0,.074)],color)
        for x,y,sx,sy in ((-.023,0,.012,.055),(.023,0,.012,.055),(0,-.023,.035,.012),(0,.023,.035,.012)):
            quad(out,[x-sx/2,y-sy/2,.074],[x+sx/2,y-sy/2,.074],[x+sx/2,y+sy/2,.086],[x-sx/2,y+sy/2,.086],color)
    elif kind=='bishop':
        lathe(out,[(.024,.019),(.011,.054),(.024,.062),(.020,.079),(0,.101)],color)
        box(out,.006,0,.084,.003,.043,.010,GOLD)
    elif kind=='knight':
        # Extruded horse-head profile: muzzle points towards +Y.
        profile=[(-.020,.020),(-.017,.060),(-.024,.080),(-.012,.101),(-.006,.087),(.009,.083),(.027,.062),(.025,.051),(.011,.051),(.002,.060),(.004,.026)]
        width=.013
        for i in range(1,len(profile)-1):
            for x in (-width,width):
                tri(out,[x,*profile[0]],[x,*profile[i]],[x,*profile[i+1]],color)
        for i,(y,z) in enumerate(profile):
            yy,zz=profile[(i+1)%len(profile)]
            quad(out,[-width,y,z],[width,y,z],[width,yy,zz],[-width,yy,zz],color)
        box(out,0,.009,.075,.030,.004,.004,GOLD)
    elif kind=='queen':
        lathe(out,[(.024,.019),(.012,.061),(.024,.073),(.030,.091),(.017,.094),(0,.094)],color)
        for i in range(5):
            a=i*2*math.pi/5
            tri(out,[.023*math.cos(a-.18),.023*math.sin(a-.18),.091],[.023*math.cos(a+.18),.023*math.sin(a+.18),.091],[.026*math.cos(a),.026*math.sin(a),.108],GOLD)
    elif kind=='king':
        lathe(out,[(.024,.019),(.012,.064),(.026,.077),(.019,.088),(0,.093)],color)
        box(out,0,0,.105,.009,.009,.030,GOLD)
        box(out,0,0,.110,.030,.009,.009,GOLD)
    return out


def lua(value):
    if isinstance(value,str): return json.dumps(value)
    if isinstance(value,(float,int)): return format(value,'.7g')
    if isinstance(value,list):
        if len(value)==3 and all(isinstance(v,(int,float)) for v in value):
            return '{'+','.join(k+'='+lua(v) for k,v in zip(('x','y','z'),value))+'}'
        separator = ',\n' if value and isinstance(value[0],dict) and 'a' in value[0] else ','
        return '{'+separator.join(lua(v) for v in value)+'}'
    return '{'+','.join(k+'='+lua(v) for k,v in value.items())+'}'


def obj(name, triangles):
    lines=['# Generated original LightRP geometry; metres, Z up.','o '+name]
    for t in triangles:
        for key in ('a','b','c'): lines.append('v '+' '.join(format(v,'.7g') for v in t[key]))
    for i in range(len(triangles)): lines.append('f %d %d %d'%(i*3+1,i*3+2,i*3+3))
    return '\n'.join(lines)+'\n'


def verify_lua(models):
    """Optional runtime regression checks; requires the test dependency lupa."""
    from lupa.lua54 import LuaRuntime
    runtime = LuaRuntime(unpack_returned_tuples=True,max_memory=32*1024*1024)
    runtime.execute('count=0;debug.sethook(function() count=count+1 end,"",1)')
    runtime.execute((OUT/'shared/board_game_models.lua').read_text())
    runtime.execute('debug.sethook()')
    startup = runtime.globals().count
    assert startup < 500, ('eager geometry allocation during activation',startup)
    runtime.execute('function measure(fn) count=0;debug.sethook(function() count=count+1 end,"",1);local value=fn();debug.sethook();return count,value end')
    same=runtime.eval('function(a,b) return rawequal(a,b) end')
    maximum=0
    for name,triangles in models.items():
        if name.endswith('_board'):
            call='LightRpBoardGameModels.board('+json.dumps(name[:-6])+')'
        else:
            game,side,kind=name.split('_',2)
            call='LightRpBoardGameModels.piece('+','.join(map(json.dumps,(kind,side,game)))+')'
        fn=runtime.eval('function() return '+call+' end')
        first,value=runtime.globals().measure(fn)
        cached,again=runtime.globals().measure(fn)
        assert len(value)==len(triangles) and same(value,again)
        assert first<15000 and cached<100,(name,first,cached)
        maximum=max(maximum,first)
    print('Lua lazy geometry checks:',startup,'startup instructions;',maximum,'maximum first-use; cached references identical')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify-lua',action='store_true',help='also test lazy startup and cache under Lua 5.4 using lupa')
    args=parser.parse_args()
    models={'chess_board':board(8),'checkers_board':board(10),'connect4_board':connect_board()}
    for game,kinds in [('chess',('pawn','rook','knight','bishop','queen','king')),('checkers',('man','king')),('connect4',('disc',))]:
        for side in ('white','black'):
            for kind in kinds: models[game+'_'+side+'_'+kind]=piece(kind,side,game)
    dest=OUT/'assets/board_games';dest.mkdir(parents=True,exist_ok=True)
    for name,ts in models.items(): (dest/(name+'.obj')).write_text(obj(name,ts))
    text='-- Generated by tools/generate-board-game-models.py; metres, Z up.\n'
    text+='-- Original solid triangle models rendered by Open77.debugDraw.set.\n'
    text+='-- Mesh tables are immutable: transform into a new world-space batch.\n'
    text+='-- Activation only registers factories; geometry is allocated on first use.\n'
    text+='LightRpBoardGameModels = {}\nlocal cache = {}\nlocal factories = {}\n'
    for name, triangles in models.items():
        text+='factories.'+name+' = function()\n    return '+lua(triangles)+'\nend\n'
    text+='local function model(name)\n'
    text+='    local value = cache[name]\n'
    text+='    if value ~= nil then return value end\n'
    text+='    local build = factories[name]\n'
    text+='    if build == nil then return nil end\n'
    text+='    value = build()\n'
    text+='    cache[name] = value\n'
    text+='    factories[name] = nil\n'
    text+='    return value\nend\n'
    text+='function LightRpBoardGameModels.board(kind) return model(kind .. "_board") end\n'
    text+='function LightRpBoardGameModels.piece(kind, side, gameKind)\n'
    text+='    return model((gameKind or "chess") .. "_" .. side .. "_" .. kind)\nend\n'
    (OUT/'shared/board_game_models.lua').write_text(text)
    # Genuine geometry checks: all triangles finite/nondegenerate and bounds fit cells.
    for name,ts in models.items():
        for t in ts:
            a,b,c=(t[k] for k in ('a','b','c'))
            u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
            cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
            assert sum(x*x for x in cross)>1e-20,(name,t)
            assert all(math.isfinite(x) for p in (a,b,c) for x in p)
        if not name.endswith('_board'):
            bound = .053 if name.startswith('connect4_') else .035
            assert max(abs(v) for t in ts for k in ('a','b','c') for v in t[k][:2])<=bound
    connect_total = len(models['connect4_board'])+42*len(models['connect4_white_disc'])
    assert connect_total < 2200 and connect_total*3 < 8192
    print('Built',len(models),'models;',sum(map(len,models.values())),'triangles; chess board',len(models['chess_board']),'checkers board',len(models['checkers_board']))
    print('Connect Four full board:',connect_total,'triangles,',connect_total*3,'vertices')
    if args.verify_lua: verify_lua(models)

if __name__=='__main__': main()
