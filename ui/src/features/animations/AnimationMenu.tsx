import { useEffect, useMemo, useRef, useState } from "react";
import { Accessibility, Armchair, ArrowLeft, ArrowRight, Check, ChevronDown, Clock3, Coffee, Footprints,
  Hand, Heart, History, LayoutGrid, List, Loader2, Music2, Play, Plus, RefreshCw, Search, Smile,
  Sparkles, Square, Star, Users, Wrench, X, type LucideIcon } from "lucide-react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { CatalogAssembler, categories, describe, entries, matches, parsePreferences, readPreferences,
  type AnimationEntry, type AnimationProfile, type AnimationState, type CatalogBatch, type Preferences } from "./model";
import "./animations.css";

const icons: Record<string, LucideIcon> = { postures: Accessibility, gestures: Hand, social: Users, dance: Music2,
  emotions: Smile, relaxation: Coffee, seated: Armchair, consumables: Coffee, work: Wrench,
  music: Music2, interactions: Hand, onthemove: Footprints };
const initial: AnimationState = { open: false, busy: false, loaded: false, loading: false, current: false, message: "", toggleKey: "F3", stopKey: "X" };
function send(action: string, data: Record<string, unknown> = {}) { emit(PAGE_EVENTS.animationsAction, { action, ...data }); }
function Glyph({ category, size = 23 }: { category: string; size?: number }) {
  const Icon = icons[category] || Accessibility;
  return <Icon size={size} strokeWidth={1.55} aria-hidden />;
}
export function AnimationMenu() {
  const character = useStore(s => s.state.character);
  const blocked = useStore(s => s.activityActive || !!s.dialog || s.menuOpen || s.welcomeReplay || s.state.character.status !== "active" || s.state.character.welcomePending);
  const [state, setState] = useState(initial);
  const [catalog, setCatalog] = useState<AnimationProfile[]>([]);
  const assembler = useRef(new CatalogAssembler());
  const storageKey = `lightrp.animations.v1:${character.userId || character.accountName || "local"}`;
  const [prefs, setPrefs] = useState<Preferences>(() => readPreferences(storageKey));
  const prefKey = useRef(storageKey);
  const prefsDirty = useRef(false);
  const [preferencesMessage, setPreferencesMessage] = useState("");
  const closeKeyPressed = useRef<string | null>(null);
  const [query, setQuery] = useState("");
  const [category, setCategory] = useState("all");
  const [tab, setTab] = useState("all");
  const [selected, setSelected] = useState("");
  const [allVariants, setAllVariants] = useState(false);
  const [duration, setDuration] = useState("loop");
  const [assigning, setAssigning] = useState(false);
  const [limit, setLimit] = useState(48);
  const [clock, setClock] = useState(Date.now());
  const observedAt = useRef(Date.now());
  const lastPlayback = useRef("");
  const list = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const offState = on<AnimationState>(PAGE_EVENTS.animationsState, value => {
      if (!value || typeof value.open !== "boolean") return;
      observedAt.current = Date.now(); setClock(Date.now()); setState(value);
    });
    const offCatalog = on<CatalogBatch>(PAGE_EVENTS.animationsCatalog, value => {
      const next = assembler.current.accept(value); if (next) setCatalog(next);
    });
    const offPreferences = on<{ preferences?: unknown; message?: string }>(PAGE_EVENTS.animationsPreferences, value => {
      if (!value) return;
      if (value.preferences) { prefsDirty.current = false; setPrefs(parsePreferences(value.preferences)); }
      setPreferencesMessage(value.message || "");
    });
    return () => { offState(); offCatalog(); offPreferences(); };
  }, []);
  useEffect(() => {
    if (prefKey.current !== storageKey) { prefKey.current = storageKey; prefsDirty.current = false; setPrefs(readPreferences(storageKey)); }
  }, [storageKey]);
  const updatePrefs = (fn: (value: Preferences) => Preferences) => { prefsDirty.current = true; setPrefs(fn); };
  useEffect(() => {
    if (!prefsDirty.current) return;
    prefsDirty.current = false;
    try { localStorage.setItem(prefKey.current, JSON.stringify(prefs)); } catch { /* Native KVP remains available even if CEF storage isn't. */ }
    send("preferences", { preferences: { ...prefs, slots: prefs.slots.map(key => key || "") } });
  }, [prefs]);
  const items = useMemo(() => entries(catalog), [catalog]);
  const byKey = useMemo(() => new Map(items.map(item => [item.key, item])), [items]);
  const selectedItem = byKey.get(selected);
  const currentStep = state.current ? state.current.steps?.[state.current.step || 0] : undefined;
  const playing = currentStep ? byKey.get(`${currentStep.profile}:${currentStep.clip}`) : undefined;
  const active = !!state.current && state.current.active;
  const signature = active && playing && state.current ? `${state.current.playbackId}:${playing.key}` : "";
  useEffect(() => {
    if (!signature || signature === lastPlayback.current || !playing) return;
    lastPlayback.current = signature;
    const key = playing.key;
    updatePrefs(old => ({ ...old, recent: [key, ...old.recent.filter(k => k !== key)].slice(0, 24) }));
  }, [signature, playing]);
  useEffect(() => {
    if (!active) return;
    const timer = window.setInterval(() => setClock(Date.now()), 250);
    return () => window.clearInterval(timer);
  }, [active]);
  useEffect(() => { if (state.open && blocked) send("close"); }, [blocked, state.open]);
  useEffect(() => { setLimit(48); list.current?.scrollTo(0, 0); }, [tab, category, query, allVariants]);
  const filtered = useMemo(() => {
    let values = items.filter(item => (category === "all" || item.profile.category === category) && matches(item, query) &&
      (tab === "all" || (tab === "favorites" ? prefs.favorites.includes(item.key) : prefs.recent.includes(item.key))));
    if (tab === "all" && !allVariants && !query.trim()) {
      const families = new Map<string, AnimationEntry>();
      for (const item of values) if (!families.has(item.profile.id) || item.clip === item.profile.clip) families.set(item.profile.id, item);
      values = [...families.values()];
    }
    return values.sort((a, b) => tab === "recent" ? prefs.recent.indexOf(a.key) - prefs.recent.indexOf(b.key)
      : a.profile.label.localeCompare(b.profile.label) || a.index - b.index);
  }, [items, category, query, tab, allVariants, prefs.favorites, prefs.recent]);
  useEffect(() => { if (!byKey.has(selected) && filtered[0]) setSelected(filtered[0].key); }, [byKey, selected, filtered]);
  const play = (item?: AnimationEntry) => {
    if (!item || state.busy || blocked) return;
    setAssigning(false);
    send("play", { profile: item.profile.id, clip: item.clip, loop: duration === "loop", durationMs: duration === "loop" ? 10000 : Number(duration) });
  };
  const close = () => { setAssigning(false); send("close"); };
  const toggleFavorite = (key: string) => updatePrefs(old => ({ ...old, favorites: old.favorites.includes(key)
    ? old.favorites.filter(k => k !== key) : [...old.favorites, key].slice(-100) }));
  const assign = (slot: number) => {
    if (!selectedItem) return;
    updatePrefs(old => ({ ...old, slots: old.slots.map((key, i) => i === slot ? selectedItem.key : key) }));
    setAssigning(false);
  };
  const variant = (offset: number) => {
    if (!selectedItem) return;
    const clips = selectedItem.profile.clips;
    setSelected(`${selectedItem.profile.id}:${clips[(selectedItem.index + offset + clips.length) % clips.length]}`);
  };
  useEffect(() => {
    if (!state.open || blocked) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.repeat || event.ctrlKey || event.altKey || event.metaKey) return;
      const typing = event.target instanceof HTMLInputElement || event.target instanceof HTMLSelectElement;
      if (event.key === "Escape") { event.preventDefault(); close(); return; }
      if ((!typing || /^F\d+$/.test(event.key)) && event.key.toUpperCase() === state.toggleKey.toUpperCase()) {
        event.preventDefault(); closeKeyPressed.current = event.code || event.key.toUpperCase(); return;
      }
      if (typing) return;
      if (event.key.toUpperCase() === state.stopKey.toUpperCase()) { event.preventDefault(); send("stop"); }
      // KeyboardEvent.code also works on AZERTY without asking players to hold Shift.
      const digit = /^Digit[1-4]$/.test(event.code) ? Number(event.code.slice(-1))
        : /^[1-4]$/.test(event.key) ? Number(event.key) : ["&", "é", '"', "'"].indexOf(event.key) + 1;
      if (digit >= 1 && digit <= 4) {
        event.preventDefault(); const slot = digit - 1;
        if (assigning) assign(slot); else play(byKey.get(prefs.slots[slot] || ""));
      }
    };
    const onUp = (event: KeyboardEvent) => {
      if (closeKeyPressed.current !== null && (event.code || event.key.toUpperCase()) === closeKeyPressed.current) {
        closeKeyPressed.current = null; event.preventDefault(); close();
      }
    };
    const onBlur = () => { closeKeyPressed.current = null; };
    window.addEventListener("keydown", onKey);
    window.addEventListener("keyup", onUp);
    window.addEventListener("blur", onBlur);
    return () => { window.removeEventListener("keydown", onKey); window.removeEventListener("keyup", onUp); window.removeEventListener("blur", onBlur); };
  });
  if (blocked) return null;
  const remaining = state.current && !state.current.loop && typeof state.current.remainingMs === "number"
    ? Math.max(0, Math.ceil((state.current.remainingMs - (clock - observedAt.current)) / 1000)) : null;
  if (!state.open) return active || state.busy ? <aside className="rp-anim-playing" aria-live="polite">
    <span className="rp-anim-playing__icon">{state.busy ? <Loader2 className="rp-anim-spin" size={18} /> : <Glyph category={playing?.profile.category || "postures"} size={18} />}</span>
    <div><small>{state.busy ? "Starting animation" : "In character"}</small><strong>{playing?.profile.label || currentStep?.profile || "Animation"}</strong></div>
    {remaining !== null && <span>{remaining}s</span>}<span><kbd>{state.stopKey}</kbd> Stop</span><span><kbd>{state.toggleKey}</kbd> Browse</span>
  </aside> : null;
  return <section className="rp-animations o77-interactive" aria-label="Animations" role="dialog" aria-modal="false">
    <header className="rp-animations__header">
      <div><span className="rp-animations__eyebrow">LIGHT RP <i /> IN CHARACTER</span><h1>Animations<em>.</em></h1><p>Gestures, moods and everyday moments.</p></div>
      <button className="rp-anim-icon" onClick={close} aria-label="Close animations" title={`Close · ${state.toggleKey} / Esc`}><X size={20} /></button>
    </header>
    <div className="rp-animations__tools">
      <label className="rp-anim-search"><Search size={18} /><input aria-label="Search animations" placeholder="Search a gesture, mood, activity…" value={query} onChange={e => setQuery(e.target.value)} />{query && <button onClick={() => setQuery("")} aria-label="Clear search"><X size={15} /></button>}</label>
      <div className="rp-anim-tabs" aria-label="Animation collections">
        {[{ id: "all", label: "Discover", icon: Sparkles }, { id: "favorites", label: "Favorites", icon: Star }, { id: "recent", label: "Recent", icon: History }].map(({ id, label, icon: Icon }) =>
          <button key={id} aria-pressed={tab === id} onClick={() => { setTab(id); setCategory("all"); }}><Icon size={15} />{label}{id === "favorites" && <span>{prefs.favorites.filter(k => byKey.has(k)).length}</span>}</button>)}
      </div>
      <div className="rp-anim-filter">
        <label><select aria-label="Animation category" value={category} onChange={e => setCategory(e.target.value)}><option value="all">All categories</option>{Object.entries(categories).filter(([id]) => catalog.some(p => p.category === id)).map(([id, label]) => <option key={id} value={id}>{label}</option>)}</select><ChevronDown size={14} /></label>
        <span className="rp-anim-count">{filtered.length} {tab === "all" && !query && !allVariants ? "animations" : "variants"}</span>
        <button className="rp-anim-icon" aria-label="Grid view" aria-pressed={prefs.layout === "grid"} onClick={() => updatePrefs(old => ({ ...old, layout: "grid" }))}><LayoutGrid size={16} /></button>
        <button className="rp-anim-icon" aria-label="List view" aria-pressed={prefs.layout === "list"} onClick={() => updatePrefs(old => ({ ...old, layout: "list" }))}><List size={17} /></button>
      </div>
    </div>
    <div className={`rp-anim-library is-${prefs.layout}`} ref={list}>
      {!state.loaded ? <div className="rp-anim-empty"><Loader2 size={26} className={state.loading ? "rp-anim-spin" : ""} /><strong>{state.loading ? "Loading your gestures…" : "Catalogue unavailable"}</strong><p>{state.message || "Retrieving the server’s animation catalogue."}</p><button onClick={() => send("refresh")} disabled={state.loading}>Try again</button></div> :
        filtered.length === 0 ? <div className="rp-anim-empty"><Search size={26} /><strong>{tab === "favorites" ? "Your own collection" : tab === "recent" ? "The stage is yours" : "No matching animations"}</strong><p>{tab === "favorites" ? "Star a variant to keep it here." : tab === "recent" ? "Animations you play appear here automatically." : "Try a different word or category."}</p></div> :
        filtered.slice(0, limit).map(item => <article key={item.key} className={`rp-anim-card ${selectedItem?.profile.id === item.profile.id && (selected === item.key || (!allVariants && !query && tab === "all")) ? "is-selected" : ""}`}>
          <button className="rp-anim-card__select" title={`${item.profile.label} · ${item.variant}`} aria-label={`Select ${item.profile.label} ${item.variant}`} onClick={() => { setSelected(item.key); setAssigning(false); }}>
            <span className="rp-anim-card__glyph"><Glyph category={item.profile.category} size={prefs.layout === "grid" ? 26 : 21} /></span>
            <span className="rp-anim-card__text"><strong>{item.profile.label}</strong><small>{allVariants || query || tab !== "all" ? item.variant : categories[item.profile.category] || "Roleplay"}</small></span>
            <span className="rp-anim-card__meta">{item.walks ? <Footprints size={12} /> : null}{item.profile.clips.length > 1 ? <span>{item.index + 1}/{item.profile.clips.length}</span> : null}</span>
          </button>
          <button className={`rp-anim-star ${prefs.favorites.includes(item.key) ? "is-favorite" : ""}`} aria-label={`${prefs.favorites.includes(item.key) ? "Unfavorite" : "Favorite"} ${item.profile.label} ${item.variant}`} aria-pressed={prefs.favorites.includes(item.key)} onClick={() => toggleFavorite(item.key)}><Star size={14} /></button>
        </article>)}
      {filtered.length > limit && <button className="rp-anim-more" onClick={() => setLimit(n => n + 48)}>Show more · {filtered.length - limit} remaining</button>}
    </div>
    {state.loaded && <div className="rp-anim-library-footer"><label><input type="checkbox" checked={allVariants} onChange={e => setAllVariants(e.target.checked)} />Show every variant</label><button onClick={() => send("refresh")} disabled={state.loading} aria-label="Refresh animations"><RefreshCw size={13} className={state.loading ? "rp-anim-spin" : ""} />Refresh</button></div>}
    {state.message && <p className="rp-anim-error" role="status">{state.message}</p>}
    {preferencesMessage && <p className="rp-anim-error" role="status">{preferencesMessage}</p>}
    {selectedItem && <div className="rp-anim-detail">
      <div className="rp-anim-detail__title"><div><small>SELECTED ANIMATION</small><h2>{selectedItem.profile.label}</h2></div><button className="rp-anim-icon" aria-label="Favorite selected variant" aria-pressed={prefs.favorites.includes(selected)} onClick={() => toggleFavorite(selected)}><Star size={18} fill={prefs.favorites.includes(selected) ? "currentColor" : "none"} /></button></div>
      <div className="rp-anim-variant"><button className="rp-anim-icon" onClick={() => variant(-1)} disabled={selectedItem.profile.clips.length < 2} aria-label="Previous variant"><ArrowLeft size={16} /></button><div><strong>{selectedItem.variant}</strong><small>Variant {selectedItem.index + 1} / {selectedItem.profile.clips.length}</small></div><button className="rp-anim-icon" onClick={() => variant(1)} disabled={selectedItem.profile.clips.length < 2} aria-label="Next variant"><ArrowRight size={16} /></button></div>
      <p className="rp-anim-context"><Footprints size={13} />{describe(selectedItem)}</p>
      {selectedItem.profile.prop && <p className="rp-anim-context"><Coffee size={13} /><span>Accessory: {selectedItem.profile.prop.replace(/_/g, " ")}</span></p>}
      <div className="rp-anim-playrow"><label><Clock3 size={15} /><select aria-label="Animation duration" value={duration} onChange={e => setDuration(e.target.value)}><option value="loop">Until stopped</option><option value="5000">5 seconds</option><option value="10000">10 seconds</option><option value="30000">30 seconds</option></select></label><button className="rp-anim-play" disabled={state.busy || !state.loaded} onClick={() => play(selectedItem)}>{state.busy ? <Loader2 size={17} className="rp-anim-spin" /> : <Play size={17} fill="currentColor" />}Play animation</button></div>
    </div>}
    <div className={`rp-anim-quick ${assigning ? "is-assigning" : ""}`}>
      <div className="rp-anim-quick__title"><span>{assigning ? "Choose a slot for this variant" : "Quick access"}</span><button disabled={!selectedItem} onClick={() => setAssigning(value => !value)}>{assigning ? <><X size={13} />Cancel</> : <><Plus size={13} />Assign selected</>}</button></div>
      <div className="rp-anim-slots">{prefs.slots.map((key, index) => {
        const item = byKey.get(key || "");
        return <div className="rp-anim-slot" key={index}>
          <button onClick={() => assigning || !item ? assign(index) : play(item)} disabled={state.busy || (!item && !selectedItem)} aria-label={assigning ? `Assign slot ${index + 1}` : item ? `Play slot ${index + 1}: ${item.profile.label}` : `Assign slot ${index + 1}`}><kbd>{index + 1}</kbd>{assigning ? <Check size={19} /> : item ? <Glyph category={item.profile.category} size={20} /> : <Plus size={19} />}<strong>{item?.profile.label || (key ? "Unavailable" : "Add selected")}</strong></button>
          {key && !assigning && <button className="rp-anim-slot__remove" aria-label={`Clear slot ${index + 1}`} onClick={() => updatePrefs(old => ({ ...old, slots: old.slots.map((value, i) => i === index ? null : value) }))}><X size={11} /></button>}
        </div>;
      })}</div>
      <p>Keys 1–4 while browsing · Favorites and slots saved on this device</p>
    </div>
    <footer className="rp-animations__footer"><span><Heart size={13} /><span>{active ? playing?.profile.label || "Animation playing" : state.busy ? "Starting…" : "Stay in character"}</span></span><button disabled={!active && !state.busy} onClick={() => send("stop")}><Square size={12} fill="currentColor" />Stop <kbd>{state.stopKey}</kbd></button><span><kbd>Esc</kbd> Close</span></footer>
  </section>;
}
