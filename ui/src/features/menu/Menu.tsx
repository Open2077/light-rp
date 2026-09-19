import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { requestClose, sendAction } from "@/bridge/open77";
import type { MenuView } from "@/bridge/protocol";
import { Badge, Button, Input, ListRow, Panel, SectionHeader, Tabs, Keycap, type TabItem } from "@/design/components";
import { IdentityForm } from "@/features/character/CharacterWizard";
import "./menu.css";

const TABS: TabItem<MenuView>[] = [
  { value: "character", label: "Personnage", icon: "id-card" },
  { value: "vehicles", label: "Véhicules", icon: "car" },
  { value: "staff", label: "Staff", icon: "shield" },
  { value: "help", label: "Aide", icon: "terminal" },
];

/* The main menu (F5): three-column terminal layout from the design system,
   rail / content / detail. Every action is validated by the server; the menu
   only shows what the server said and asks for what the player clicked. */
export function Menu() {
  const open = useStore((s) => s.menuOpen);
  const view = useStore((s) => s.menuView);
  const setView = useStore((s) => s.setMenuView);
  const state = useStore((s) => s.state);
  const lastResult = useStore((s) => s.lastResult);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !e.repeat) { e.preventDefault(); requestClose(); }
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open]);

  if (!open) return null;
  const tabs = TABS.filter((t) => t.value !== "staff" || state.staff.isStaff);
  const name = state.character.registered ? `${state.character.firstName} ${state.character.lastName}` : state.character.accountName;

  return (
    <div className="menu o77-interactive">
      <div className="menu__scrim" onClick={requestClose} />
      <Panel className="menu__frame" chamfer="lg" tone="accent" padding={0} scanlines>
        <header className="menu__head">
          <div>
            <span className="o77-tag o77-accent">OPEN//77 // TERMINAL</span>
            <h1 className="menu__title">{state.server.name}</h1>
          </div>
          <div className="menu__head-right">
            <Badge tone={state.character.registered ? "accent" : "outline"}>{name}</Badge>
            <Badge>ID {String(state.character.playerId).padStart(3, "0")}</Badge>
            <Button variant="ghost" size="sm" icon="x" onClick={requestClose}>Fermer</Button>
          </div>
        </header>
        <div className="menu__grid">
          <Tabs items={tabs} value={view} onChange={setView} orientation="vertical" className="menu__rail" />
          <div className="menu__content">
            {view === "character" && <CharacterView />}
            {view === "vehicles" && <VehiclesView />}
            {view === "staff" && state.staff.isStaff && <StaffView />}
            {view === "help" && <HelpView />}
          </div>
        </div>
        <footer className="menu__foot">
          <span className="o77-readout o77-disabled"><Keycap size="sm">ESC</Keycap> FERMER · <Keycap size="sm">F5</Keycap> MENU</span>
          {lastResult && Date.now() - lastResult.at < 8000 && (
            <span className={"o77-readout " + (lastResult.ok ? "o77-accent" : "menu__foot--bad")}>{lastResult.text}</span>
          )}
        </footer>
      </Panel>
    </div>
  );
}

function CharacterView() {
  const character = useStore((s) => s.state.character);
  const needs = useStore((s) => s.state.needs);
  const [editing, setEditing] = useState(false);
  const origin = character.origins.find((o) => o.key === character.origin)?.label;
  const freeSlots = character.maxSlots - character.slots.length;
  return (
    <div className="menu__stack">
      <SectionHeader index="01" title="Identité" subtitle={character.userId ? `MASTER // ${character.userId.slice(0, 8)}` : "MASTER // —"}
        right={<Button size="sm" variant="ghost" icon="id-card" onClick={() => setEditing((v) => !v)}>{editing ? "Fermer" : "Modifier"}</Button>} />
      {editing ? (
        <IdentityForm character={character} submitLabel="Enregistrer" onSubmitted={() => setEditing(false)} />
      ) : (
        <div className="menu__stats">
          <Stat label="NOM" value={character.firstName ? `${character.firstName} ${character.lastName}` : "—"} />
          <Stat label="NAISSANCE" value={character.birthDate ?? "—"} />
          <Stat label="ORIGINE" value={origin ?? "—"} />
          <Stat label="STATUT" value={character.status === "active" ? "ACTIF" : "BROUILLON"} />
        </div>
      )}
      {character.story && !editing && <p className="menu__story">{character.story}</p>}

      <SectionHeader index="02" title="Apparence" subtitle={character.bodyFamily ? `${character.bodyFamily.toUpperCase()} · RÉVISION ${character.appearanceRevision}` : "NON ENREGISTRÉE"}
        right={character.appearanceSavedAt && <span className="o77-readout o77-disabled">{character.appearanceSavedAt.slice(0, 16)}</span>} />
      <div className="menu__actions">
        <Button size="sm" variant="secondary" icon="user" onClick={() => sendAction({ type: "character.appearance.open", mode: "ripperdoc" })}>Miroir</Button>
        <Button size="sm" variant="secondary" icon="settings" onClick={() => sendAction({ type: "character.appearance.open", mode: "hairdresser" })}>Coiffeur</Button>
        <Button size="sm" variant="secondary" icon="package" onClick={() => sendAction({ type: "character.wardrobe.open" })}>Garde-robe</Button>
        <span className="o77-readout o77-dim">Corps, visage et tenue sont sauvegardés sur le serveur pour ce personnage.</span>
      </div>

      <SectionHeader index="03" title="Personnages" subtitle={`${character.slots.length} / ${character.maxSlots} EMPLACEMENTS`}
        right={<Button size="sm" icon="users" disabled={freeSlots <= 0 || character.status !== "active"} onClick={() => sendAction({ type: "character.new" })}>Nouveau</Button>} />
      <div className="menu__list">
        {character.slots.map((slot) => {
          const current = slot.key === character.key;
          return (
            <ListRow key={slot.key} icon="id-card" selected={current}
              title={slot.name ?? "Personnage sans nom"}
              subtitle={`${slot.status === "active" ? "Actif" : "Brouillon"}${slot.bodyFamily ? ` · ${slot.bodyFamily}` : ""} · ${formatDuration(slot.playtimeMs)} de jeu`}
              meta={slot.key.toUpperCase()}
              right={current ? <Badge tone="accent">EN JEU</Badge> : (
                <>
                  <Button size="sm" variant="secondary" onClick={() => sendAction({ type: "character.select", key: slot.key })}>Jouer</Button>
                  <Button size="sm" variant="ghost" icon="x" onClick={() => sendAction({ type: "character.archive", key: slot.key })} />
                </>
              )} />
          );
        })}
      </div>

      <SectionHeader index="04" title="État" subtitle="BESOINS" />
      <div className="menu__stats">
        <Stat label="FAIM" value={`${Math.round(needs.food)}%`} />
        <Stat label="SOIF" value={`${Math.round(needs.drink)}%`} />
        <Stat label="TEMPS DE JEU" value={formatDuration(character.playtimeMs ?? 0)} />
        <Stat label="COMPTE" value={character.accountName || "—"} />
      </div>
    </div>
  );
}

function VehiclesView() {
  const vehicles = useStore((s) => s.state.vehicles);
  const staff = useStore((s) => s.state.staff);
  const [category, setCategory] = useState<string>("all");
  const categories = Array.from(new Set(vehicles.catalog.map((v) => v.category)));
  const visible = vehicles.catalog.filter((v) => (category === "all" || v.category === category) && (!v.staffOnly || staff.isStaff));
  return (
    <div className="menu__stack">
      <SectionHeader index="03" title="Garage" subtitle={`${vehicles.owned.length} VÉHICULE(S) DEHORS`}
        right={vehicles.owned.length > 0 && <Button size="sm" variant="danger" icon="x" onClick={() => sendAction({ type: "vehicle.return" })}>Rendre</Button>} />
      <Tabs items={[{ value: "all", label: "Tous" }, ...categories.map((c) => ({ value: c, label: c }))]} value={category} onChange={setCategory} />
      <div className="menu__list">
        {visible.map((v) => (
          <ListRow key={v.key} icon="car" title={v.label} subtitle={v.category} meta={v.staffOnly ? "STAFF" : v.key}
            right={<Button size="sm" variant="secondary" onClick={() => sendAction({ type: "vehicle.spawn", key: v.key })}>Appeler</Button>} />
        ))}
        {visible.length === 0 && <span className="o77-readout o77-disabled">AUCUN MODÈLE</span>}
      </div>
    </div>
  );
}

function StaffView() {
  const state = useStore((s) => s.state);
  const [target, setTarget] = useState<string>("me");
  const [announce, setAnnounce] = useState("");
  const targetValue = (): "me" | number => (target === "me" ? "me" : Number(target));
  return (
    <div className="menu__stack">
      <SectionHeader index="04" title="Staff" subtitle={(state.staff.role ?? "ACL").toUpperCase()} />
      <div className="menu__two">
        <label className="o77-input">
          <span className="o77-input__label">CIBLE</span>
          <span className="o77-input__field">
            <select className="o77-input__control menu__select" value={target} onChange={(e) => setTarget(e.target.value)}>
              <option value="me">Moi</option>
              {state.online.map((p) => <option key={p.id} value={p.id}>{String(p.id).padStart(3, "0")} · {p.name}</option>)}
            </select>
          </span>
        </label>
        <div className="menu__actions menu__actions--end">
          <Button size="sm" variant="secondary" icon="heart-pulse" onClick={() => sendAction({ type: "staff.heal", target: targetValue() })}>Soigner</Button>
          <Button size="sm" variant="secondary" icon="users" disabled={target === "me"} onClick={() => sendAction({ type: "staff.bring", target: Number(target) })}>Amener</Button>
        </div>
      </div>
      <span className="o77-readout o77-dim">TÉLÉPORTER LA CIBLE</span>
      <div className="menu__chips">
        {state.locations.map((l) => (
          <Button key={l.name} size="sm" variant="ghost" icon="map-pin" onClick={() => sendAction({ type: "staff.tp", target: targetValue(), location: l.name })}>{l.label}</Button>
        ))}
      </div>
      <SectionHeader title="Annonce" subtitle="TOUT LE SERVEUR" />
      <div className="menu__two">
        <Input label="MESSAGE" icon="radio" value={announce} onChange={(e) => setAnnounce(e.target.value)} placeholder="Message du staff" maxLength={200} />
        <div className="menu__actions menu__actions--end">
          <Button size="sm" icon="radio" disabled={announce.trim().length < 2} onClick={() => { sendAction({ type: "staff.announce", text: announce.trim() }); setAnnounce(""); }}>Envoyer</Button>
        </div>
      </div>
    </div>
  );
}

function HelpView() {
  const rows: Array<[string, string]> = [
    ["texte", "Parole en jeu, 20 m, sous le nom du personnage"],
    ["/w · /s", "Chuchoter (4 m) · crier (45 m)"],
    ["/ooc", "Hors-jeu, tout le serveur"],
    ["/me · /do · /try · /roll", "Action · scène · tentative · dé"],
    ["/pm <id>", "Message privé"],
    ["/car · /cars · /dv", "Appeler, lister, rendre un véhicule"],
    ["/who · /rules · /report", "Présents · règles · signalement"],
  ];
  return (
    <div className="menu__stack">
      <SectionHeader index="05" title="Commandes" subtitle="CHAT" />
      <div className="menu__list">
        {rows.map(([cmd, text]) => <ListRow key={cmd} title={<span className="menu__mono">{cmd}</span>} subtitle={text} />)}
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="menu__stat">
      <span className="o77-readout o77-dim">{label}</span>
      <span className="menu__stat-value">{value}</span>
    </div>
  );
}

function formatDuration(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  return `${String(Math.floor(minutes / 60)).padStart(2, "0")}H${String(minutes % 60).padStart(2, "0")}`;
}
