import { useCallback, useEffect, useRef, useState } from "react";
import { emit, on } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Badge, Button, Icon, Input, Keycap, RageMenu, isPickable, type RageMenuItem } from "@/design/components";
import { mutationKey, request, ZoneRequestTimeout } from "./api";
import { clone, extraRuleDefaults, EXTRA_RESTRICTIONS, fresh, invalid, normalizeZone, SHAPES, shapeName, type Capture, type Listing, type Permissions, type Wire, type Zone } from "./model";
import "./safezones.css";

type Entry = RageMenuItem & { run?: () => void };
const NO_PERMISSIONS: Permissions = { view: false, edit: false, publish: false, delete: false };
const errorText = (error: unknown) => error instanceof Error ? error.message : "La demande a échoué.";

/** One RP surface: staff authoring is separate from the always-on protection signal. */
export function Safezones() {
  const [opened, setOpened] = useState(false), [zones, setZones] = useState<Zone[]>([]);
  const [ready, setReady] = useState(false), [permissions, setPermissions] = useState(NO_PERMISSIONS);
  const [draft, setDraft] = useState<Zone>(), [original, setOriginal] = useState("");
  const [session, setSession] = useState(""), [world, setWorld] = useState(false), [selected, setSelected] = useState(0);
  const [query, setQuery] = useState(""), [index, setIndex] = useState(0), [busy, setBusy] = useState(false);
  const [searching, setSearching] = useState(false);
  const [unconfirmed, setUnconfirmed] = useState<"save" | "delete">();
  const [error, setError] = useState(""), [feedback, setFeedback] = useState("");
  const [confirm, setConfirm] = useState<"discard" | "delete">();
  const [captureMode, setCaptureMode] = useState<"append" | "replace">("append");
  const live = useRef(true), working = useRef(false), generation = useRef(-1), confirmation = useRef<HTMLDivElement>(null);
  const mutation = useRef<{ signature: string; key: string }>();
  const current = useRef({ opened, draft, session, busy, world, selected, captureMode, unconfirmed });
  current.current = { opened, draft, session, busy, world, selected, captureMode, unconfirmed };
  const locked = busy || !!unconfirmed;
  const changed = !!draft && JSON.stringify(draft) !== original;

  const refresh = useCallback(async () => {
    const data = await request<Listing>("list");
    if (!live.current) return;
    setZones(Array.isArray(data.zones) ? data.zones.map(normalizeZone) : []);
    setPermissions(data.permissions ?? NO_PERMISSIONS); setReady(data.ready === true);
  }, []);
  const run = useCallback(async (task: () => Promise<void>) => {
    if (working.current) return;
    working.current = true; setBusy(true); setError(""); setFeedback("");
    try { await task(); } catch (reason) { if (live.current) setError(errorText(reason)); }
    finally { working.current = false; if (live.current) setBusy(false); }
  }, []);
  const clearDraft = useCallback(() => {
    setDraft(undefined); setOriginal(""); setSession(""); setWorld(false); setConfirm(undefined);
    setUnconfirmed(undefined);
    mutation.current = undefined;
    emit(PAGE_EVENTS.safezones, { operation: "preview", zone: null });
    emit(PAGE_EVENTS.safezones, { operation: "cancel" });
  }, []);
  const close = useCallback(() => {
    clearDraft(); setOpened(false); setError("");
    emit(PAGE_EVENTS.safezones, { operation: "close" });
  }, [clearDraft]);
  const capture = useCallback(() => run(async () => {
    const state = current.current;
    if (!state.draft || !state.opened || state.unconfirmed) return;
    if (state.draft.shape === "poly" && state.captureMode === "append" && state.draft.points.length >= 32) throw new Error("Le polygone est limité à 32 sommets.");
    const data = await request<Capture>("capture", { session: state.session || undefined });
    if (!live.current || !current.current.opened) return;
    if (data.bucket !== state.draft.bucket) throw new Error("Votre instance a changé. Fermez le brouillon puis recommencez.");
    setSession(data.session);
    setDraft(previous => {
      if (!previous) return previous;
      if (previous.shape === "poly") {
        const points = [...previous.points];
        if (state.captureMode === "replace" && points[state.selected]) points[state.selected] = data.position;
        else if (points.length < 32) { points.push(data.position); setSelected(points.length - 1); }
        return { ...previous, points };
      }
      return { ...previous, center: data.position };
    });
  }), [run]);

  useEffect(() => {
    live.current = true;
    const off = on<Wire>(PAGE_EVENTS.safezones, event => {
      if (event.kind === "open") {
        useStore.getState().closeDialog(); useStore.getState().closeMenu();
        setOpened(true); setWorld(false); setError(""); void run(refresh);
      } else if (event.kind === "snapshot") {
        const revision = event.generation ?? 0;
        if (revision < generation.current) return;
        generation.current = revision;
        setReady(event.ready === true);
        setZones(Array.isArray(event.zones) ? event.zones.map(normalizeZone) : []);
        if (!event.ready) useStore.getState().setSafezone(undefined);
      } else if (event.kind === "presence") {
        const zone = event.ready === true ? event.zone : undefined;
        useStore.getState().setSafezone(zone ? { id: zone.id, label: zone.label, blockRun: zone.blockRun ?? false, blockShoot: zone.blockShoot ?? true, ...extraRuleDefaults(zone) } : undefined);
        setReady(event.ready === true);
      } else if (event.kind === "editor" && current.current.opened) {
        setWorld(event.mode === "world");
      } else if (event.kind === "captureKey") {
        void capture();
      } else if (event.kind === "invalidate") {
        close();
        useStore.getState().pushNotice({ kind: "warning", title: "Zones protégées", body: event.error || "La session d'édition a été fermée.", durationMs: 8000 });
      }
    });
    return () => { live.current = false; off(); useStore.getState().setSafezone(undefined); emit(PAGE_EVENTS.safezones, { operation: "close" }); };
  }, [capture, close, refresh, run]);
  useEffect(() => {
    if (!opened) return;
    emit(PAGE_EVENTS.safezones, { operation: "input", mode: world ? "world" : draft || confirm || searching ? "form" : "menu" });
  }, [opened, world, !!draft, confirm, searching]);
  useEffect(() => {
    if (!opened) return;
    emit(PAGE_EVENTS.safezones, { operation: "preview", zone: draft ?? null });
  }, [draft, opened]);
  useEffect(() => {
    if (!opened || !session) return;
    const timer = window.setInterval(() => {
      void request("heartbeat", { session: current.current.session }).catch(reason => {
        if (live.current && current.current.opened) setError(errorText(reason));
      });
    }, 60000);
    return () => window.clearInterval(timer);
  }, [opened, session]);
  const back = () => {
    if (working.current) return;
    if (unconfirmed === "delete") return;
    if (searching) { setSearching(false); return; }
    if (confirm) { setConfirm(undefined); return; }
    if (draft) { if (changed) setConfirm("discard"); else clearDraft(); }
    else close();
  };
  useEffect(() => {
    if (!opened || world || !draft && !confirm && !searching) return;
    const handler = (event: KeyboardEvent) => {
      if (event.key !== "Escape") return;
      event.preventDefault(); event.stopPropagation(); back();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  });
  useEffect(() => {
    if (!confirm) return;
    const panel = confirmation.current;
    panel?.querySelector<HTMLButtonElement>("button")?.focus();
    const trap = (event: KeyboardEvent) => {
      if (event.key !== "Tab") return;
      const buttons = Array.from(panel?.querySelectorAll<HTMLButtonElement>("button:not(:disabled)") ?? []);
      const first = buttons[0], last = buttons[buttons.length - 1];
      if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last?.focus(); }
      else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first?.focus(); }
    };
    window.addEventListener("keydown", trap);
    return () => window.removeEventListener("keydown", trap);
  }, [confirm]);

  const edit = (source?: Zone, duplicate = false) => run(async () => {
    if (source && !permissions.edit) {
      const next = clone(source); setDraft(next); setOriginal(JSON.stringify(next)); setSession("");
      setSelected(0); setWorld(false); setConfirm(undefined); mutation.current = undefined;
      return;
    }
    if (!duplicate) await request("cancel");
    const data = await request<Capture>("capture");
    if (!live.current || !current.current.opened) return;
    if (source && source.bucket !== data.bucket) throw new Error("Rejoignez l'instance de cette zone pour la modifier.");
    const next = source ? clone(source) : fresh(data);
    if (duplicate) { next.id = ""; next.revision = 0; next.label = `${next.label.slice(0, 69)} · copie`; }
    setDraft(next); setOriginal(source && !duplicate ? JSON.stringify(next) : ""); setSession(data.session);
    setSelected(0); setWorld(false); setConfirm(undefined); mutation.current = undefined;
  });
  const update = (patch: Partial<Zone>) => setDraft(previous => previous ? { ...previous, ...patch } : previous);
  const publish = () => run(async () => {
    if (!draft) return;
    const reason = invalid(draft); if (reason) throw new Error(reason);
    const signature = JSON.stringify({ operation: "save", zone: draft, session });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    let result: { zone: Zone };
    try { result = await request<{ zone: Zone }>("save", { zone: draft, baseRevision: draft.revision, mutation: mutation.current.key, session }); }
    catch (reason) { if (reason instanceof ZoneRequestTimeout) setUnconfirmed("save"); throw reason; }
    if (!live.current) return;
    const saved = normalizeZone(result.zone); setDraft(saved); setOriginal(JSON.stringify(saved));
    mutation.current = undefined; setUnconfirmed(undefined); setFeedback("Zone enregistrée. La protection suit son état actif/inactif.");
    await refresh();
  });
  const remove = () => run(async () => {
    if (!draft?.id) return;
    const signature = JSON.stringify({ operation: "delete", id: draft.id, revision: draft.revision, session });
    if (mutation.current?.signature !== signature) mutation.current = { signature, key: mutationKey() };
    try { await request("delete", { id: draft.id, baseRevision: draft.revision, mutation: mutation.current.key, session }); }
    catch (reason) { if (reason instanceof ZoneRequestTimeout) setUnconfirmed("delete"); throw reason; }
    if (!live.current) return;
    clearDraft(); setFeedback("Zone supprimée."); await refresh();
  });

  const filtered = zones.filter(z => z.label.toLocaleLowerCase().includes(query.toLocaleLowerCase()));
  const entries: Entry[] = [
    { id: "new", text: "Créer une zone", icon: "plus", disabled: busy || !permissions.edit || !permissions.publish || !ready, run: () => { void edit(); }, description: "Placez un volume dans le monde, puis publiez-le." },
    { id: "search", text: "Rechercher", icon: "search", meta: query || "TOUTES", disabled: busy, run: () => setSearching(true), description: "Filtrer les noms des zones." },
    { separator: true },
    ...filtered.map(z => ({ id: z.id, text: z.label, meta: z.enabled ? "ACTIVE" : "INACTIVE", icon: "shield", disabled: busy, run: () => { void edit(z); }, description: `${shapeName[z.shape]} · instance ${z.bucket} · révision ${z.revision}` })),
    ...(!filtered.length ? [{ id: "empty", text: ready ? "Aucune zone" : "Protection indisponible", disabled: true }] : []),
    { separator: true },
    { id: "refresh", text: "Actualiser", icon: "activity", disabled: busy, run: () => { void run(refresh); } },
    { id: "close", text: "Fermer", icon: "x", disabled: busy, run: close },
  ];
  const activeIndex = isPickable(entries[index]) ? index : Math.max(0, entries.findIndex(isPickable));
  const problem = draft ? invalid(draft) : undefined;
  const vertex = draft?.points[selected];
  const numeric = (name: string, value: number, change: (value: number) => void, step = 0.1, disabled = false) => <Input label={name} type="number" step={step} value={Number.isFinite(value) ? value : ""} disabled={locked || !permissions.edit || disabled} onChange={event => change(event.currentTarget.valueAsNumber)} />;

  return <>
    {opened && <>
      <div className={`safezone-toolstrip ${world ? "safezone-toolstrip--world" : ""}`}>
        <Icon name="shield" size={18} /><span><b>ZONE / ÉDITEUR</b><small>{draft ? `${draft.label} · ${shapeName[draft.shape]}` : "Gestion des zones protégées"}</small></span>
        <Badge tone={draft ? "accent" : "outline"}>{draft ? "BROUILLON" : `${zones.length} ZONE(S)`}</Badge>
        {draft && <span className="safezone-toolstrip__keys"><Keycap>F9</Keycap> {world ? "Inspecteur" : "Déplacement"}<Keycap>F10</Keycap> {draft.shape === "poly" ? captureMode === "replace" ? "Remplacer le sommet" : "Ajouter un sommet" : "Placer le centre"}</span>}
      </div>
      {!world && <section className="safezone-workspace o77-interactive" aria-label="Éditeur de zones protégées">
        {!draft ? <>
          <RageMenu title="LIGHT/RP" subtitle="ZONES PROTÉGÉES" tag="STAFF" items={entries} index={activeIndex} visibleRows={9} width={350}
            active={!busy && !searching} onIndexChange={setIndex} onSelect={(_, i) => entries[i]?.run?.()} onBack={back} />
          <div className="safezone-intro"><Icon name="shield" size={28} /><h2>Un espace pour le RP.</h2><p>Délimitez les lieux où les combats entre joueurs sont bloqués. Les attaques depuis la zone sont également refusées.</p><p>Chaque volume appartient à une instance et possède ses propres limites de hauteur.</p>{searching && <form onSubmit={event => { event.preventDefault(); setSearching(false); }}><Input label="Rechercher une zone" autoFocus value={query} onChange={event => { setQuery(event.target.value); setIndex(0); }} /><Button size="sm" type="submit">Appliquer le filtre</Button></form>}<small>Les contours de votre brouillon restent visibles uniquement pour vous.</small></div>
        </> : <section className="safezone-inspector" aria-label="Propriétés de la zone">
          <header><div><span className="o77-tag">{draft.id ? `RÉVISION ${draft.revision}` : "NOUVELLE ZONE"}</span><h2>{draft.label || "Sans nom"}</h2></div><Badge tone={changed ? "accent" : "outline"}>{changed ? "MODIFIÉ" : "ENREGISTRÉ"}</Badge></header>
          <div className="safezone-inspector__scroll">
            <Input label="Nom de la zone" maxLength={80} value={draft.label} disabled={locked || !permissions.edit} onChange={event => update({ label: event.target.value })} />
            <div className="safezone-shapes" role="group" aria-label="Forme de la zone">{SHAPES.map(shape => <Button key={shape} size="sm" variant={draft.shape === shape ? "primary" : "secondary"} disabled={locked || !permissions.edit} onClick={() => update({ shape })}>{shapeName[shape]}</Button>)}</div>
            <div className="safezone-metadata"><span>INSTANCE <b>{draft.bucket}</b></span><label><input type="checkbox" checked={draft.enabled} disabled={locked || !permissions.edit} onChange={event => update({ enabled: event.target.checked })} /> Protection active après publication</label></div>
            <fieldset className="safezone-restrictions" disabled={locked || !permissions.edit}>
              <legend>Règles de la zone</legend>
              <label><input type="checkbox" checked={draft.blockRun} onChange={event => update({ blockRun: event.target.checked })} />Interdire de courir</label>
              <label><input type="checkbox" checked={draft.blockShoot} onChange={event => update({ blockShoot: event.target.checked })} />Interdire de tirer</label>
              {EXTRA_RESTRICTIONS.map(rule => <label key={rule.key}><input type="checkbox" checked={draft[rule.key]} onChange={event => update({ [rule.key]: event.target.checked })} />{rule.label}</label>)}
              <p>Les consommables natifs désignent les soins/inhalateurs et leur raccourci du jeu, pas les aliments ou boissons de l'inventaire RP.</p>
              <label><input type="checkbox" checked={draft.fullHeight} onChange={event => update({ fullHeight: event.target.checked,
                minZ: Number.isFinite(draft.minZ) ? draft.minZ : draft.center.z - 1,
                maxZ: Number.isFinite(draft.maxZ) ? draft.maxZ : draft.center.z + 5 })} />Toute la hauteur (haut et bas)</label>
              <p>{draft.fullHeight ? "La zone couvre toute la colonne verticale. Le plancher et le plafond sont ignorés ; leurs valeurs sont conservées." : "Le plancher et le plafond délimitent les étages protégés. Activez toute la hauteur pour protéger la colonne entière."}</p>
            </fieldset>
            <div className="safezone-grid">
              {numeric("Plancher Z", draft.minZ, minZ => update({ minZ }), 0.1, draft.fullHeight)}
              {numeric("Plafond Z", draft.maxZ, maxZ => update({ maxZ }), 0.1, draft.fullHeight)}
              {draft.shape === "circle" && numeric("Rayon (m)", draft.radius, radius => update({ radius }))}
              {draft.shape === "box" && <>{numeric("Longueur (m)", draft.length, length => update({ length }))}{numeric("Largeur (m)", draft.width, width => update({ width }))}{numeric("Rotation (°)", draft.heading, heading => update({ heading }), 1)}</>}
            </div>
            {draft.shape !== "poly" ? <>
              <h3>Centre du volume</h3><div className="safezone-grid safezone-grid--three">{(["x", "y", "z"] as const).map(axis => <div key={axis}>{numeric(axis.toUpperCase(), draft.center[axis], value => update({ center: { ...draft.center, [axis]: value } }))}</div>)}</div>
            </> : <>
              <h3>Sommets <span>{draft.points.length} / 32</span></h3>
              <div className="safezone-vertices">{draft.points.map((p, i) => <button type="button" aria-label={`Sommet ${i + 1}`} aria-pressed={i === selected} key={i} onClick={() => setSelected(i)}><b>{String(i + 1).padStart(2, "0")}</b><span>{p.x.toFixed(1)} / {p.y.toFixed(1)}</span></button>)}{!draft.points.length && <p>Marchez jusqu'au premier angle, puis appuyez sur F10.</p>}</div>
              {vertex && <div className="safezone-grid safezone-grid--three">{(["x", "y", "z"] as const).map(axis => <div key={axis}>{numeric(`Sommet ${selected + 1} · ${axis.toUpperCase()}`, vertex[axis], value => update({ points: draft.points.map((p, i) => i === selected ? { ...p, [axis]: value } : p) }))}</div>)}</div>}
              <div className="safezone-inline"><Button size="sm" variant={captureMode === "append" ? "primary" : "secondary"} onClick={() => setCaptureMode("append")}>Ajouter</Button><Button size="sm" variant={captureMode === "replace" ? "primary" : "secondary"} disabled={!vertex} onClick={() => setCaptureMode("replace")}>Remplacer #{selected + 1}</Button><Button size="sm" variant="ghost" disabled={locked || !permissions.edit || !draft.points.length} onClick={() => { update({ points: draft.points.slice(0, -1) }); setSelected(n => Math.max(0, Math.min(n, draft.points.length - 2))); }}>Annuler le dernier</Button></div>
            </>}
            <div className="safezone-inline"><Button icon="map-pin" size="sm" variant="secondary" disabled={locked || !permissions.edit} onClick={() => { void capture(); }}>Utiliser ma position</Button><Button icon="footprints" size="sm" variant="secondary" disabled={busy} onClick={() => setWorld(true)}>Déplacer dans le monde</Button></div>
            <p className="safezone-note">Le contour est un aperçu. La protection change uniquement après publication. Le serveur valide chaque sommet et la hauteur.</p>
            {problem && <p className="safezone-validation" role="status"><Icon name="triangle-alert" size={14} />{problem}</p>}
          </div>
          <footer><Button icon="check" size="sm" disabled={busy || unconfirmed === "delete" || !permissions.publish || !permissions.edit || !!problem || !ready} onClick={publish}>{busy ? "En cours…" : unconfirmed ? "Vérifier la publication" : "Publier la zone"}</Button><Button size="sm" variant="secondary" disabled={locked || !permissions.edit || !permissions.publish} onClick={() => { void edit(draft, true); }}>Dupliquer</Button><Button size="sm" variant="danger" disabled={locked || !draft.id || !permissions.delete} onClick={() => setConfirm("delete")}>Supprimer</Button><Button size="sm" variant="ghost" disabled={busy} onClick={back}>Retour</Button></footer>
        </section>}
        {(error || feedback) && <div className={`safezone-message ${error ? "safezone-message--error" : ""}`} role="status"><Icon name={error ? "triangle-alert" : "check"} size={16} />{error || feedback}</div>}
      </section>}
      {world && <div className="safezone-world-note"><span>APERÇU LOCAL · AUCUNE MODIFICATION PUBLIÉE</span><p>Marchez autour du volume. <b>F9</b> pour régler ses propriétés.</p>{busy && <small>Capture de la position…</small>}{error && <small role="alert">{error}</small>}</div>}
      {confirm && <div ref={confirmation} className="safezone-confirm o77-interactive" role="alertdialog" aria-modal="true" aria-labelledby="safezone-confirm-title"><Icon name="triangle-alert" size={25} /><h2 id="safezone-confirm-title">{confirm === "delete" ? "Supprimer cette zone ?" : "Abandonner le brouillon ?"}</h2><p>{unconfirmed ? "Une écriture reste à confirmer. Vérifiez son résultat avant de poursuivre." : confirm === "delete" ? "La protection de cette zone sera retirée après confirmation du serveur. Les autres zones restent actives." : "Les modifications non publiées seront perdues. La version enregistrée reste inchangée."}</p><div><Button variant="secondary" disabled={busy || unconfirmed === "delete"} onClick={() => setConfirm(undefined)}>Annuler</Button><Button variant="danger" disabled={busy || unconfirmed && confirm !== "delete"} onClick={() => { if (confirm === "delete") remove(); else clearDraft(); }}>{confirm === "delete" ? unconfirmed ? "Vérifier la suppression" : "Supprimer" : "Abandonner"}</Button></div>{error && <p role="alert">{error}</p>}</div>}
    </>}
  </>;
}
