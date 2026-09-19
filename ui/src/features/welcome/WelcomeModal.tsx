import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { PAGE_EVENTS } from "@/bridge/protocol";
import { Button, HazardStripe, Icon, Keycap, type IconName } from "@/design/components";
import "./welcome.css";

/* The first-spawn briefing. Shown once per account, right after the character
   becomes active (server flag `character.welcomePending`), and again on demand
   from the Help tab. The OK button unlocks after `welcomeReadSeconds` so the
   player reads what kind of server this is before stepping into the city. */

const PILLARS: Array<{ icon: IconName; title: string; text: string }> = [
  {
    icon: "user", title: "Live your life",
    text: "You play a citizen of Night City, not a legend. Your character has a name, a past and a place in the city: stay in character in the chat, /ooc when you need to step out of it.",
  },
  {
    icon: "banknote", title: "Earn your eddies",
    text: "Start small. Take up jobs around town (garbage runs, deliveries, odd gigs), rent an apartment, save up for your first car, and build your life from there.",
  },
  {
    icon: "zap", title: "No pressure",
    text: "This is not serious roleplay. The server exists so you can discover roleplay on Cyberpunk 2077 without the hassle: have fun, respect the others, and let the story happen.",
  },
];

// Served by the resource host next to app.js (ui/public/img, copied by the build).
const HERO_URL = "./img/night-city.jpg";

const HOUSE_RULES = ["Stay in character", "No random kills, no car ramming", "Respect the other players", "/report reaches the staff"];

export function WelcomeModal() {
  const character = useStore((s) => s.state.character);
  const connected = useStore((s) => s.connected);
  const replay = useStore((s) => s.welcomeReplay);
  const setReplay = useStore((s) => s.setWelcomeReplay);
  const pending = character.status === "active" && character.welcomePending;
  const visible = connected && (pending || replay);

  useEffect(() => {
    if (!visible) return;
    emit(PAGE_EVENTS.focus, { active: true });
    return () => emit(PAGE_EVENTS.focus, { active: false });
  }, [visible]);

  if (!visible) return null;
  const close = () => {
    if (pending) sendAction({ type: "welcome.ack" });
    setReplay(false);
  };
  // A replay was asked for on purpose: no need to wait again.
  return <WelcomeBody name={`${character.firstName ?? ""} ${character.lastName ?? ""}`.trim() || character.accountName}
    playerId={character.playerId} readSeconds={replay && !pending ? 0 : character.welcomeReadSeconds ?? 15} onClose={close} />;
}

function WelcomeBody({ name, playerId, readSeconds, onClose }: { name: string; playerId: number; readSeconds: number; onClose: () => void }) {
  const [startedAt] = useState(() => Date.now());
  const [now, setNow] = useState(startedAt);
  useEffect(() => {
    if (readSeconds <= 0) return;
    const timer = setInterval(() => setNow(Date.now()), 100);
    return () => clearInterval(timer);
  }, [readSeconds]);
  const elapsed = (now - startedAt) / 1000;
  const left = Math.max(0, Math.ceil(readSeconds - elapsed));
  const progress = readSeconds > 0 ? Math.min(1, elapsed / readSeconds) : 1;
  const unlocked = left <= 0;

  return (
    <div className="welcome o77-interactive" role="dialog" aria-modal="true" aria-labelledby="welcome-title">
      <div className="welcome__frame">
        <div className="welcome__hero">
          <img className="welcome__hero-img" src={HERO_URL} alt="" draggable={false} />
          <div className="welcome__hero-shade" />
          <div className="welcome__hero-text">
            <span className="o77-tag o77-accent">OPEN//77 // OFFICIAL ROLEPLAY // LIGHT RP</span>
            <h1 id="welcome-title" className="welcome__title">Welcome to Night City<span> !</span></h1>
            <span className="welcome__sub">NEW ARRIVAL · {name.toUpperCase()} · ID {String(playerId).padStart(3, "0")}</span>
          </div>
        </div>
        <HazardStripe height={4} />

        <div className="welcome__body">
          <p className="welcome__lead">
            This is a <b>Light Roleplay</b> server. You are going to live your life in Night City: earn a living,
            find a place to sleep, get around, meet people. The story is whatever you and the others make of it.
          </p>
          <div className="welcome__pillars">
            {PILLARS.map((p, i) => (
              <article key={p.title} className="welcome__pillar">
                <div className="welcome__pillar-head">
                  <span className="welcome__pillar-index">{String(i + 1).padStart(2, "0")}</span>
                  <Icon name={p.icon} size={16} />
                  <h2 className="welcome__pillar-title">{p.title}</h2>
                </div>
                <p className="welcome__pillar-text">{p.text}</p>
              </article>
            ))}
          </div>
          <div className="welcome__rules">
            <span className="o77-readout o77-accent">HOUSE RULES</span>
            <ul className="welcome__rules-list">
              {HOUSE_RULES.map((r) => <li key={r}>{r}</li>)}
            </ul>
            <span className="welcome__keys o77-readout o77-dim">
              <Keycap size="sm">F5</Keycap> MENU · /help COMMANDS
            </span>
          </div>
        </div>

        <footer className="welcome__foot">
          <div className="welcome__timer" aria-live="polite">
            <span className="o77-readout o77-dim">{unlocked ? "READ · YOU MAY ENTER THE CITY" : "TAKE A MOMENT TO READ"}</span>
            <div className="welcome__bar"><div className="welcome__bar-fill" style={{ transform: `scaleX(${progress})` }} /></div>
          </div>
          <Button size="lg" icon="badge-check" disabled={!unlocked} onClick={onClose} className="welcome__ok">
            {unlocked ? "OK, I got it" : `OK in ${left} s`}
          </Button>
        </footer>
      </div>
    </div>
  );
}
