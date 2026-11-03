import { PAGE_EVENTS, type HallOfFameBoard, type HallOfFameDialogPayload, type HallOfFameRow, type HallOfFameTab, type HallOfFameUnit, type UiAction } from "@/bridge/protocol";

/* Browser fixture of the Hall of Fame (Vite dev only), shaped as
   server/modules/halloffame.lua sends it. ?dialog=halloffame opens it; &tab=pvp picks
   the first tab; &hof=session shows the no-database banner; &hof=empty shows the
   empty states; &hof=top puts the viewer in the top ten (else ranked 14th). */
export function hallOfFameMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const mode = params.get("hof");
  const you = "Yuki Tanaka";
  const names = ["Kei Mori", "Vi Okafor", "Jax Romero", "Nadia Sol", "Rook", "Tess Varga", "Ilya Brandt", "Marco Reyes", "Lena Mori",
    "Dex Hale", "Sasha Kim", "Theo Vance", "Mira Sol", "Ana Ruiz", "Bo Chen", "Kai Ito"];
  let computedAt = Date.now() - 3 * 60_000;
  let askedAt = 0;

  // `count` characters, best first; ties where `tieAt` says.
  const rows = (unit: HallOfFameUnit, start: number, step: number, count: number, detail?: (i: number) => string | undefined, tieAt?: number): HallOfFameRow[] => {
    const out: HallOfFameRow[] = [];
    for (let i = 0; i < count; i++) {
      const value = unit === "time" ? start + i * step : Math.max(1, start - i * step);
      const tie = tieAt != null && i === tieAt + 1;
      out.push({ rank: tie ? out[i - 1]!.rank : i + 1, name: names[i % names.length]!, value: tie ? out[i - 1]!.value : value, detail: detail?.(i) });
    }
    return out;
  };
  const board = (key: string, tab: HallOfFameTab, title: string, subtitle: string, unit: HallOfFameUnit, list: HallOfFameRow[], ascending = false) => {
    const viewerTop = mode === "top";
    const all = viewerTop && list.length > 4 ? list.map((r, i) => (i === 4 ? { ...r, name: you, you: true } : r)) : list;
    return { tab, board: {
      key, title, subtitle, unit, ascending: ascending || undefined, total: mode === "empty" ? 0 : all.length + 4,
      rows: mode === "empty" ? [] : all.slice(0, 10),
      mine: mode === "empty" ? undefined : viewerTop ? { rank: 5, value: all[4]?.value ?? 0, detail: all[4]?.detail } : { rank: 14, value: unit === "time" ? 99_120 : 3, detail: undefined },
    } as HallOfFameBoard };
  };
  const tiers = (i: number) => (i < 4 ? "TIER 3" : i < 9 ? "TIER 2" : "TIER 1");
  const all = [
    board("pvp.wins", "pvp", "MOST WINS", "Arena, duels, races, chases and turf war", "wins", rows("wins", 48, 3, 12, (i) => `${60 + i * 4} played`, 2)),
    board("pvp.kills", "pvp", "MOST KILLS", "Players taken down in PvP activities", "kills", rows("kills", 212, 14, 12, (i) => `K/D ${(3.4 - i * 0.2).toFixed(2)}`)),
    board("races.race.trial", "races", "TIME TRIAL", "Best time · WATSON LOOP · REV 2", "time", rows("time", 61_234, 1_380, 11), true),
    board("races.race.grid", "races", "STREET RACE", "Best time · KABUKI SPRINT", "time", rows("time", 182_480, 2_210, 8), true),
    board("races.race.foot", "races", "ROOFTOP RACE", "Best time · All courses", "time", rows("time", 74_020, 990, 2), true),
    board("pve.wins", "pve", "PVE WINS", "Combat Zone PvE, races vs AI, NCPD Escape, turf PvE", "wins", rows("wins", 31, 2, 12, (i) => `${40 + i} played`)),
    board("pve.kills", "pve", "PVE TAKEDOWNS", "Gang bots and NCPD taken down", "kills", rows("kills", 640, 31, 12, (i) => `K/D ${(9.1 - i * 0.4).toFixed(2)}`)),
    board("pve.rep", "pve", "STREET CRED", "Reputation from missions and activities", "rep", rows("rep", 4_850, 310, 12, tiers)),
    board("missions.completed", "missions", "CONTRACTS COMPLETED", "Mission boards cleared, every difficulty", "count", rows("count", 64, 5, 12, (i) => `${4_850 - i * 310} rep`)),
    board("missions.heists", "missions", "HEISTS", "Ranked by the hardest clears", "clears", rows("clears", 21, 2, 9, (i) => `CRIT ${Math.max(0, 6 - i)} · HARD ${3 + (i % 3)} · STD ${8 - (i % 4)}`)),
    board("missions.raids", "missions", "CHIMERA RAID", "Ranked by the hardest clears", "clears", rows("clears", 9, 1, 5, (i) => `CRIT ${Math.max(0, 3 - i)} · HARD ${2 + (i % 2)}`)),
    board("wealth.richest", "wealth", "RICHEST", "Cash and bank, eddies", "eddies", rows("eddies", 1_284_500, 97_300, 12)),
  ];

  const payload = (tab: HallOfFameTab): HallOfFameDialogPayload => {
    const boards = tab === "overview"
      ? all.map((b) => ({ ...b.board, rows: b.board.rows.slice(0, 3) }))
      : all.filter((b) => b.tab === tab).map((b) => b.board);
    const wait = Math.max(0, 30 - Math.floor((Date.now() - askedAt) / 1000));
    return {
      kind: "halloffame", title: "HALL OF FAME", hub: "The Crossing", tab, tabs: ["overview", "pvp", "races", "pve", "missions", "wealth"],
      boards, database: mode !== "session", updatedAgoS: Math.floor((Date.now() - computedAt) / 1000), refreshInS: askedAt ? wait : 0,
    };
  };
  const tabOf = (value: unknown): HallOfFameTab => {
    const tabs: HallOfFameTab[] = ["overview", "pvp", "races", "pve", "missions", "wealth"];
    return tabs.includes(value as HallOfFameTab) ? (value as HallOfFameTab) : "overview";
  };
  const send = (tab: HallOfFameTab) => fire(PAGE_EVENTS.dialog, payload(tab));

  return {
    boot() { if (params.get("dialog") === "halloffame") send(tabOf(params.get("tab"))); },
    /** true when the action was the Hall of Fame's */
    handle(action: UiAction): boolean {
      if (action.type === "halloffame.close") return true;
      if (action.type !== "halloffame.open" && action.type !== "halloffame.tab" && action.type !== "halloffame.refresh") return false;
      if (action.type === "halloffame.refresh" && Date.now() - askedAt >= 30_000) { askedAt = Date.now(); computedAt = Date.now(); }
      window.setTimeout(() => send(tabOf(action.tab)), 160);
      return true;
    },
  };
}
