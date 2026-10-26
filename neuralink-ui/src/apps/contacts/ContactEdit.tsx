/* Add / edit a contact: name, number, favourite; delete with confirmation. */
import { useState } from "react";
import { Hash, Save, Star, Trash2, UserPen, UserPlus, UserRound } from "lucide-react";
import { useStore } from "@/store/store";
import { Window } from "@/components/Window";
import { Avatar, Btn, Field, Toggle } from "@/components/ui";
import { actOrThrow, act } from "@/store/actions";
import { NUMBER_RE } from "@/bridge/protocol";
import { errorText } from "@/bridge/errors";
import { RequestError } from "@/bridge/open77";
import { formatNumberInput } from "@/lib/format";
import { play } from "@/fx/sound";

export function ContactEdit({ id, number: preset, canBack }: { id?: number; number?: string; canBack: boolean }) {
  const existing = useStore((s) => (id != null ? s.state?.contacts.find((c) => c.id === id) : undefined));
  const myNumber = useStore((s) => s.state?.line?.number);
  const [name, setName] = useState(existing?.name ?? "");
  const [number, setNumber] = useState(existing?.number ?? preset ?? "");
  const [favorite, setFavorite] = useState(existing?.favorite ?? false);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [confirmDel, setConfirmDel] = useState(false);

  const nameOk = name.trim().length >= 1 && name.trim().length <= 32;
  const numOk = NUMBER_RE.test(number);
  const close = () => { if (!useStore.getState().back()) useStore.getState().resetView(null); };

  const save = async () => {
    if (!nameOk) { setErr(errorText("invalid_name")); play("error"); return; }
    if (!numOk) { setErr(errorText("invalid_number")); play("error"); return; }
    if (number === myNumber) { setErr(errorText("self")); play("error"); return; }
    setBusy(true); setErr(null);
    try {
      await actOrThrow("contacts.save", { id: existing?.id, name: name.trim(), number, favorite });
      play("select");
      close();
    } catch (e) {
      play("error");
      setErr(errorText(e instanceof RequestError ? e.slug : "unknown"));
      setBusy(false);
    }
  };
  const del = async () => {
    if (!existing) return;
    if (await act("contacts.delete", { id: existing.id })) { play("back"); close(); }
  };

  return (
    <Window
      icon={existing ? <UserPen size={22} /> : <UserPlus size={22} />}
      title={existing ? "Edit contact" : "New contact"}
      subtitle={existing ? existing.number : "Save a neural line"}
      tag="NL//04-EDT"
      canBack={canBack}
      footer={
        <div className="form__bar">
          {existing ? (
            confirmDel ? (
              <span className="form__confirm">
                <span>Delete {existing.name}?</span>
                <Btn small tone="danger" onClick={del}>Delete</Btn>
                <Btn small tone="ghost" onClick={() => setConfirmDel(false)}>Keep</Btn>
              </span>
            ) : <Btn tone="danger" icon={<Trash2 size={16} />} onClick={() => setConfirmDel(true)}>Delete</Btn>
          ) : <span />}
          <Btn tone="sel" icon={<Save size={17} />} onClick={save} disabled={busy}>{busy ? "Saving…" : "Save"}</Btn>
        </div>
      }
    >
      <div className="form form--contact">
        <div className="form__hero">
          <Avatar name={name || "?"} seed={number || "new"} size={96} ring="sel" />
        </div>
        <Field label="Name" icon={<UserRound size={16} />} placeholder="Jackie Welles" value={name} maxLength={32} counter
          onChange={(e) => { setName(e.target.value); setErr(null); }}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void save(); } }} />
        <Field label="Number" icon={<Hash size={16} />} placeholder="555-0000" inputMode="numeric" value={number}
          error={number.length > 0 && number.length === 8 && !numOk ? errorText("invalid_number") : null}
          onChange={(e) => { setNumber(formatNumberInput(e.target.value)); setErr(null); }}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void save(); } }} />
        <Toggle checked={favorite} onChange={setFavorite} label="Favorite" hint="Pin to the phone's favorites" />
        {err && <div className="form__error">{err}</div>}
        <div className="form__note"><Star size={14} /> Contacts are stored on your neural line and follow you across sessions.</div>
      </div>
    </Window>
  );
}
