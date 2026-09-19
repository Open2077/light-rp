import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS, type CharacterState, type CharacterStep, type IdentityFields } from "@/bridge/protocol";
import { Badge, Button, HazardStripe, Input, Modal, SectionHeader } from "@/design/components";
import "./wizard.css";

/* Character creation, over the world, driven by the server's `character.step`:
   identity (civil state) -> appearance (native mirror, body saved by
   open77_appearance) -> confirm. The wizard never decides a step is done; it
   shows the step the server still misses and asks. */

const STEPS: Array<{ id: CharacterStep; label: string }> = [
  { id: "identity", label: "IDENTITY" },
  { id: "appearance", label: "APPEARANCE" },
  { id: "confirm", label: "CONFIRM" },
];

function useDialogFocus(active: boolean) {
  useEffect(() => {
    if (!active) return;
    emit(PAGE_EVENTS.focus, { active: true });
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [active]);
}

export function CharacterWizard() {
  const character = useStore((s) => s.state.character);
  const connected = useStore((s) => s.connected);
  const visible = connected && character.status !== "active";
  useDialogFocus(visible);
  if (!visible) return null;
  return <WizardBody character={character} />;
}

function WizardBody({ character }: { character: CharacterState }) {
  const [page, setPage] = useState<CharacterStep>(character.step);
  // Follow the server: when it advances, the page advances; the player may still
  // go back to re-read a step they already filled.
  useEffect(() => { setPage(character.step); }, [character.step]);
  const stepIndex = Math.max(0, STEPS.findIndex((s) => s.id === page));
  const slotLabel = character.key === "default" ? "CHARACTER 1" : `CHARACTER ${character.key.replace("slot", "")}`;

  return (
    <div className="wizard o77-interactive">
      <div className="wizard__void" aria-hidden="true">
        <span className="wizard__void-mark">Open<span>//</span>77</span>
        <span className="wizard__void-tag">CHARACTER CREATION // THE CITY IS WAITING</span>
      </div>
      <div className="wizard__frame">
        <header className="wizard__head">
          <div>
            <span className="o77-tag o77-accent">OPEN//77 // OFFICIAL ROLEPLAY</span>
            <h1 className="wizard__title">New character</h1>
          </div>
          <div className="wizard__head-right">
            <Badge tone="outline">{slotLabel}</Badge>
            <Badge>{character.accountName}</Badge>
          </div>
        </header>
        <HazardStripe height={4} />
        <ol className="wizard__steps">
          {STEPS.map((s, i) => {
            const done = STEPS.findIndex((x) => x.id === character.step) > i || character.step === "done";
            const current = s.id === page;
            return (
              <li key={s.id} className={"wizard__step" + (current ? " wizard__step--on" : "") + (done ? " wizard__step--done" : "")}
                onClick={() => (done || i <= stepIndex) && setPage(s.id)}>
                <span className="wizard__step-index">{String(i + 1).padStart(2, "0")}</span>
                <span className="wizard__step-label">{s.label}</span>
                {done && <span className="wizard__step-check">OK</span>}
              </li>
            );
          })}
        </ol>
        <div className="wizard__content">
          {page === "identity" && <IdentityStep character={character} />}
          {page === "appearance" && <AppearanceStep character={character} />}
          {(page === "confirm" || page === "done") && <ConfirmStep character={character} />}
        </div>
      </div>
    </div>
  );
}

export function IdentityForm({ character, submitLabel, onSubmitted }: { character: CharacterState; submitLabel: string; onSubmitted?: () => void }) {
  const [fields, setFields] = useState<IdentityFields>({
    firstName: character.firstName ?? "", lastName: character.lastName ?? "",
    birthDate: character.birthDate ?? "", origin: character.origin ?? "", story: character.story ?? "",
  });
  const set = (patch: Partial<IdentityFields>) => setFields((f) => ({ ...f, ...patch }));
  const nameOk = fields.firstName.trim().length >= 2 && fields.lastName.trim().length >= 2;
  const birthOk = !fields.birthDate || /^\d{4}-\d{2}-\d{2}$/.test(fields.birthDate);
  const age = fields.birthDate && birthOk ? character.currentYear - Number(fields.birthDate.slice(0, 4)) : null;
  const ageOk = age === null || (age >= character.minAge && age <= 90);
  const valid = nameOk && birthOk && ageOk;
  const submit = () => {
    if (!valid) return;
    sendAction({ type: "character.identity", firstName: fields.firstName.trim(), lastName: fields.lastName.trim(),
      birthDate: fields.birthDate || undefined, origin: fields.origin || undefined, story: fields.story?.trim() || undefined });
    onSubmitted?.();
  };
  return (
    <div className="wizard__stack">
      <div className="wizard__two">
        <Input label="FIRST NAME" icon="user" autoFocus value={fields.firstName} onChange={(e) => set({ firstName: e.target.value })} placeholder="First name" maxLength={24} />
        <Input label="LAST NAME" icon="user" value={fields.lastName} onChange={(e) => set({ lastName: e.target.value })} placeholder="Last name" maxLength={24} />
      </div>
      <div className="wizard__two">
        <Input label={`BORN · NIGHT CITY ${character.currentYear}`} icon="id-card" value={fields.birthDate ?? ""} onChange={(e) => set({ birthDate: e.target.value })}
          placeholder="YYYY-MM-DD" maxLength={10} invalid={!birthOk || !ageOk}
          hint={age !== null && birthOk ? (ageOk ? `${age} YEARS OLD` : `${character.minAge} YEARS MINIMUM`) : "OPTIONAL"} />
        <label className="o77-input">
          <span className="o77-input__label">ORIGIN</span>
          <span className="o77-input__field">
            <select className="o77-input__control wizard__select" value={fields.origin ?? ""} onChange={(e) => set({ origin: e.target.value })}>
              <option value="">—</option>
              {character.origins.map((o) => <option key={o.key} value={o.key}>{o.label}</option>)}
            </select>
          </span>
        </label>
      </div>
      <label className="o77-input">
        <span className="o77-input__label">BACKSTORY · {(fields.story ?? "").length}/600</span>
        <span className="o77-input__field wizard__textarea-field">
          <textarea className="o77-input__control wizard__textarea" value={fields.story ?? ""} onChange={(e) => set({ story: e.target.value.slice(0, 600) })}
            placeholder="A few lines about who you are in Night City. Optional." rows={4} />
        </span>
      </label>
      <div className="wizard__actions">
        <Button icon="badge-check" disabled={!valid} onClick={submit}>{submitLabel}</Button>
        <span className="o77-readout o77-dim">The name is what the others read; your account stays private.</span>
      </div>
    </div>
  );
}

function IdentityStep({ character }: { character: CharacterState }) {
  return (
    <div className="wizard__stack">
      <SectionHeader index="01" title="Identity" subtitle="WHO ARE YOU" />
      <IdentityForm character={character} submitLabel={character.firstName ? "Save" : "Continue"} />
    </div>
  );
}

function AppearanceStep({ character }: { character: CharacterState }) {
  const saved = character.bodyFamily != null;
  return (
    <div className="wizard__stack">
      <SectionHeader index="02" title="Body and face" subtitle={saved ? `${character.bodyFamily?.toUpperCase()} · REVISION ${character.appearanceRevision}` : "NO APPEARANCE SAVED"} />
      <p className="wizard__text">
        The mirror opens the game's character editor. Confirm your look in there: it is saved on the server
        and follows this character every time you connect. Pick the body first.
      </p>
      <div className="wizard__chips">
        <Button variant={character.bodyFamily === "female" ? "primary" : "secondary"} icon="user"
          onClick={() => sendAction({ type: "character.appearance.open", mode: "ripperdoc", family: "female" })}>Female body</Button>
        <Button variant={character.bodyFamily === "male" ? "primary" : "secondary"} icon="user"
          onClick={() => sendAction({ type: "character.appearance.open", mode: "ripperdoc", family: "male" })}>Male body</Button>
        <Button variant="ghost" icon="settings" disabled={!saved}
          onClick={() => sendAction({ type: "character.appearance.open", mode: "hairdresser" })}>Hairdresser</Button>
      </div>
      <p className="wizard__text o77-dim">
        {saved ? "Appearance saved. You can touch it up later from the Character menu." : "Waiting for a first save from the mirror."}
      </p>
    </div>
  );
}

function ConfirmStep({ character }: { character: CharacterState }) {
  const [sent, setSent] = useState(false);
  const origin = character.origins.find((o) => o.key === character.origin)?.label;
  const ready = character.step === "confirm" || character.step === "done";
  return (
    <div className="wizard__stack">
      <SectionHeader index="03" title="Summary" subtitle="ENTER THE CITY" />
      <div className="wizard__summary">
        <Row label="NAME" value={character.firstName ? `${character.firstName} ${character.lastName}` : "—"} />
        <Row label="BORN" value={character.birthDate ? `${character.birthDate} · ${character.currentYear - Number(character.birthDate.slice(0, 4))} YEARS OLD` : "—"} />
        <Row label="ORIGIN" value={origin ?? "—"} />
        <Row label="BODY" value={character.bodyFamily ? character.bodyFamily.toUpperCase() : (character.appearanceTracked ? "NOT SAVED" : "NOT TRACKED")} />
        {character.story && <Row label="BACKSTORY" value={character.story} wide />}
      </div>
      <div className="wizard__actions">
        <Button size="lg" icon="badge-check" disabled={!ready || sent} onClick={() => { setSent(true); sendAction({ type: "character.finish" }); setTimeout(() => setSent(false), 3000); }}>
          Enter Night City
        </Button>
        <Button variant="ghost" icon="package" onClick={() => sendAction({ type: "character.wardrobe.open" })}>Wardrobe</Button>
        {!ready && <span className="o77-readout wizard__missing">One step is still missing.</span>}
      </div>
    </div>
  );
}

function Row({ label, value, wide }: { label: string; value: string; wide?: boolean }) {
  return (
    <div className={"wizard__row" + (wide ? " wizard__row--wide" : "")}>
      <span className="o77-readout o77-dim">{label}</span>
      <span className="wizard__row-value">{value}</span>
    </div>
  );
}

// Used by the Personnage tab too.
export { Modal as WizardModal };
