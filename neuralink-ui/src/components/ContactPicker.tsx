/* Pick contacts or type raw numbers. Single mode calls onPick; multi mode keeps
   a chip list (used by New group). */
import { useMemo, useState } from "react";
import { listKeys, useWindowKeys } from "@/shell/keys";
import { Check, Hash, Plus, Search, X } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import { NUMBER_RE } from "@/bridge/protocol";
import { displayName, formatNumberInput } from "@/lib/format";
import { Avatar, Field, IconBtn } from "./ui";
import { play } from "@/fx/sound";

export interface ContactPickerProps {
  mode: "single" | "multi";
  exclude?: string[];
  selected?: string[];
  max?: number;
  onPick?: (number: string) => void;
  onChange?: (numbers: string[]) => void;
  pickLabel?: string;
}

export function ContactPicker({ mode, exclude = [], selected = [], max = 15, onPick, onChange, pickLabel = "Select" }: ContactPickerProps) {
  const contacts = useStore((s) => s.state?.contacts ?? EMPTY);
  const myNumber = useStore((s) => s.state?.line?.number);
  const [q, setQ] = useState("");
  const [raw, setRaw] = useState("");
  const [rawErr, setRawErr] = useState<string | null>(null);

  const list = useMemo(() => {
    const ql = q.trim().toLowerCase();
    return [...contacts]
      .filter((c) => !exclude.includes(c.number) && c.number !== myNumber)
      .filter((c) => !ql || c.name.toLowerCase().includes(ql) || c.number.includes(ql))
      .sort((a, b) => Number(b.online) - Number(a.online) || a.name.localeCompare(b.name));
  }, [contacts, q, exclude, myNumber]);

  const full = mode === "multi" && selected.length >= max;
  const [kbd, setKbd] = useState(-1);

  const choose = (number: string) => {
    if (mode === "single") { play("select"); onPick?.(number); return; }
    if (selected.includes(number)) { play("back"); onChange?.(selected.filter((n) => n !== number)); return; }
    if (full) { play("error"); return; }
    play("select");
    onChange?.([...selected, number]);
  };

  useWindowKeys(useMemo(() => listKeys(list.length, kbd, setKbd, (i) => { const c = list[i]; if (c) choose(c.number); }), [list, kbd, selected])); // eslint-disable-line

  const addRaw = () => {
    if (!NUMBER_RE.test(raw)) { setRawErr("Numbers look like 555-0123."); play("error"); return; }
    if (raw === myNumber) { setRawErr("That is your own number."); play("error"); return; }
    if (exclude.includes(raw)) { setRawErr("Already included."); play("error"); return; }
    setRawErr(null);
    choose(raw);
    setRaw("");
  };

  return (
    <div className="picker">
      {mode === "multi" && selected.length > 0 && (
        <div className="chips">
          {selected.map((n) => (
            <span key={n} className="chip">
              <span>{displayName(contacts, n)}</span>
              <button type="button" aria-label="Remove" onClick={() => choose(n)}><X size={13} strokeWidth={2.6} /></button>
            </span>
          ))}
          <span className="chips__count mono">{selected.length}/{max}</span>
        </div>
      )}
      <div className="picker__row">
        <Field icon={<Search size={16} />} placeholder="Search contacts" value={q} onChange={(e) => setQ(e.target.value)} />
        <Field
          icon={<Hash size={16} />}
          placeholder="555-0000"
          inputMode="numeric"
          value={raw}
          error={rawErr}
          className="picker__raw"
          onChange={(e) => { setRaw(formatNumberInput(e.target.value)); setRawErr(null); }}
          onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); addRaw(); } }}
        />
        <IconBtn label={mode === "multi" ? "Add number" : pickLabel} tone="sel" onClick={addRaw} disabled={raw.length === 0}>
          <Plus size={18} strokeWidth={2.6} />
        </IconBtn>
      </div>
      <div className="picker__list nl-scroll">
        {list.length === 0 && <div className="picker__none">{contacts.length === 0 ? "No contacts yet. Type a number above." : "No match."}</div>}
        {list.map((c, i) => {
          const on = selected.includes(c.number);
          return (
            <button
              key={c.id}
              type="button"
              className={`prow ${on ? "is-on" : ""} ${kbd === i ? "is-kbd" : ""}`}
              style={{ ["--i" as string]: Math.min(i, 12) }}
              disabled={mode === "multi" && full && !on}
              onClick={() => choose(c.number)}
            >
              <Avatar name={c.name} seed={c.number} size={36} online={c.online} />
              <span className="prow__text">
                <span className="prow__name">{c.name}</span>
                <span className="prow__num mono">{c.number}</span>
              </span>
              {mode === "multi" ? (
                <span className={`check ${on ? "is-on" : ""}`}>{on && <Check size={14} strokeWidth={3} />}</span>
              ) : (
                <span className="prow__pick label">{pickLabel}</span>
              )}
            </button>
          );
        })}
      </div>
    </div>
  );
}
