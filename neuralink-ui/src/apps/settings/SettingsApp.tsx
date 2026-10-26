/* Settings: ringtone (preview played by Lua), volume, do-not-disturb, accent
   theme, hologram intensity. Changes apply at once and save debounced. */
import { BellOff, Cpu, Palette, Play, Settings as SettingsIcon, Volume2 } from "lucide-react";
import { useStore, useSettings, type SettingsSection } from "@/store/store";
import type { Accent, Ringtone, Style } from "@/bridge/protocol";
import { Window } from "@/components/Window";
import { Segmented, SectionTitle, Slider, Toggle } from "@/components/ui";
import { changeSettings } from "@/store/actions";
import { emitSound } from "@/bridge/open77";
import { play } from "@/fx/sound";

const RINGTONES: { id: Ringtone; label: string; hint: string }[] = [
  { id: "aurora", label: "Holocall", hint: "The implant's own ring" },
  { id: "link", label: "Rockerboy", hint: "Kerry's private line" },
  { id: "pulse", label: "Landline", hint: "An old corded phone" },
  { id: "silent", label: "Silent", hint: "Vibration only" },
];

const STYLES: { id: Style; label: string; hint: string }[] = [
  { id: "cyberpunk", label: "Night City", hint: "Navy glass, cut corners, red selection" },
  { id: "sao", label: "Aincrad", hint: "The original holographic glass" },
];

const ACCENTS: { id: Accent; label: string; hint: string }[] = [
  { id: "sao", label: "Aincrad", hint: "White glass, gold selection" },
  { id: "cyan", label: "Netrunner", hint: "Ice cyan, magenta edges" },
  { id: "magenta", label: "Kabuki", hint: "Neon magenta, cyan edges" },
];

export function SettingsApp({ section, canBack }: { section: SettingsSection; canBack: boolean }) {
  const set = (s: SettingsSection) => useStore.getState().replaceTop({ app: "settings", section: s });
  return (
    <Window icon={<SettingsIcon size={22} />} title="Settings" subtitle="Neural-Link preferences" tag="NL//05-CFG" canBack={canBack} bodyClass="settings">
      <Segmented
        value={section}
        onChange={set}
        options={[
          { id: "sound", label: "Sound", icon: <Volume2 size={15} /> },
          { id: "display", label: "Hologram", icon: <Palette size={15} /> },
          { id: "about", label: "System", icon: <Cpu size={15} /> },
        ]}
      />
      <div className="settings__pane nl-scroll" key={section}>
        {section === "sound" && <SoundSection />}
        {section === "display" && <DisplaySection />}
        {section === "about" && <AboutSection />}
      </div>
    </Window>
  );
}

function SoundSection() {
  const s = useSettings();
  return (
    <>
      <SectionTitle>Ringtone</SectionTitle>
      <div className="rings">
        {RINGTONES.map((r, i) => (
          <div key={r.id} className={`ring-opt ${s.ringtone === r.id ? "is-on" : ""}`} style={{ ["--i" as string]: i }}>
            <button type="button" className="ring-opt__main" onClick={() => { play("select"); changeSettings({ ringtone: r.id }, 0); }}>
              <span className="ring-opt__radio" />
              <span className="ring-opt__text"><span className="label">{r.label}</span><span>{r.hint}</span></span>
            </button>
            {r.id !== "silent" && (
              <button type="button" className="ring-opt__play" aria-label={`Preview ${r.label}`} onClick={() => emitSound(`preview:${r.id}`)}>
                <Play size={16} />
              </button>
            )}
          </div>
        ))}
      </div>
      <SectionTitle>Levels</SectionTitle>
      <Slider label="Volume" value={s.volume} onInput={(v) => changeSettings({ volume: v })} onCommit={() => play("select")} />
      <Toggle checked={s.dnd} onChange={(v) => changeSettings({ dnd: v }, 0)} label="Do not disturb" hint="No ringtone, silent notifications" />
      {s.dnd && <div className="form__note"><BellOff size={14} /> Calls still reach you; the ringtone and notification sounds are muted.</div>}
    </>
  );
}

function DisplaySection() {
  const s = useSettings();
  return (
    <>
      <SectionTitle>Interface</SectionTitle>
      <div className="accents">
        {STYLES.map((st) => (
          <button
            key={st.id}
            type="button"
            className={`accent accent--style-${st.id} ${s.style === st.id ? "is-on" : ""}`}
            onClick={() => { play("select"); changeSettings({ style: st.id }, 0); }}
          >
            <span className="accent__swatch"><i /><i /><i /></span>
            <span className="label">{st.label}</span>
            <span className="accent__hint">{st.hint}</span>
          </button>
        ))}
      </div>
      {s.style === "sao" && <SaoLook />}
      <SectionTitle>Hologram</SectionTitle>
      <Slider label="Intensity" min={0.3} max={1} value={s.intensity} onInput={(v) => changeSettings({ intensity: v })} display={`${Math.round(s.intensity * 100)}%`} />
      <div className="form__note">Glow, scanlines and ambient particles follow this level.</div>
    </>
  );
}

/** Theme and accent only exist for the SAO look: Night City has its own colours. */
function SaoLook() {
  const s = useSettings();
  return (
    <>
      <SectionTitle>Theme</SectionTitle>
      <Toggle checked={s.theme === "dark"} onChange={(v) => changeSettings({ theme: v ? "dark" : "light" }, 0)} label="Dark mode" hint="Smoked black glass, light text" />
      <SectionTitle>Accent</SectionTitle>
      <div className="accents">
        {ACCENTS.map((a) => (
          <button
            key={a.id}
            type="button"
            className={`accent accent--${a.id} ${s.accent === a.id ? "is-on" : ""}`}
            onClick={() => { play("select"); changeSettings({ accent: a.id }, 0); }}
          >
            <span className="accent__swatch"><i /><i /><i /></span>
            <span className="label">{a.label}</span>
            <span className="accent__hint">{a.hint}</span>
          </button>
        ))}
      </div>
    </>
  );
}

function AboutSection() {
  const line = useStore((s) => s.state?.line ?? null);
  const apps = useStore((s) => s.state?.apps.length ?? 0);
  const rows: [string, string][] = [
    ["System", "Neural-Link OS 2.7.7"],
    ["Firmware", "Kiroshi Optics / NL-77 bridge"],
    ["Line", line ? `${line.number} · ${line.name}` : "Not assigned"],
    ["Third-party apps", String(apps)],
    ["Encryption", "Quantum-sealed, end-to-end"],
    ["Manufacturer", "Zetatech for Open//77"],
  ];
  return (
    <>
      <SectionTitle>System</SectionTitle>
      <dl className="about">
        {rows.map(([k, v]) => (<div key={k}><dt className="label">{k}</dt><dd className="mono">{v}</dd></div>))}
      </dl>
      <div className="form__note">Press Esc to go back a level. Close the link from the bottom of the column.</div>
    </>
  );
}
