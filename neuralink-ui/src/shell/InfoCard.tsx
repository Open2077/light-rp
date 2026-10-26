/* SAO-style player card left of the column: name, line number, neural sync
   bar, Night City time and weather, link quality. */
import { useEffect, useState } from "react";
import { Copy, MessageSquare, PhoneMissed } from "lucide-react";
import { useStore } from "@/store/store";
import { copyText, pad2 } from "@/lib/format";
import { play } from "@/fx/sound";
import { WeatherIcon } from "@/components/Weather";
import { missedSince, unreadTotal } from "./menu";

/** Slowly drifting "neural sync" value, 94..99.9 %. Purely cosmetic. */
export function useSync(): number {
  const [v, setV] = useState(97.4);
  useEffect(() => {
    const t = window.setInterval(() => setV((x) => Math.max(94, Math.min(99.9, x + (Math.random() - 0.5) * 1.2))), 2400);
    return () => window.clearInterval(t);
  }, []);
  return v;
}

export function InfoCard() {
  const line = useStore((s) => s.state?.line ?? null);
  const clock = useStore((s) => s.clock);
  const state = useStore((s) => s.state);
  const seen = useStore((s) => s.recentsSeenAt);
  const sync = useSync();
  const [copied, setCopied] = useState(false);
  const unread = unreadTotal(state);
  const missed = missedSince(state, seen);

  const copy = async () => {
    if (!line) return;
    const ok = await copyText(line.number);
    play(ok ? "select" : "error");
    setCopied(ok);
    window.setTimeout(() => setCopied(false), 1400);
  };

  return (
    <div className="tilt tilt--card">
      <aside className="card nl-hit">
        <div className="card__top">
          <span className="card__brand mono">NEURAL-LINK</span>
          <span className="card__fw mono">OS 2.7.7</span>
        </div>
        <div className="card__name">{line?.name ?? "Unlinked"}</div>
        <button type="button" className="card__num" onClick={copy} disabled={!line} title="Copy number">
          <span className="mono">{line?.number ?? "---- ----"}</span>
          <Copy size={14} strokeWidth={2.4} />
          <span className={`card__copied ${copied ? "is-on" : ""}`}>Copied</span>
        </button>

        <div className="card__bar">
          <span className="card__bar-label label">Sync</span>
          <span className="card__bar-track">
            <span className="card__bar-fill" style={{ transform: `scaleX(${line ? sync / 100 : 0.08})` }} />
            <span className="card__bar-seg" aria-hidden />
          </span>
          <span className="card__bar-val mono">{line ? `${sync.toFixed(1)}%` : "0%"}</span>
        </div>

        <div className="card__row">
          <div className="card__time">
            <span className="mono card__clock">{clock ? `${pad2(clock.hours)}:${pad2(clock.minutes)}` : "--:--"}</span>
            <span className="card__city label">Night City</span>
          </div>
          <div className="card__weather">
            <WeatherIcon weather={clock?.weather} size={26} />
            <span>{clock?.weather ?? "No data"}</span>
          </div>
        </div>

        <div className="card__foot">
          <span className={`card__signal ${line ? "" : "is-off"}`} aria-label="link quality">
            {[0, 1, 2, 3, 4].map((i) => <i key={i} style={{ ["--i" as string]: i }} />)}
          </span>
          <span className="card__stat" title="Unread messages"><MessageSquare size={15} /> <b className="mono">{unread}</b></span>
          <span className={`card__stat ${missed ? "is-alert" : ""}`} title="Missed calls"><PhoneMissed size={15} /> <b className="mono">{missed}</b></span>
        </div>
      </aside>
    </div>
  );
}
