import { useEffect, useState } from "react";
import { Icon } from "@/design/components";
import { emit } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import "./lessons.css";

export type VoiceSetup = {
  available: boolean; configured: boolean; captureEnabled: boolean; inputDevice: string; outputDevice: string;
  inputs: Array<{ id: string; name: string }>; outputs: Array<{ id: string; name: string }>;
  inputVolume: number; outputVolume: number; activation: boolean; threshold: number; key: string;
  level: number; testing: boolean; signalDetected: boolean; distance: number; captureState?: string; rangeKey?: string;
};
const voice = (action: string, data: Record<string, unknown> = {}) => emit(PAGE_EVENTS.tutorial, { operation: "voice", action, ...data });
const setting = (name: string, value: string | number) => voice("set", { name, value });
const steps = ["Your choice", "Devices", "How you speak", "Sound check"];

function Gain({ label, value, name, detail }: { label: string; value: number; name: string; detail: string }) {
  const [draft, setDraft] = useState(Math.round(value * 100));
  useEffect(() => setDraft(Math.round(value * 100)), [value]);
  return <label className="voice-lesson__field"><span>{label}<b>{draft}%</b></span>
    <input type="range" min={0} max={200} value={draft} onChange={e => setDraft(+e.target.value)} onPointerUp={() => setting(name, draft)} onKeyUp={() => setting(name, draft)} onBlur={() => { if (draft !== Math.round(value * 100)) setting(name, draft); }} />
    <small>{detail}</small></label>;
}

export function VoiceTutorial({ state, error }: { state?: VoiceSetup; error?: string }) {
  const [step, setStep] = useState(0), [binding, setBinding] = useState(false), [heard, setHeard] = useState(false);
  const [bindingError, setBindingError] = useState("");
  useEffect(() => { voice("begin"); return () => voice("end"); }, []);
  useEffect(() => { setHeard(false); }, [state?.inputDevice, state?.outputDevice]);
  useEffect(() => {
    if (!binding) return;
    const accept = (key: string) => { setting("PushToTalkKey", key); setBinding(false); setBindingError(""); };
    const key = (e: KeyboardEvent) => {
      e.preventDefault(); e.stopImmediatePropagation();
      if (e.repeat) return;
      if (e.key === "Escape") { setBinding(false); return; }
      const names: Record<string, string> = { Space: "SPACE", Enter: "ENTER", Tab: "TAB", ShiftLeft: "SHIFT", ShiftRight: "SHIFT", ControlLeft: "CTRL", ControlRight: "CTRL", AltLeft: "ALT", AltRight: "ALT", CapsLock: "CAPSLOCK", Backspace: "BACKSPACE", Insert: "INSERT", Delete: "DELETE", Home: "HOME", End: "END", PageUp: "PAGEUP", PageDown: "PAGEDOWN", ArrowUp: "UP", ArrowDown: "DOWN", ArrowLeft: "LEFT", ArrowRight: "RIGHT" };
      const result = /^Key[A-Z]$/.test(e.code) ? e.code.slice(3) : /^Digit\d$/.test(e.code) ? e.code.slice(5) : /^F([1-9]|1[0-2])$/.test(e.code) ? e.code : names[e.code];
      if (result) accept(result); else setBindingError("Choose a letter, number, function key, modifier or mouse button.");
    };
    const mouse = (e: MouseEvent) => {
      e.preventDefault(); e.stopImmediatePropagation();
      const result = ["MOUSE1", "MOUSE3", "MOUSE2", "MOUSE4", "MOUSE5"][e.button];
      if (!result) return;
      const swallow = (event: Event) => { event.preventDefault(); event.stopImmediatePropagation(); };
      window.addEventListener("click", swallow, { capture: true, once: true });
      setTimeout(() => window.removeEventListener("click", swallow, true), 500);
      accept(result);
    };
    const cancel = (e: Event) => e.preventDefault();
    window.addEventListener("keydown", key, true); window.addEventListener("mousedown", mouse, true); window.addEventListener("contextmenu", cancel, true);
    return () => { window.removeEventListener("keydown", key, true); window.removeEventListener("mousedown", mouse, true); window.removeEventListener("contextmenu", cancel, true); };
  }, [binding]);
  const level = Math.round(Math.max(0, Math.min(1, state?.level ?? 0)) * 100);
  const changeStep = (n: number) => { setBinding(false); if (step === 3) voice("test", { value: false }); setStep(n); };
  const ready = !!state?.available;
  return <section className="voice-lesson" aria-label="Voice setup guide">
    <aside className="voice-lesson__rail">
      <span className="first-day__eyebrow">FIRST DAY / COMMUNICATION</span>
      <div className="voice-lesson__mark"><Icon name="mic" size={42} /></div>
      <h2>Find your<br /><em>voice.</em></h2>
      <p>A few settings. A clear signal. People nearby hear you as part of the world.</p>
      <ol>{steps.map((label, i) => <li key={label} className={i === step ? "is-now" : i < step ? "is-done" : ""}><span>{i < step ? <Icon name="check" size={14} /> : `0${i + 1}`}</span>{label}</li>)}</ol>
      <small><Icon name="shield" size={15} />The sound check plays back locally. Voice activation resumes when you leave setup.</small>
    </aside>
    <div className="voice-lesson__main">
      <header><span className="first-day__eyebrow">0{step + 1} / 04 · {steps[step]?.toUpperCase()}</span><span>OPTIONAL</span></header>
      <div className="voice-lesson__body">
        {step === 0 && <>
          <h3>Be heard. On your terms.</h3><p>Use a microphone for nearby conversations, or keep playing with text. This guide will never block your arrival.</p>
          {state?.configured && <div className="voice-lesson__notice"><Icon name="check-check" />You already completed voice setup on this server. Keep it, or check it again.</div>}
          <div className="voice-lesson__choices">
            <button className="voice-lesson__choice" onClick={() => changeStep(1)}><Icon name="settings" size={25} /><span><b>Set up my voice</b><small>Devices, talk key and a local sound check.</small></span><Icon name="arrow-right" /></button>
            <button className="voice-lesson__choice" onClick={() => voice("configured")}><Icon name="check-check" size={25} /><span><b>My voice is already configured</b><small>Keep my current settings and continue.</small></span><Icon name="arrow-right" /></button>
            <button className="voice-lesson__choice" onClick={() => voice("skip")}><Icon name="message-square" size={25} /><span><b>Continue without voice setup</b><small>Use text chat. Configure voice whenever you like.</small></span><Icon name="arrow-right" /></button>
          </div>
          <div className="voice-lesson__tip"><Icon name="info" /><span>Skipping leaves your current audio settings unchanged. You can disable your microphone in Devices or in Pause → Settings → Voice.</span></div>
        </>}
        {step === 1 && <>
          <h3>Choose what you hear.</h3><p>Pick your microphone and the headset that should play other players. Headphones help prevent echo.</p>
          <div className="voice-lesson__devices">{([['input', 'Microphone'], ['output', 'Voice output']] as const).map(([flow, label]) => {
            const selected = flow === 'input' ? state?.inputDevice : state?.outputDevice;
            const devices = flow === 'input' ? state?.inputs : state?.outputs;
            return <label className="voice-lesson__field" key={flow}><span>{label}</span><select aria-label={label} disabled={!state} value={selected ?? ''} onChange={e => setting(flow === 'input' ? 'InputDevice' : 'OutputDevice', e.target.value)}>
              {selected && !devices?.some(d => d.id === selected) && <option value={selected}>Saved device unavailable — choose another</option>}
              {(devices?.length ? devices : [{ id: '', name: 'Waiting for audio devices…' }]).map(d => <option key={d.id} value={d.id}>{d.id === '' ? 'Windows communications default' : d.name}</option>)}</select></label>;
          })}</div>
          <button className="voice-lesson__text-button" onClick={() => voice("refresh")}><Icon name="settings" size={14} />Refresh devices</button>
          <Gain label="Microphone gain" name="InputVolume" value={state?.inputVolume ?? 1} detail="Start at 100%. Lower it if your voice sounds distorted." />
          <Gain label="Other players' volume" name="OutputVolume" value={state?.outputVolume ?? 1} detail="This changes voice audio, not music or game effects." />
          <label className="voice-lesson__check"><input type="checkbox" checked={state?.captureEnabled ?? false} onChange={e => setting("CaptureEnabled", e.target.checked ? 1 : 0)} />Enable my microphone</label>
        </>}
        {step === 2 && <>
          <h3>Decide when to speak.</h3><p>Push-to-talk gives you control in a noisy room. Voice activation opens the microphone when your voice crosses a threshold.</p>
          <div className="voice-lesson__modes">{[{ value: false, label: 'Push-to-talk', icon: 'keyboard', text: 'Hold a key or mouse button. Release to stop.' }, { value: true, label: 'Voice activation', icon: 'mic', text: 'Speak naturally. Tune the threshold below.' }].map(m => <button key={m.label} aria-pressed={state?.activation === m.value} onClick={() => setting("VoiceActivation", m.value ? 1 : 0)}><Icon name={m.icon} size={22} /><b>{m.label}</b><small>{m.text}</small></button>)}</div>
          {state?.activation ? <label className="voice-lesson__field"><span>Activation threshold<b>{Math.round(state.threshold * 100)}%</b></span><input aria-label="Activation threshold" type="range" min={0} max={100} value={Math.round(state.threshold * 100)} onChange={e => setting("VoiceActivationThreshold", +e.target.value)} /><small>Keep room noise below the marker and your normal speaking voice above it. You can watch both in the sound check.</small></label>
            : <div className="voice-lesson__binding"><div><b>Push-to-talk button</b><small>Keyboard and all five mouse buttons are supported.</small></div><button aria-label="Change push-to-talk button" className={binding ? "is-listening" : ""} onClick={() => { setBinding(true); setBindingError(""); }}>{binding ? "Press a key / mouse button…" : state?.key ?? 'N'}</button></div>}
          {binding && <p role="status">Waiting for your button. Press Escape to cancel.</p>}{bindingError && <p role="alert">{bindingError}</p>}
          <div className="voice-lesson__tip"><Icon name="mouse-pointer-click" /><span>A side mouse button keeps your movement keys free. Avoid Alt: you need it for the interaction menu.</span></div>
        </>}
        {step === 3 && <>
          <h3>Say something. Hear yourself.</h3><p>Start the local test and say: “Hi, can you hear me clearly?” Your meter should move while you speak and settle when you stop.</p>
          <div className="voice-lesson__signal"><div><span>{state?.testing ? 'LOCAL MICROPHONE TEST' : 'MICROPHONE LEVEL'}</span><b>{level}%</b></div><div className="voice-lesson__meter" role="meter" aria-label="Microphone level" aria-valuemin={0} aria-valuemax={100} aria-valuenow={level}>
            {Array.from({ length: 24 }, (_, i) => <i key={i} className={i < level * .24 ? 'is-lit' : ''} />)}{state?.activation && <b className="voice-lesson__threshold" style={{ left: `${state.threshold * 100}%` }} />}</div>
            <small>{state?.signalDetected ? 'Microphone signal detected' : 'Waiting for a real microphone signal'}{state?.activation ? ` · threshold ${Math.round(state.threshold * 100)}%` : ''}</small>
          </div>
          <button className={state?.testing ? '' : 'first-day__primary'} disabled={!ready || !state?.captureEnabled} onClick={() => voice("test", { value: !state?.testing })}><Icon name={state?.testing ? 'mic-off' : 'mic'} />{state?.testing ? 'Stop local test' : 'Start local test'}</button>
          {!state?.captureEnabled && <p className="voice-lesson__warning">Your microphone is disabled. Enable it in Devices, or skip voice setup.</p>}
          <label className="voice-lesson__check"><input type="checkbox" checked={heard} disabled={!state?.signalDetected} onChange={e => setHeard(e.target.checked)} />I can hear myself clearly, without echo or distortion.</label>
          <details><summary>No sound, too quiet or echo?</summary><p>Check the microphone's hardware mute switch and Windows microphone access. Refresh devices if you just plugged it in. Select your actual headset, start at 100% gain, and keep speakers away from the microphone. A moving meter proves input; the checkbox confirms that you heard the output.</p></details>
          <div className="voice-lesson__range"><Icon name="radio" size={22} /><div><b>Next: talk to people nearby</b><p>{state?.activation ? 'Speak above your threshold.' : `Hold ${state?.key ?? 'N'} while speaking.`} Current reach: {state?.distance ?? 20} m. {state?.rangeKey ?? 'F11'} cycles the server's voice ranges; watch the HUD for the active range. Nearby players hear you only when the HUD says you are transmitting.</p></div></div>
        </>}
        {!ready && step > 0 && <div className="voice-lesson__warning" role="status">Voice audio is not ready. Check your devices, retry, or skip this optional lesson.<button onClick={() => voice("begin")}>Retry audio</button></div>}
        {error && <p className="voice-lesson__warning" role="alert">{error}</p>}
      </div>
      <footer><button className="voice-lesson__text-button" onClick={() => voice("skip")}>Skip voice setup</button><div>{step > 0 && <button onClick={() => changeStep(step - 1)}><Icon name="chevron-left" />Back</button>}{step > 0 && step < 3 && <button className="first-day__primary" disabled={!ready || binding} onClick={() => changeStep(step + 1)}>Continue<Icon name="arrow-right" /></button>}{step === 3 && <button className="first-day__primary" disabled={!heard || !state?.signalDetected} onClick={() => voice("complete")}>Save & continue<Icon name="check" /></button>}</div></footer>
      <small className="voice-lesson__return">Always available in Pause → Settings → Voice. Key bindings accept mouse buttons too.</small>
    </div>
  </section>;
}
