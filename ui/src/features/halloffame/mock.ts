import { PAGE_EVENTS, type HallOfFameBoard, type HallOfFameDialogPayload, type HallOfFameRow, type HallOfFameTab, type HallOfFameUnit, type UiAction } from "@/bridge/protocol";

/* Browser fixture of the Hall of Fame (Vite dev only), shaped as
   server/modules/halloffame.lua sends it. ?dialog=halloffame opens it; &tab=pvp picks
   the first tab; &hof=session shows the no-database banner; &hof=empty shows the
   empty states; &hof=top puts the viewer in the top ten (else ranked 14th, and 80th
   on MOST WINS, a 120-row board); &hofdelay=ms slows the answers (the loading states).
   A card clicked answers `halloffame.board` with that board's ladder (top 50). */
export function hallOfFameMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const mode = params.get("hof");
  const delay = Math.max(0, Number(params.get("hofdelay")) || 160);
  const you = "Yuki Tanaka";
  const first = ["Kei", "Vi", "Jax", "Nadia", "Tess", "Ilya", "Marco", "Lena", "Dex", "Sasha", "Theo", "Mira", "Ana", "Bo", "Kai", "Rook"];
  const last = ["Mori", "Okafor", "Romero", "Sol", "Varga", "Brandt", "Reyes", "Hale", "Kim", "Vance", "Ruiz", "Chen", "Ito", "Delacroix-Ferreira"];
  const nameOf = (i: number) => (i === 4 ? "Rook" : i === 17 ? "Alexandra Konstantinopoulou-Whitfield" : `${first[i % first.length]} ${last[(i * 7 + Math.floor(i / first.length)) % last.length]}`);
  const titles: Record<number, string> = { 0: "Champion", 3: "Top Gun", 9: "Night Owl", 22: "Street Legend" };
  let computedAt = Date.now() - 3 * 60_000;
  let askedAt = 0;

  // `count` characters, best first; ties at the indexes `ties` (each one shares the previous rank).
  const rows = (unit: HallOfFameUnit, start: number, step: number, count: number, detail?: (i: number) => string | undefined, ties: number[] = []): HallOfFameRow[] => {
    const out: HallOfFameRow[] = [];
    for (let i = 0; i < count; i++) {
      const tie = ties.includes(i) && i > 0;
      const value = tie ? out[i - 1]!.value : unit === "time" ? start + i * step : Math.max(1, start - i * step);
      out.push({ rank: tie ? out[i - 1]!.rank : i + 1, name: nameOf(i), value, detail: detail?.(i), title: titles[i] });
    }
    return out;
  };
  // A board's whole ranking with the viewer at `at` (1-based; `top` mode: 5th), as the cache holds it.
  const board = (key: string, tab: HallOfFameTab, title: string, subtitle: string, unit: HallOfFameUnit, list: HallOfFameRow[], ascending = false, at = 14) => {
    const place = mode === "top" ? 5 : at;
    const full = list.map((r, i) => (i === place - 1 ? { ...r, name: you, you: true, title: undefined } : r));
    const viewer = full[place - 1];
    return { tab, full: mode === "empty" ? [] : full, board: {
      key, title, subtitle, unit, ascending: ascending || undefined, total: mode === "empty" ? 0 : full.length, rows: [],
      mine: mode === "empty" || !viewer ? undefined : { rank: viewer.rank, value: viewer.value, detail: viewer.detail },
    } as HallOfFameBoard };
  };
  const view = (b: ReturnType<typeof board>, size: number): HallOfFameBoard => ({ ...b.board, rows: b.full.slice(0, size) });
  const tiers = (i: number) => (i < 4 ? "TIER 3" : i < 9 ? "TIER 2" : "TIER 1");
  const all = [
    board("pvp.wins", "pvp", "MOST WINS", "Arena, duels, races, chases and turf war", "wins",
      rows("wins", 412, 3, 120, (i) => `${600 - i * 4} played`, [2, 23, 24, 48, 49, 50]), false, 80),
    board("pvp.kills", "pvp", "MOST KILLS", "Players taken down in PvP activities", "kills", rows("kills", 212, 14, 12, (i) => `K/D ${(3.4 - i * 0.2).toFixed(2)}`)),
    board("races.race.trial", "races", "TIME TRIAL", "Best time · WATSON LOOP · REV 2", "time", rows("time", 61_234, 380, 64, undefined, [7]), true),
    board("races.race.grid", "races", "STREET RACE", "Best time · KABUKI SPRINT", "time", rows("time", 182_480, 2_210, 8), true),
    board("races.race.foot", "races", "ROOFTOP RACE", "Best time · All courses", "time", rows("time", 74_020, 990, 2), true),
    board("pve.wins", "pve", "PVE WINS", "Combat Zone PvE, races vs AI, NCPD Escape, turf PvE", "wins", rows("wins", 31, 2, 12, (i) => `${40 + i} played`)),
    board("pve.kills", "pve", "PVE TAKEDOWNS", "Gang bots and NCPD taken down", "kills", rows("kills", 640, 31, 12, (i) => `K/D ${(9.1 - i * 0.4).toFixed(2)}`)),
    board("pve.rep", "pve", "STREET CRED", "Reputation from missions and activities", "rep", rows("rep", 4_850, 310, 12, tiers)),
    board("missions.completed", "missions", "CONTRACTS COMPLETED", "Mission boards cleared, every difficulty", "count", rows("count", 64, 5, 12, (i) => `${4_850 - i * 310} rep`)),
    board("missions.heists", "missions", "HEISTS", "Ranked by the hardest clears", "clears", rows("clears", 21, 2, 9, (i) => `CRIT ${Math.max(0, 6 - i)} · HARD ${3 + (i % 3)} · STD ${8 - (i % 4)}`)),
    board("missions.raids", "missions", "CHIMERA RAID", "Ranked by the hardest clears", "clears", rows("clears", 9, 1, 5, (i) => `CRIT ${Math.max(0, 3 - i)} · HARD ${2 + (i % 2)}`)),
    board("wealth.richest", "wealth", "RICHEST", "Cash and bank, eddies", "eddies", rows("eddies", 1_284_500, 9_730, 40)),
  ];

  const header = (tab: HallOfFameTab): Omit<HallOfFameDialogPayload, "boards"> => {
    const wait = Math.max(0, 30 - Math.floor((Date.now() - askedAt) / 1000));
    return {
      kind: "halloffame", title: "HALL OF FAME", hub: "The Crossing", tab, tabs: ["overview", "pvp", "races", "pve", "missions", "wealth"],
      database: mode !== "session", updatedAgoS: Math.floor((Date.now() - computedAt) / 1000), refreshInS: askedAt ? wait : 0,
    };
  };
  const payload = (tab: HallOfFameTab): HallOfFameDialogPayload => {
    const boards = tab === "overview" ? all.map((b) => view(b, 3)) : all.filter((b) => b.tab === tab).map((b) => view(b, 10));
    return { ...header(tab), boards };
  };
  const ladder = (key: string, tab: HallOfFameTab): HallOfFameDialogPayload | undefined => {
    const b = all.find((x) => x.board.key === key);
    return b && { ...header(tab), boards: [], ladder: view(b, 50) };
  };
  const tabOf = (value: unknown): HallOfFameTab => {
    const tabs: HallOfFameTab[] = ["overview", "pvp", "races", "pve", "missions", "wealth"];
    return tabs.includes(value as HallOfFameTab) ? (value as HallOfFameTab) : "overview";
  };
  const send = (tab: HallOfFameTab, key?: string) => {
    const answer = key ? ladder(key, tab) : payload(tab);
    if (answer) fire(PAGE_EVENTS.dialog, answer);
    else fire(PAGE_EVENTS.result, { ok: false, text: "That board is not on the Hall of Fame.", action: "halloffame.board" });
  };

  return {
    boot() { if (params.get("dialog") === "halloffame") send(tabOf(params.get("tab"))); },
    /** true when the action was the Hall of Fame's */
    handle(action: UiAction): boolean {
      if (action.type === "halloffame.close") return true;
      if (action.type === "halloffame.board") { window.setTimeout(() => send(tabOf(action.tab), action.key), delay); return true; }
      if (action.type !== "halloffame.open" && action.type !== "halloffame.tab" && action.type !== "halloffame.refresh") return false;
      if (action.type === "halloffame.refresh" && Date.now() - askedAt >= 30_000) { askedAt = Date.now(); computedAt = Date.now(); }
      const key = action.type === "halloffame.refresh" ? action.key : undefined;
      window.setTimeout(() => send(tabOf(action.tab), key), delay);
      return true;
    },
  };
}
