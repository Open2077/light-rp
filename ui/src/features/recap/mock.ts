import { PAGE_EVENTS, type RecapDialogPayload, type RecapRow, type UiAction } from "@/bridge/protocol";

/* Browser fixture of the end-of-match recap (Vite dev only), shaped as
   server/modules/recap.lua sends it (zeros left out of the rows, bots negative).
   ?dialog=recap opens it; &recap= picks the match: ffa (default), team, race, chase,
   turf, mission, boss, test, unranked, draw, big (40 on the board, 32 shown). F1 >
   Last match (recap.open) sends it again as `reopened`. */
const NAMES = ["Kei Mori", "Vi Okafor", "Jax Romero", "Nadia Sol", "Rook", "Tess Varga", "Ilya Brandt", "Marco Reyes", "Lena Mori", "Dex Hale",
  "Sasha Kim", "Theo Vance", "Mira Sol", "Ana Ruiz", "Bo Chen", "Kai Ito"];
const YOU = 7;

const drop = (row: RecapRow): RecapRow => {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(row)) if (v !== 0 && v !== undefined && v !== false) out[k] = v;
  return out as RecapRow;
};
const dps = (damage: number, ms: number) => Math.round((damage / Math.max(1, ms / 1000)) * 10) / 10;

function fighters(count: number, bots: number, ms: number, sides = 0): RecapRow[] {
  const rows: RecapRow[] = [];
  for (let i = 0; i < count + bots; i++) {
    const bot = i >= count;
    const id = bot ? -(i - count + 1) : i === 1 ? YOU : 20 + i;
    const kills = Math.max(0, 14 - i * 2 - (bot ? 3 : 0)), deaths = 2 + (i % 4), damage = Math.max(0, 2900 - i * 310 - (bot ? 600 : 0));
    rows.push(drop({ id, name: bot ? `[BOT] ${["Viper", "Ghost", "Razor", "Nomad"][(i - count) % 4]}` : i === 1 ? "Yuki Tanaka" : NAMES[i % NAMES.length]!, bot: bot || undefined,
      side: sides ? (i % sides) + 1 : undefined, kills, deaths, assists: (i * 3) % 5, damage, damageTaken: 1400 + (i % 3) * 420, dps: dps(damage, ms),
      headshots: Math.max(0, 5 - i), score: kills * 100 + ((i * 3) % 5) * 25, placement: sides ? undefined : i + 1 }));
  }
  return rows;
}

function scenario(kind: string): RecapDialogPayload {
  const base = { kind: "recap" as const, source: "activity" as const, you: YOU, sides: [], lines: [], rewards: {} };
  switch (kind) {
    case "team": {
      const rows = fighters(6, 2, 840_000, 2);
      return { ...base, id: "arena.team|arena:3:m2@1", mode: "Team Arena", modeKind: "pvp", detail: "Best of 3", durationMs: 840_000,
        result: { label: "WIN", tone: "win" }, columns: ["kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score"],
        sides: [{ id: 1, label: "Team A", score: 1 }, { id: 2, label: "Team B", score: 2 }], winnerSide: 2, rows, total: rows.length,
        lines: [{ label: "Rounds", value: "1 - 2" }, { label: "Round 1", value: "Team B" }, { label: "Round 2", value: "Team A" }, { label: "Round 3", value: "Team B" }],
        mvp: { id: 20, by: "score" }, rewards: { eddies: 1250, eddiesReason: "pvp", eddiesNote: "won · 14 min", reputation: 60 } };
    }
    case "race": {
      const rows: RecapRow[] = [
        { id: 21, name: "Kei Mori", placement: 1, timeMs: 185_412, bestLapMs: 61_034, checkpoints: 24 },
        { id: YOU, name: "Yuki Tanaka", placement: 2, timeMs: 187_950, bestLapMs: 61_880, checkpoints: 24 },
        { id: -1, name: "[AI] Razor", bot: true, placement: 3, timeMs: 191_200, bestLapMs: 62_410, checkpoints: 24 },
        { id: 24, name: "Nadia Sol", outcome: "dnf", checkpoints: 17 },
        { id: -2, name: "[AI] Nomad", bot: true, outcome: "dnf", checkpoints: 9 },
      ];
      return { ...base, id: "race.grid|race:5@1", mode: "Street Race", modeKind: "race", durationMs: 196_000,
        result: { label: "#2", tone: "neutral", placement: 2, of: 3 }, columns: ["placement", "timeMs", "bestLapMs", "checkpoints"], rows, total: rows.length,
        lines: [{ label: "Course", value: "Kabuki Sprint" }, { label: "Laps", value: "3" }, { label: "Mode", value: "Grid" }, { label: "Winner", value: "Kei Mori" }],
        mvp: { id: 21, by: "placement" }, rewards: { eddies: 640, eddiesReason: "pvp", eddiesNote: "#2 of 3 · 3 min", reputation: 25,
          hof: [{ board: "Street Race", before: 9, rank: 4 }] } };
    }
    case "chase": {
      const rows: RecapRow[] = [
        { id: YOU, name: "Yuki Tanaka", placement: 1, roundsWon: 2, busts: 1, escapes: 1, timeMs: 412_000 },
        { id: 22, name: "Vi Okafor", placement: 2, roundsWon: 1, escapes: 1, timeMs: 398_000 },
      ];
      return { ...base, id: "chase.1v1|chase:4@1", mode: "Chase 1v1", modeKind: "chase", detail: "Chase 1v1", durationMs: 610_000,
        result: { label: "WIN", tone: "win", placement: 1, of: 2 }, columns: ["placement", "roundsWon", "busts", "escapes", "timeMs"], rows, total: 2,
        lines: [{ label: "Round 1", value: "escaped · Yuki Tanaka" }, { label: "Round 2", value: "escaped · Vi Okafor" }, { label: "Round 3", value: "busted · Yuki Tanaka" }],
        mvp: { id: YOU, by: "placement" }, rewards: { eddies: 900, eddiesReason: "pvp", eddiesNote: "won · 10 min", reputation: 40 } };
    }
    case "turf": {
      const rows = fighters(5, 3, 900_000, 2).map((r, i) => drop({ id: r.id, name: r.name, bot: r.bot, side: r.side, kills: r.kills, deaths: r.deaths,
        captures: (i * 2) % 5, holdS: 300 - i * 25, score: (r.kills ?? 0) * 10 + ((i * 2) % 5) * 50 }));
      return { ...base, id: "turf.war|turf:pvp:3@1", mode: "Turf War", modeKind: "pvp", detail: "Turf War", durationMs: 900_000,
        result: { label: "LOSS", tone: "loss" }, columns: ["kills", "deaths", "captures", "holdS", "score"],
        sides: [{ id: 1, label: "Valentinos", score: 500 }, { id: 2, label: "Maelstrom", score: 412 }], winnerSide: 1, rows, total: rows.length,
        lines: [{ label: "Site", value: "Heywood Docks" }, { label: "District", value: "Heywood" }],
        rewards: { reputation: 15, eddiesReason: "bots" } };
    }
    case "mission": {
      const rows: RecapRow[] = [
        { id: YOU, name: "Yuki Tanaka", kills: 9, deaths: 1, damage: 4120, damageTaken: 860, dps: 9.8, headshots: 4, share: 41.5 },
        { id: 22, name: "Vi Okafor", kills: 7, deaths: 2, damage: 3310, damageTaken: 1540, dps: 7.9, headshots: 2, share: 33.2 },
        { id: 23, name: "Jax Romero", kills: 4, damage: 2540, damageTaken: 410, dps: 6, share: 25.3 },
      ];
      return { ...base, id: "mission|m-12", source: "mission", mode: "Docks Heist", modeKind: "mission", detail: "Hard", durationMs: 420_000,
        result: { label: "COMPLETE", tone: "win" }, columns: ["kills", "deaths", "damage", "damageTaken", "dps", "headshots", "share"], rows, total: 3,
        lines: [{ label: "Waves", value: "3 / 3" }, { label: "Checkpoints", value: "2 / 2" }, { label: "Hostiles down", value: "20" }, { label: "Team respawns left", value: "1 / 3" }],
        mvp: { id: YOU, by: "share" },
        rewards: { eddies: 2400, eddiesNote: " (crew of 3, shared pot)", reputation: 180,
          tier: { tier: 3, name: "Solo", points: 2_140, next: 3_000, nextName: "Legend", up: true } } };
    }
    case "boss": {
      const rows: RecapRow[] = [
        { id: 22, name: "Vi Okafor", kills: 12, damage: 18_400, dps: 30.7, bossShare: 38.2, share: 35 },
        { id: YOU, name: "Yuki Tanaka", kills: 8, damage: 14_900, dps: 24.8, bossShare: 30.9, share: 28.4 },
        { id: 23, name: "Jax Romero", kills: 5, deaths: 1, damage: 9_200, dps: 15.3, bossShare: 19.6, share: 22.1 },
        { id: 24, name: "Nadia Sol", kills: 2, deaths: 2, damage: 4_100, dps: 6.8, bossShare: 11.3, share: 14.5 },
      ];
      return { ...base, id: "worldboss|wb-2", source: "worldboss", mode: "Smasher's Convoy", modeKind: "worldboss", durationMs: 600_000,
        result: { label: "BOSS DOWN", tone: "win" }, columns: ["kills", "deaths", "damage", "dps", "bossShare", "share"], rows, total: 4,
        lines: [{ label: "Location", value: "Arasaka Waterfront" }, { label: "Fighters", value: "4" }, { label: "Minimum share", value: "5%" }],
        mvp: { id: 22, by: "share" }, rewards: { eddies: 3550, reputation: 120 } };
    }
    case "big": {
      const rows = fighters(16, 24, 600_000).slice(0, 32);
      return { ...base, id: "arena.ffa|big@1", mode: "Arena Night", modeKind: "pvp", detail: "Round 4", durationMs: 600_000,
        result: { label: "#2", tone: "neutral", placement: 2, of: 40 }, columns: ["placement", "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score"],
        rows, total: 40, lines: [{ label: "Round", value: "4" }, { label: "Event", value: "Arena Night" }], mvp: { id: 20, by: "score" },
        rewards: { eddies: 0, eddiesReason: "bots" } };
    }
    case "draw": {
      const rows: RecapRow[] = [{ id: YOU, name: "Yuki Tanaka", placement: 1, roundsWon: 1, escapes: 1, timeMs: 300_000 }, { id: 22, name: "Vi Okafor", placement: 1, roundsWon: 1, busts: 1, timeMs: 290_000 }];
      return { ...base, id: "chase.1v1|chase:9@1", mode: "Chase 1v1", modeKind: "chase", durationMs: 600_000, result: { label: "DRAW", tone: "neutral", placement: 1, of: 2 },
        columns: ["placement", "roundsWon", "busts", "escapes", "timeMs"], rows, total: 2, lines: [{ label: "Result", value: "Draw" }],
        rewards: { eddies: 420, eddiesReason: "pvp", eddiesNote: "played · 10 min", reputation: 10 } };
    }
    default: {
      const rows = fighters(4, 2, 600_000);
      const test = kind === "test", unranked = kind === "unranked";
      return { ...base, id: `arena.ffa|arena:7:3@${kind}`, mode: "Arena FFA", modeKind: "pvp", detail: "Round 3", durationMs: 600_000,
        result: { label: "#2", tone: "neutral", placement: 2, of: 6 }, test: test || undefined, unranked: unranked || undefined,
        columns: ["placement", "kills", "deaths", "assists", "damage", "damageTaken", "dps", "headshots", "score"], rows, total: rows.length,
        lines: [{ label: "Round", value: "3" }, { label: "Winner", value: "Kei Mori" }], mvp: { id: 20, by: "score" },
        rewards: test ? { test: true } : unranked ? { eddiesReason: "unranked", reputation: 0 }
          : { eddies: 875, eddiesReason: "pvp", eddiesNote: "#2 of 6 · 10 min", reputation: 40, hof: [{ board: "Most kills", before: 18, rank: 12 }] } };
    }
  }
}

export function recapMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const payload = scenario(params.get("recap") ?? "ffa");
  return {
    boot() {
      fire(PAGE_EVENTS.state, { recap: { last: { id: payload.id, mode: payload.mode, result: payload.result.label, test: payload.test } } });
      if (params.get("dialog") === "recap") fire(PAGE_EVENTS.dialog, payload);
    },
    /** true when the action was the recap's */
    handle(action: UiAction): boolean {
      if (action.type === "recap.close") return true;
      if (action.type !== "recap.open") return false;
      window.setTimeout(() => fire(PAGE_EVENTS.dialog, { ...payload, reopened: true }), 160);
      return true;
    },
  };
}
