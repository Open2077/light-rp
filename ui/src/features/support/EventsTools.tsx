import { useEffect, useRef, useState, type ReactNode } from "react";
import type { RageMenuItem } from "@/design/components";
import { request, key, type EventsView, type LiveEvent, type EventSpot, type DeskResult, type Person } from "./api";
import { useFormFocus } from "./SupportForms";

/* Staff events (/admin > Events, server/modules/staff_events.lua): launch world bosses,
   cyberpsychos and gang attacks where the staff want, chain them into event nights, keep a
   list of spots. The server re-checks every right (command.lightrp.events, and
   command.worldboss.start to pay), builds and validates the event, and audits before it acts:
   this page only picks the options, shows what will happen and collects a confirmation. */

type Entry = RageMenuItem & { run?:()=>void; change?:(patch:Partial<RageMenuItem>)=>void };
export type EventPageKind = "events"|"eventLive"|"eventLaunch"|"eventNight"|"eventSpots"|"eventSpot";
export const isEventPage = (kind:string):kind is EventPageKind => kind==="events"||kind.startsWith("event");
export interface EventPage { kind:EventPageKind; selected?:string; event?:LiveEvent; spot?:EventSpot }

export interface LaunchConfig { kind:number; boss:number; psycho:number; crew:number; where:number; player:number; spot:number; level:number; minutes:number; radius:number; pay:boolean; silent:boolean }
export const LAUNCH_DEFAULT:LaunchConfig = { kind:0, boss:0, psycho:0, crew:0, where:0, player:0, spot:0, level:0, minutes:15, radius:50, pay:false, silent:false };
export interface NightConfig { preset:number; rounds:number; where:number; level:number; pay:boolean }
export const NIGHT_DEFAULT:NightConfig = { preset:0, rounds:0, where:0, level:0, pay:false };

export type EventForm =
  | { kind:"launch" }
  | { kind:"night" }
  | { kind:"spotSave" }
  | { kind:"confirm"; action:"stop"|"win"|"nightStop"|"spotDelete"; id?:string; spot?:string; title:string; body:string; danger?:boolean; callOff?:boolean };

const KINDS = [
  { id:"psycho", label:"Cyberpsycho", icon:"zap", blurb:"One of the game's Psycho Squad cyberpsychos, a big health pool, hunting whoever enters its zone." },
  { id:"gang", label:"Gang attack", icon:"swords", blurb:"A warlord and its squad hold the point; two waves of backup come from the edge of the zone at 66 % and 33 % of the warlord's health." },
  { id:"boss", label:"World boss", icon:"crown", blurb:"A world boss of the catalogue (missions tagged World boss): at its own authored place, or moved into a compact layout around the point." },
] as const;
type Kind = typeof KINDS[number]["id"];
const WHERE_ALL = [
  { id:"origin", label:"Its own place", blurb:"Where the mission was authored, with its cover and routes." },
  { id:"here", label:"Here", blurb:"Around you. You must be in the city, not in an instance." },
  { id:"player", label:"On a player", blurb:"Around that player's position now." },
  { id:"spot", label:"Saved spot", blurb:"A spot saved in Events > Saved spots." },
] as const;
const whereFor = (kind:Kind) => kind==="boss" ? [...WHERE_ALL] : WHERE_ALL.filter(w=>w.id!=="origin");
const mmss = (ms?:number) => { if(ms===undefined)return "—"; const s=Math.max(0,Math.ceil(ms/1000)); return `${String(Math.floor(s/60)).padStart(2,"0")}:${String(s%60).padStart(2,"0")}`; };
const kindLabel = (k:string) => KINDS.find(x=>x.id===k)?.label ?? k;
const clamp = (n:number,low:number,high:number) => Math.max(low,Math.min(high,n));
const at = <T,>(rows:readonly T[], i:number):T|undefined => rows.length ? rows[((i%rows.length)+rows.length)%rows.length] : undefined;

/** The launch request the configurator describes, what it will do, and what blocks it. */
export function launchRequest(view:EventsView, c:LaunchConfig, players:Person[]) {
  const kind = at(KINDS, c.kind)!.id;
  const where = at(whereFor(kind), c.where)!;
  const boss = at(view.bosses, c.boss), psycho = c.psycho===0 ? undefined : at(view.psychos, c.psycho-1), crew = c.crew===0 ? undefined : at(view.crews, c.crew-1);
  const player = at(players, c.player), spot = at(view.spots, c.spot), level = at(view.levels, c.level);
  const own = kind==="boss" && where.id==="origin";
  const minutes = kind==="boss" && c.minutes===0 ? undefined : clamp(c.minutes||view.minutes.default, view.minutes.min, view.minutes.max);
  const payload:Record<string,unknown> = { kind, where:where.id, level:level?.id, pay:c.pay, silent:c.silent, minutes,
    radius: own ? undefined : clamp(c.radius, view.radius.min, view.radius.max) };
  if(kind==="boss")payload.boss=boss?.id;
  if(kind==="psycho")payload.enemy=psycho?.id ?? "random";
  if(kind==="gang")payload.crew=crew?.id ?? "random";
  if(where.id==="player")payload.target=player?.id;
  if(where.id==="spot")payload.spot=spot?.id;
  const problems:string[] = [];
  if(kind==="boss"&&!boss)problems.push("No world boss in the catalogue: tag a mission \"World boss\" in /lightrp.missions.");
  if(where.id==="here"&&!view.inCity)problems.push("You are in an instance: go back to the city, or pick a player or a spot.");
  if(where.id==="player"&&!player)problems.push("Nobody to pick.");
  if(where.id==="spot"&&!spot)problems.push("No saved spot yet (Events > Saved spots).");
  if(c.pay&&!view.canPay)problems.push("Paying needs the world boss right.");
  if(view.live.length>=view.maxLive)problems.push(`${view.live.length} events are out: that is the most at once.`);
  const what = kind==="boss" ? (boss?.title ?? "—") : kind==="psycho" ? (psycho?.label ?? "A random cyberpsycho") : `${crew?.label ?? "A random gang"}`;
  const place = own ? (boss?.location ?? "its own place") : where.id==="here" ? "around you" : where.id==="player" ? `on #${player?.id ?? "?"} ${player?.name ?? ""}` : `at ${spot?.name ?? "—"}`;
  const summary = [`${kindLabel(kind)}: ${what}`, `Where: ${place}${own?"":` · ${clamp(c.radius, view.radius.min, view.radius.max)} m zone`}`,
    `Level: ${level?.label ?? "Normal"} · Time: ${minutes===undefined?"as authored":`${minutes} min`}`,
    c.pay ? "Paid like a world boss: the pool, the daily cap, reputation, dailies, titles and drops." : "For fun: nothing is paid or counted.",
    c.silent ? "Silent: no city notice, no map pin." : "Announced to the whole city, with a map pin."];
  return { payload, summary, problems, kind, where:where.id, own, level, boss, psycho, crew, player, spot };
}

export function nightRequest(view:EventsView, c:NightConfig) {
  const preset = at(view.presets, c.preset), level = at(view.levels, c.level);
  const war = preset?.id==="gang_war", rush = preset?.id==="boss_rush";
  const high = war ? view.maxLive : view.maxRounds;
  const rounds = clamp(c.rounds || preset?.rounds || 1, preset?.min ?? 1, high);
  const where = rush ? "spots" : c.where===1 ? "here" : "spots";
  const problems:string[] = [];
  if(!preset)problems.push("No preset.");
  if(view.night&&view.night.phase!=="done")problems.push(`${view.night.label} is running: stop it first.`);
  if(rush&&!view.bosses.length)problems.push("No world boss in the catalogue.");
  if(!rush&&where==="spots"&&!view.spots.length)problems.push("No saved spot: save a few, or run it here.");
  if(war&&where==="here")problems.push("Gang War needs saved spots, one per gang.");
  if(war&&where==="spots"&&view.spots.length<rounds)problems.push(`Gang War needs ${rounds} saved spots.`);
  if(where==="here"&&!view.inCity)problems.push("You are in an instance: go back to the city.");
  if(c.pay&&!view.canPay)problems.push("Paying needs the world boss right.");
  const payload = { preset:preset?.id, rounds, where, level:level?.id, pay:c.pay };
  const summary = [`${preset?.label ?? "—"}: ${war?`${rounds} gangs at once`:`${rounds} round${rounds===1?"":"s"}`}`,
    rush ? "Each boss at its own place." : where==="here" ? "Around you." : `At the saved spots (${view.spots.length}), shuffled.`,
    `From ${level?.label ?? "Normal"}${war||rush?"":", harder every round"}.`, c.pay ? "Paid like world bosses." : "For fun: nothing is paid or counted."];
  return { payload, summary, problems, preset, rounds, war, rush, high };
}

/** The menu rows and the side panel of the Events pages. */
export function eventsMenu(ctx:{
  page:EventPage; view?:EventsView; players:Person[]; busy:boolean;
  launch:LaunchConfig; setLaunch:(p:Partial<LaunchConfig>)=>void; night:NightConfig; setNight:(p:Partial<NightConfig>)=>void;
  push:(p:EventPage)=>void; openForm:(f:EventForm)=>void; direct:(action:string,extra?:Record<string,unknown>)=>void;
  item:(id:string,text:string,run:()=>void,o?:Partial<Entry>)=>Entry; submenu:(id:string,text:string,run:()=>void,o?:Partial<Entry>)=>Entry;
}):{title:string;subtitle:string;entries:Entry[];content:ReactNode} {
  const { page, view:v, players, busy, launch:c, setLaunch, night:n, setNight, push, openForm, direct, item, submenu } = ctx;
  const loading:Entry = { id:"loading", text:"Loading…", disabled:true };
  if(!v)return { title:"EVENTS", subtitle:"LOADING", entries:[loading], content:null };
  const liveRow = (e:LiveEvent) => submenu(`live:${e.id}`, `${e.boss} · ${e.location}`, ()=>push({kind:"eventLive",event:e}),
    { icon:e.kind==="psycho"?"zap":e.kind==="gang"?"swords":"crown", meta:e.phase==="fight"?mmss(e.endsInMs):e.phase.toUpperCase(),
      description:`${kindLabel(e.kind)} · ${e.health} % · ${e.fighters} fighter(s) · ${e.pay?"paid":"no pay"}${e.silent?" · silent":""}${e.night?" · event night":""} · by ${e.by}` });
  if(page.kind==="events"){
    const night = v.night && v.night.phase!=="done" ? v.night : undefined;
    const entries:Entry[] = [
      { label:`LIVE NOW · ${v.live.length}/${v.maxLive}` },
      ...(v.live.length ? v.live.map(liveRow) : [{ id:"none", text:"No world event out", disabled:true }]),
      { separator:true },
      submenu("launch","Launch an event",()=>push({kind:"eventLaunch"}),{ icon:"siren", disabled:v.live.length>=v.maxLive,
        description:"A cyberpsycho, a gang attack or a world boss, here, on a player, at a saved spot or at its own place." }),
      submenu("night","Event nights",()=>push({kind:"eventNight"}),{ icon:"calendar", meta:night?`R${night.round}/${night.rounds}`:undefined,
        description:night?`${night.label}: ${night.phase}, ${night.won} of ${night.played} won.`:"Psycho Night, Boss Rush, Gang War, Siege: rounds of events announced to the city." }),
      submenu("spots","Saved spots",()=>push({kind:"eventSpots"}),{ icon:"map-pin", meta:String(v.spots.length), description:"Named places to launch events at later: prepare them in noclip, save, reuse." }),
      { separator:true },
      { id:"random", text:"Random world bosses", type:"checkbox", checked:v.random.enabled, disabled:busy||!v.canPay,
        run:()=>direct("random",{enabled:!v.random.enabled}), change:()=>direct("random",{enabled:!v.random.enabled}),
        description:v.canPay?"The automatic world bosses of the catalogue (until the next restart). Staff events run either way.":"Needs the world boss right." },
      item("nextNow","Next random boss now",()=>direct("next",{minutes:0}),{ icon:"timer", disabled:busy||!v.canPay||!v.random.enabled,
        meta:v.random.enabled&&v.random.nextInMs!==undefined?`${Math.ceil(v.random.nextInMs/60000)} MIN`:undefined,
        description:"A random world boss of the catalogue within a few seconds, once no other event is out." }),
    ];
    // the highlighted live event (the first row when nothing was moved yet)
    const chosen = v.live.find(e=>`live:${e.id}`===page.selected) ?? (page.selected===undefined ? v.live[0] : undefined);
    return { title:"EVENTS", subtitle:night?`${night.label.toUpperCase()} · ROUND ${night.round}/${night.rounds}`:`${v.live.length} OUT`, entries,
      content: chosen ? <LiveCard event={chosen}/> : <EventsHelp/> };
  }
  if(page.kind==="eventLive"){
    const e = v.live.find(x=>x.id===page.event?.id);
    if(!e)return { title:"EVENT", subtitle:page.event?.boss ?? "", entries:[{ id:"gone", text:"This event is over", disabled:true }], content:page.event?<LiveCard event={page.event}/>:null };
    const fighting = e.phase==="fight";
    return { title:kindLabel(e.kind).toUpperCase(), subtitle:`${e.boss} · ${e.location}`, content:<LiveCard event={e}/>, entries:[
      item("goto","Go to the event",()=>direct("goto",{id:e.id}),{ icon:"navigation", disabled:busy, description:"Teleport to the edge of its zone, facing in. Recorded in the staff history." }),
      ...(fighting?[
        submenu("win","End it as a win",()=>openForm({kind:"confirm",action:"win",id:e.id,title:"End it as a win?",
          body:e.pay?"The fight ends now and the shares are paid as fought, like a kill.":"The fight ends now as a win. Nothing is paid."}),
          { icon:"crown", disabled:e.pay&&!v.canPay, description:e.pay&&!v.canPay?"A paid event: needs the world boss right.":"The boss counts as down." }),
        submenu("stop","Call it off",()=>openForm({kind:"confirm",action:"stop",id:e.id,title:"Call it off?",body:"The enemies disappear, the zone is told it got away, nobody is paid.",danger:true}),
          { icon:"x", danger:true, description:"Ends it at once, nobody paid." }),
      ]:[{ id:"ending", text:"Ending…", disabled:true }]),
    ]};
  }
  if(page.kind==="eventLaunch"){
    const r = launchRequest(v, c, players);
    const wheres = whereFor(r.kind);
    const entries:Entry[] = [
      { id:"kind", text:"Event", type:"list", options:KINDS.map(k=>k.label), index:c.kind%KINDS.length, change:p=>setLaunch({kind:p.index??0,where:0}), description:at(KINDS,c.kind)!.blurb },
      ...(r.kind==="boss"?[{ id:"boss", text:"World boss", type:"list" as const, options:v.bosses.length?v.bosses.map(b=>b.title):["None"], index:v.bosses.length?c.boss%v.bosses.length:0,
        disabled:!v.bosses.length, change:(p:Partial<RageMenuItem>)=>setLaunch({boss:p.index??0}), description:r.boss?`Authored at ${r.boss.location}.`:"Tag a mission \"World boss\" in /lightrp.missions." }]:[]),
      ...(r.kind==="psycho"?[{ id:"psycho", text:"Cyberpsycho", type:"list" as const, options:["Random",...v.psychos.map(p=>p.label)], index:c.psycho%(v.psychos.length+1),
        change:(p:Partial<RageMenuItem>)=>setLaunch({psycho:p.index??0}), description:"The game's Psycho Squad record: its look and weapons. The handle shown is yours to choose at the review." }]:[]),
      ...(r.kind==="gang"?[{ id:"crew", text:"Gang", type:"list" as const, options:["Random",...v.crews.map(x=>x.label)], index:c.crew%(v.crews.length+1),
        change:(p:Partial<RageMenuItem>)=>setLaunch({crew:p.index??0}), description:"Its warlord, its squad and its backup waves." }]:[]),
      { id:"where", text:"Where", type:"list", options:wheres.map(w=>w.label), index:c.where%wheres.length, change:p=>setLaunch({where:p.index??0}), description:at(wheres,c.where)!.blurb },
      ...(r.where==="player"?[{ id:"player", text:"Player", type:"list" as const, options:players.length?players.map(p=>`#${p.id} ${p.name}`):["Nobody online"], index:players.length?c.player%players.length:0,
        disabled:!players.length, change:(p:Partial<RageMenuItem>)=>setLaunch({player:p.index??0}), description:"Their position when you launch. Not in an instance." }]:[]),
      ...(r.where==="spot"?[{ id:"spot", text:"Spot", type:"list" as const, options:v.spots.length?v.spots.map(s=>s.name):["No spot saved"], index:v.spots.length?c.spot%v.spots.length:0,
        disabled:!v.spots.length, change:(p:Partial<RageMenuItem>)=>setLaunch({spot:p.index??0}), description:r.spot?`${r.spot.district||"Night City"} · saved by ${r.spot.by}`:"Save spots in Events > Saved spots." }]:[]),
      { id:"level", text:"Level", type:"list", options:v.levels.map(l=>l.label), index:c.level%Math.max(1,v.levels.length), change:p=>setLaunch({level:p.index??0}), description:r.level?.blurb },
      { id:"minutes", text:"Time limit", type:"slider", value:c.minutes, min:r.kind==="boss"?0:v.minutes.min, max:v.minutes.max, step:5, unit:"min",
        change:p=>setLaunch({minutes:p.value??v.minutes.default}), description:r.kind==="boss"?"0 = the boss's authored time. Then it gets away.":"Then it gets away and nobody is paid." },
      { id:"radius", text:"Zone radius", type:"slider", value:c.radius, min:v.radius.min, max:v.radius.max, step:5, unit:"m", disabled:r.own,
        change:p=>setLaunch({radius:p.value??v.radius.default}), description:r.own?"A world boss at its own place keeps its authored zone.":"The zone that shows the HUD and leashes the enemies." },
      { id:"pay", text:"Pay the fighters", type:"checkbox", checked:c.pay, disabled:!v.canPay, run:()=>setLaunch({pay:!c.pay}), change:()=>setLaunch({pay:!c.pay}),
        description:v.canPay?"On: exactly a world boss (pool, daily cap, reputation, dailies, titles, drops). Off: for fun.":"Needs the world boss right: your events are for fun." },
      { id:"silent", text:"Silent", type:"checkbox", checked:c.silent, run:()=>setLaunch({silent:!c.silent}), change:()=>setLaunch({silent:!c.silent}),
        description:"No city notice and no map pin: the players stumble on it." },
      { separator:true },
      submenu("review","Review and launch",()=>openForm({kind:"launch"}),{ icon:"siren", disabled:r.problems.length>0||busy, description:r.problems[0] ?? "Name the place and the boss if you want, then confirm." }),
      item("reset","Reset the options",()=>setLaunch({...LAUNCH_DEFAULT,minutes:v.minutes.default,radius:v.radius.default}),{ icon:"undo-2" }),
    ];
    return { title:"LAUNCH AN EVENT", subtitle:at(KINDS,c.kind)!.label.toUpperCase(), entries, content:<SummaryCard caption="WHAT WILL HAPPEN" lines={r.summary} problems={r.problems}/> };
  }
  if(page.kind==="eventNight"){
    const r = nightRequest(v, n), running = v.night && v.night.phase!=="done" ? v.night : undefined;
    const entries:Entry[] = running ? [
      { id:"status", text:`${running.label} · round ${running.round}/${running.rounds}`, disabled:true, meta:running.phase.toUpperCase(),
        description:`${running.won} of ${running.played} won · ${running.live} out${running.nextInMs!==undefined?` · next in ${mmss(running.nextInMs)}`:""} · by ${running.by}` },
      submenu("stopNight","Stop the night",()=>openForm({kind:"confirm",action:"nightStop",title:`Stop ${running.label}?`,body:"No more rounds. Choose whether the events still out end now.",danger:true,callOff:false}),
        { icon:"x", danger:true }),
    ] : [
      { id:"preset", text:"Night", type:"list", options:v.presets.map(p=>p.label), index:n.preset%Math.max(1,v.presets.length), change:p=>setNight({preset:p.index??0,rounds:0}), description:r.preset?.blurb },
      { id:"rounds", text:r.war?"Gangs":"Rounds", type:"slider", value:r.rounds, min:r.preset?.min??1, max:r.high, step:1, change:p=>setNight({rounds:p.value??0}),
        description:r.war?"Gangs at once, one per saved spot.":r.rush?"Bosses back to back (at most the catalogue).":"Rounds, a break between two." },
      { id:"where", text:"Where", type:"list", options:["Saved spots","Here"], index:r.rush?0:n.where%2, disabled:r.rush, change:p=>setNight({where:p.index??0}),
        description:r.rush?"Each boss at its own place.":"Saved spots: shuffled, one per round. Here: every round around where you stand now." },
      { id:"level", text:"Starting level", type:"list", options:v.levels.map(l=>l.label), index:n.level%Math.max(1,v.levels.length), change:p=>setNight({level:p.index??0}) },
      { id:"pay", text:"Pay the fighters", type:"checkbox", checked:n.pay, disabled:!v.canPay, run:()=>setNight({pay:!n.pay}), change:()=>setNight({pay:!n.pay}),
        description:v.canPay?"On: each event pays like a world boss.":"Needs the world boss right." },
      { separator:true },
      submenu("start","Review and start",()=>openForm({kind:"night"}),{ icon:"calendar", disabled:r.problems.length>0||busy, description:r.problems[0] ?? "Announced to the city, the first round after the countdown." }),
    ];
    return { title:"EVENT NIGHTS", subtitle:running?running.label.toUpperCase():(r.preset?.label ?? "").toUpperCase(), entries,
      content:running?<SummaryCard caption="RUNNING" lines={[`${running.label}: round ${running.round} of ${running.rounds} (${running.phase})`, `${running.won} of ${running.played} fight(s) won so far.`, `Started by ${running.by}.`]}/>
        :<SummaryCard caption="THE PLAN" lines={r.summary} problems={r.problems}/> };
  }
  if(page.kind==="eventSpots"){
    const chosen = v.spots.find(s=>`spot:${s.id}`===page.selected);
    return { title:"SAVED SPOTS", subtitle:`${v.spots.length} SPOTS`, content:chosen?<SpotCard spot={chosen}/>:null, entries:[
      submenu("save","Save a spot here",()=>openForm({kind:"spotSave"}),{ icon:"plus", disabled:!v.inCity, description:v.inCity?"Your position and facing, under a name. The district is added for you.":"You are in an instance: spots are in the city." }),
      { separator:true },
      ...(v.spots.length?v.spots.map(s=>submenu(`spot:${s.id}`,s.name,()=>push({kind:"eventSpot",spot:s}),{ meta:s.distance!==undefined?`${s.distance} m`:undefined, description:`${s.district||"Night City"} · by ${s.by}` }))
        :[{ id:"empty", text:"No spot saved yet", disabled:true }]),
    ]};
  }
  if(page.kind==="eventSpot"){
    const s = v.spots.find(x=>x.id===page.spot?.id);
    if(!s)return { title:"SPOT", subtitle:page.spot?.name ?? "", entries:[{ id:"gone", text:"This spot no longer exists", disabled:true }], content:null };
    const index = v.spots.indexOf(s);
    return { title:"SPOT", subtitle:s.name, content:<SpotCard spot={s}/>, entries:[
      submenu("launchHere","Launch an event here",()=>{setLaunch({where:r2(c.kind),spot:index});push({kind:"eventLaunch"});},{ icon:"siren", description:"The launch page, set on this spot." }),
      item("goto","Go to this spot",()=>direct("goto",{spot:s.id}),{ icon:"navigation", disabled:busy }),
      submenu("delete","Remove this spot",()=>openForm({kind:"confirm",action:"spotDelete",spot:s.id,title:`Remove "${s.name}"?`,body:"Events already out stay where they are.",danger:true}),{ icon:"trash-2", danger:true }),
    ]};
  }
  return { title:"EVENTS", subtitle:"", entries:[], content:null };
}
// the "Saved spot" row of the Where list for an event kind
const r2 = (kindIndex:number) => whereFor(at(KINDS,kindIndex)!.id).findIndex(w=>w.id==="spot");

function EventsHelp() {
  return <div className="rp-support__record"><small>STAFF EVENTS</small><h2>Make the city move</h2>
    <p>Launch a cyberpsycho, a gang attack or a world boss where the players are. For fun nothing is paid; with the world boss right an event can pay exactly like a world boss.</p>
    <dl><dt>Up to</dt><dd>Several events at once (the random world boss included).</dd><dt>Announce</dt><dd>The whole city is told and a pin goes on the map, unless the event is silent.</dd>
      <dt>Recorded</dt><dd>Every launch, stop and teleport is in the staff history.</dd></dl></div>;
}
function LiveCard({event:e}:{event:LiveEvent}) {
  return <div className="rp-support__record"><small>{kindLabel(e.kind).toUpperCase()} · {e.pay?"PAID":"NO PAY"}{e.silent?" · SILENT":""}</small><h2>{e.boss}</h2><p>{e.title} · {e.location}</p>
    <dl><dt>Boss health</dt><dd>{e.health} %</dd><dt>Enemies left</dt><dd>{e.enemies}</dd><dt>In the zone</dt><dd>{e.fighters} fighter{e.fighters===1?"":"s"}</dd>
      <dt>Time left</dt><dd>{e.phase==="fight"?mmss(e.endsInMs):e.phase}</dd><dt>Started by</dt><dd>{e.by}{e.night?" · event night":""}</dd>
      {e.distance!==undefined&&<><dt>Distance</dt><dd>{e.distance} m</dd></>}</dl></div>;
}
function SpotCard({spot:s}:{spot:EventSpot}) {
  return <div className="rp-support__record"><small>SAVED SPOT · {s.id}</small><h2>{s.name}</h2><p>{s.district||"Night City"} · saved by {s.by||"?"}</p>
    {s.distance!==undefined&&<dl><dt>Distance</dt><dd>{s.distance} m</dd></dl>}</div>;
}
function SummaryCard({caption,lines,problems=[]}:{caption:string;lines:string[];problems?:string[]}) {
  return <div className="rp-support__record"><small>{caption}</small>{lines.map((l,i)=>i===0?<h2 key={i}>{l}</h2>:<p key={i}>{l}</p>)}
    {problems.map(p=><p key={p} className="rp-support__error" role="alert">{p}</p>)}</div>;
}

/** The right-hand panel for an event form: options, a note, a confirmation, then the server's answer. */
export function EventFormPanel({form,view,launch,night,players,onCancel,onDone}:{form:EventForm;view:EventsView;launch:LaunchConfig;night:NightConfig;players:Person[];onCancel:()=>void;onDone:(message:string)=>void}) {
  const [location,setLocation]=useState(""),[name,setName]=useState(""),[reason,setReason]=useState(""),[callOff,setCallOff]=useState(form.kind==="confirm"&&form.callOff===true);
  const [confirm,setConfirm]=useState(false),[busy,setBusy]=useState(false),[error,setError]=useState(""),[uncertain,setUncertain]=useState(false);
  const mutation=useRef<string>(),cancelRef=useRef<HTMLButtonElement>(null),ref=useFormFocus();
  useEffect(()=>{if(confirm)cancelRef.current?.focus();},[confirm]);
  const plan = form.kind==="launch" ? launchRequest(view,launch,players) : form.kind==="night" ? nightRequest(view,night) : undefined;
  const send=async()=>{
    if(busy||uncertain)return;setBusy(true);setError("");mutation.current??=key();
    let payload:Record<string,unknown>;
    if(form.kind==="launch")payload={...plan!.payload,action:"launch",location,name};
    else if(form.kind==="night")payload={...plan!.payload,action:"night"};
    else if(form.kind==="spotSave")payload={action:"spotSave",name};
    else payload={action:form.action,id:form.id,spot:form.spot,callOff};
    try{
      const r=await request<DeskResult>("eventsAction",{...payload,confirmed:true,mutation:mutation.current,reason});
      if(r.accepted&&r.outcome==="success")onDone(r.message);else{setError(r.message);setConfirm(false);setUncertain(r.outcome==="pending");mutation.current=undefined;}
    }catch(e){setError((e as Error).message);}finally{setBusy(false);}
  };
  const title = form.kind==="launch" ? "Launch an event" : form.kind==="night" ? "Start an event night" : form.kind==="spotSave" ? "Save a spot here" : form.title;
  const lines = plan?.summary ?? (form.kind==="confirm" ? [form.body] : ["Your position and facing now, under this name."]);
  const danger = form.kind==="confirm" && form.danger===true;
  const verb = form.kind==="launch" ? "Launch" : form.kind==="night" ? "Start the night" : form.kind==="spotSave" ? "Save spot" : danger ? "Confirm" : "Confirm";
  const problems = plan?.problems ?? [];
  return <div className="rp-support__action"><h2>{title}</h2>{lines.map((l,i)=><p key={i}>{l}</p>)}
    {confirm?<div className="rp-support__confirm" role="alertdialog" aria-label="Confirm the event">
      <h3>{form.kind==="launch"?"Launch it now?":form.kind==="night"?"Announce it to the city now?":form.kind==="spotSave"?`Save "${name}"?`:title}</h3>
      {form.kind==="launch"&&(location||name)&&<p>{name?`Boss: ${name}`:""}{name&&location?" · ":""}{location?`Place: ${location}`:""}</p>}
      {reason&&<blockquote>{reason}</blockquote>}
      <footer><button ref={cancelRef} disabled={busy} onClick={()=>setConfirm(false)}>Cancel</button><button className={danger?"is-danger":"is-primary"} disabled={busy} onClick={send}>{busy?"Applying…":verb}</button></footer>
    </div>:<form className="rp-support__form" ref={ref} onSubmit={e=>{e.preventDefault();mutation.current=undefined;setConfirm(true);}}>
      {form.kind==="launch"&&<>
        <label>Place name the city is told<input maxLength={40} value={location} onChange={e=>setLocation(e.target.value)} placeholder={plan&&"own" in plan&&plan.own?"As authored":"The spot's name, your district, or Night City"}/></label>
        <label>Boss name<input maxLength={32} value={name} onChange={e=>setName(e.target.value)} placeholder="A handle from the list, or the boss's own"/></label></>}
      {form.kind==="spotSave"&&<label>Spot name<input required minLength={1} maxLength={40} value={name} onChange={e=>setName(e.target.value)} placeholder="Market behind Tom's Diner"/></label>}
      {form.kind==="confirm"&&form.action==="nightStop"&&<label className="rp-support__check"><span><input type="checkbox" checked={callOff} onChange={e=>setCallOff(e.target.checked)}/>Also call off the events still out (nobody paid)</span></label>}
      <label>Note for the staff history (optional)<textarea maxLength={500} rows={3} value={reason} onChange={e=>setReason(e.target.value)} placeholder="Why, for whom: an event for the players online, a test…"/></label>
      {problems.map(p=><p key={p} className="rp-support__error" role="alert">{p}</p>)}
      <footer><button type="button" onClick={onCancel}>Back</button><button className={danger?"is-danger":"is-primary"} disabled={uncertain||problems.length>0||(form.kind==="spotSave"&&!name.trim())}>Review</button></footer>
    </form>}{error&&<p className="rp-support__error" role="alert">{error}</p>}</div>;
}
export const eventAuditLabels:Record<string,string>={eventLaunch:"Launch an event",eventStop:"Call off an event",eventWin:"End an event as a win",eventGoto:"Go to an event",
  eventNight:"Start an event night",eventNightStop:"Stop an event night",eventSpotSave:"Save an event spot",eventSpotDelete:"Remove an event spot",eventRandom:"Random world bosses",eventNext:"Next random world boss"};
