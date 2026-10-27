#!/usr/bin/env python3
"""Synthesize original tabletop feedback; standard library only, no sampled audio."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'resources/gamemodes/op77_lightrp/assets/audio/board-games'
RATE = 22050


def impact(length, seed, hits, resonances, noise_decay=.012):
    """Damped modal resonances plus a brief filtered friction transient."""
    rng = random.Random(seed)
    samples=[]
    previous=0.0
    for i in range(round(length*RATE)):
        now=i/RATE
        noise=rng.uniform(-1,1)
        previous=.63*previous+.37*noise
        value=0.0
        for start, gain in hits:
            t=now-start
            if t < 0: continue
            # A 0.5ms attack avoids a discontinuity/click in the PCM boundary.
            attack=min(1,t/.0005)
            modes=sum(a*math.sin(2*math.pi*f*t)*math.exp(-t/decay)
                      for f,a,decay in resonances)
            transient=previous*math.exp(-t/noise_decay)
            value+=gain*attack*(modes+.55*transient)
        samples.append(value)
    return samples


def victory():
    samples=[]
    notes=[(0,523.251),(.14,659.255),(.28,783.991),(.44,1046.502)]
    for i in range(round(.95*RATE)):
        now=i/RATE
        value=0.0
        for start,f in notes:
            t=now-start
            if t<0: continue
            envelope=min(1,t/.008)*math.exp(-t/.14)
            value+=envelope*(math.sin(2*math.pi*f*t)+.18*math.sin(4*math.pi*f*t))
        samples.append(value)
    return samples


def write(name,samples,peak):
    maximum=max(abs(v) for v in samples) or 1
    # Every clip has a quiet tail and a 10ms release to avoid abrupt truncation.
    release=min(round(.010*RATE),len(samples))
    for i in range(release): samples[-release+i]*=(release-i-1)/release
    pcm=[round(max(-1,min(1,v/maximum*peak))*32767) for v in samples]
    path=OUT/(name+'.wav')
    with wave.open(str(path),'wb') as out:
        out.setnchannels(1);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes(struct.pack('<%dh'%len(pcm),*pcm))
    with wave.open(str(path),'rb') as source:
        assert source.getnchannels()==1 and source.getsampwidth()==2
        assert source.getframerate()==RATE
        assert source.getnframes()/RATE < (1.2 if name=='game-win' else .6)
    print(name+'.wav',f'{len(pcm)/RATE:.3f}s',path.stat().st_size,'bytes')


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    wood=[(285,.60,.042),(615,.24,.026),(1220,.12,.013)]
    clack=[(780,.48,.032),(1680,.31,.019),(2650,.17,.009)]
    plastic=[(510,.30,.030),(1170,.42,.021),(2120,.17,.012)]
    write('chess-move',impact(.23,77,[(0,1)],wood,.010),.25)
    write('chess-capture',impact(.36,78,[(0,.75),(.095,1)],wood,.012),.29)
    write('checkers-move',impact(.21,79,[(0,1)],clack,.007),.23)
    write('checkers-capture',impact(.34,80,[(0,.70),(.075,1)],clack,.009),.27)
    write('connect4-drop',impact(.46,81,[(0,.25),(.065,.37),(.15,1),(.195,.50)],plastic,.009),.27)
    write('game-win',victory(),.20)


if __name__=='__main__': main()
