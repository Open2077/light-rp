/* Status: the identity card. Name, copyable number, Night City time and
   weather, today's activity, contacts online. */
import { useMemo, useState, type ReactNode } from "react";
import { Activity, Copy, Fingerprint, MessageSquare, Phone, PhoneMissed, Signal, Users } from "lucide-react";
import { EMPTY, useStore } from "@/store/store";
import { Window } from "@/components/Window";
import { Avatar, Btn, SectionTitle } from "@/components/ui";
import { WeatherIcon } from "@/components/Weather";
import { copyText, pad2, startOfDay } from "@/lib/format";
import { unreadTotal } from "@/shell/menu";
import { play } from "@/fx/sound";

export function StatusApp({ canBack }: { canBack: boolean }) {
  const state = useStore((s) => s.state);
  const clock = useStore((s) => s.clock);
  const seenToday = useStore((s) => s.seenToday);
  const recents = useStore((s) => s.state?.recents ?? EMPTY);
  const threads = useStore((s) => s.state?.threads ?? EMPTY);
  const [copied, setCopied] = useState(false);
  const line = state?.line ?? null;

  const today = useMemo(() => {
    const day = startOfDay(Date.now());
    const calls = recents.filter((r) => r.at >= day);
    return {
      calls: calls.filter((r) => r.status === "answered").length,
      missed: calls.filter((r) => r.direction === "in" && r.status === "missed").length,
      talk: calls.reduce((n, r) => n + (r.duration || 0), 0),
      // Seen this session in loaded threads, at least one per thread active today.
      messages: Math.max(Object.keys(seenToday).length, threads.filter((t) => t.last && t.last.kind === "text" && t.last.at >= day).length),
    };
  }, [recents, seenToday, threads]);

  const contacts = state?.contacts ?? [];
  const online = contacts.filter((c) => c.online).length;

  const copy = async () => {
    if (!line) return;
    const ok = await copyText(line.number);
    play(ok ? "select" : "error");
    setCopied(ok);
    window.setTimeout(() => setCopied(false), 1500);
  };

  return (
    <Window icon={<Fingerprint size={22} />} title="Status" subtitle="Neural identity" tag="NL//01-ID" canBack={canBack}>
      <div className="status nl-scroll">
        <div className="status__id">
          <div className="status__avatar">
            <Avatar name={line?.name ?? "?"} seed={line?.number ?? "x"} size={112} ring="sel" />
            <svg className="status__orbit" viewBox="0 0 140 140" aria-hidden><circle cx="70" cy="70" r="66" /></svg>
          </div>
          <div className="status__who">
            <div className="status__name">{line?.name ?? "No line assigned"}</div>
            <div className="status__numrow">
              <span className="status__num mono">{line?.number ?? "--- ----"}</span>
              <Btn small tone="ghost" icon={<Copy size={15} />} onClick={copy} disabled={!line}>{copied ? "Copied" : "Copy"}</Btn>
            </div>
            <div className="status__chips">
              <span className={`pill ${line ? "pill--ok" : "pill--danger"}`}><Signal size={13} /> {line ? "Linked" : "Offline"}</span>
              <span className="pill"><Users size={13} /> {online}/{contacts.length} contacts online</span>
            </div>
          </div>
          <div className="status__clock">
            <div className="status__time mono">{clock ? `${pad2(clock.hours)}:${pad2(clock.minutes)}` : "--:--"}</div>
            <div className="status__weather"><WeatherIcon weather={clock?.weather} size={22} /> {clock?.weather ?? "Weather unavailable"}</div>
            <div className="status__city label">Night City · NCT</div>
          </div>
        </div>

        <SectionTitle>Today</SectionTitle>
        <div className="stats">
          <Stat icon={<MessageSquare size={20} />} value={today.messages} label="Messages" />
          <Stat icon={<Phone size={20} />} value={today.calls} label="Calls" />
          <Stat icon={<PhoneMissed size={20} />} value={today.missed} label="Missed" alert={today.missed > 0} />
          <Stat icon={<Activity size={20} />} value={unreadTotal(state)} label="Unread" />
        </div>

        <SectionTitle aside={<span className="mono status__sync">{online} online</span>}>Neural network</SectionTitle>
        <div className="netlist">
          {contacts.length === 0 && <span className="netlist__none">No contacts linked yet.</span>}
          {[...contacts].sort((a, b) => Number(b.online) - Number(a.online) || a.name.localeCompare(b.name)).map((c, i) => (
            <span key={c.id} className={`netlist__c ${c.online ? "is-on" : ""}`} style={{ ["--i" as string]: i }} title={`${c.name} · ${c.number}`}>
              <Avatar name={c.name} seed={c.number} size={46} online={c.online} />
              <span>{c.name.split(" ")[0]}</span>
            </span>
          ))}
        </div>
      </div>
    </Window>
  );
}

function Stat({ icon, value, label, alert }: { icon: ReactNode; value: number; label: string; alert?: boolean }) {
  return (
    <div className={`stat ${alert ? "is-alert" : ""}`}>
      <span className="stat__icon">{icon}</span>
      <span className="stat__val mono">{value}</span>
      <span className="stat__label label">{label}</span>
    </div>
  );
}
