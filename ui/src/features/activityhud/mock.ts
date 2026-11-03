import { PAGE_EVENTS } from "@/bridge/protocol";
import type { ActivityHudMessage, ActivityHudState, ActivityRow } from "./model";

/* Browser fixture of the activity HUD (Vite dev only). ?activity=race | trial | arena |
   turf | lobby | countdown | result | editor | demo. `demo` walks a whole race: lobby,
   countdown, the run with its pushes, the result, then the clear. Add &run=courier to
   see a lobby fold beside a work order, &queue=1 to see the strip under the mission queue. */
export function activityHudMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const kind = params.get("activity");
  const send = (m: ActivityHudMessage) => fire(PAGE_EVENTS.activityHud, m);
  const show = (hud: ActivityHudState) => send({ op: "show", hud });
  const later = (ms: number, fn: () => void) => { window.setTimeout(fn, ms); };

  const racers = ["Kei Mori", "Vi Okafor", "You", "Jax Romero", "Nadia Sol", "Rook", "Tess Varga", "Ilya Brandt"];
  const raceRows = (selfAt = 3): ActivityRow[] => racers.map((name, i) => ({
    name: i === selfAt - 1 ? "Lena Mori" : name,
    values: [String(12 - i), i === 0 ? "-" : `+${(i * 1.37).toFixed(2)}`],
    self: i === selfAt - 1 || undefined,
  }));
  const race = (elapsedMs: number, checkpoint: number): ActivityHudState => ({
    activity: "race.grid", title: "Street Race", subtitle: "Watson Loop · Quadra Turbo-R", phase: "running",
    timer: { remainingMs: elapsedMs, label: "TIME", countUp: true },
    stats: [{ label: "Position", value: "3/8" }, { label: "Checkpoint", value: `${checkpoint}/12` }, { label: "Lap", value: "2/3" }, { label: "Best lap", value: "0:58.21" }],
    progress: [{ id: "course", label: "Course", value: checkpoint / 12 }],
    scoreboard: { columns: ["CP", "GAP"], rows: raceRows() },
    hints: [{ key: "HOME", label: "Restart" }, { key: "END", label: "Last checkpoint" }, { key: "/race.leave", label: "Quit" }],
  });
  const lobby = (): ActivityHudState => ({
    activity: "race.grid", title: "Street Race", subtitle: "Watson Loop", phase: "lobby",
    timer: { remainingMs: 45000, label: "STARTS IN" }, objective: "3 racers queued · 2 more to start",
    hints: [{ key: "/race.leave", label: "Leave queue" }],
  });
  const result = () => send({ op: "push", kind: "result", item: {
    placement: 2, title: "Street Race", subtitle: "Watson Loop · 8 racers", durationMs: 9000,
    lines: [{ label: "Time", value: "3:02.48" }, { label: "Best lap", value: "0:58.21" }, { label: "Gap", value: "+1.37" }, { label: "Personal best", value: "New" }],
  } });

  const scenarios: Record<string, () => void> = {
    race: () => {
      show(race(62345, 7));
      later(1200, () => send({ op: "push", kind: "banner", item: { title: "LAP 2/3", durationMs: 2600 } }));
      ["Checkpoint 5 · +0.42", "Checkpoint 6 · -0.18", "Checkpoint 7 · +0.07"].forEach((text, i) =>
        later(600 + i * 1700, () => send({ op: "push", kind: "feed", item: { text, tone: text.includes("-") ? "success" : undefined } })));
    },
    trial: () => show({
      activity: "race.trial", title: "Time Trial", subtitle: "Kabuki Sprint · Arch Nazaré", phase: "running",
      timer: { remainingMs: 41200, label: "TIME", countUp: true },
      stats: [{ label: "Checkpoint", value: "4/9" }, { label: "Personal best", value: "1:12.40" }, { label: "Record", value: "1:08.95" }],
      progress: [{ id: "course", label: "Course", value: 4 / 9 }],
      hints: [{ key: "HOME", label: "Restart" }, { key: "END", label: "Last checkpoint" }, { key: "/race.leave", label: "Quit" }],
    }),
    arena: () => {
      const names = ["Kei Mori", "Lena Mori", "Vi Okafor", "Jax Romero", "Nadia Sol", "Rook", "Tess Varga", "Ilya Brandt", "Saul K", "Mira"];
      show({
        activity: "arena.tdm", title: "Team Deathmatch", subtitle: "Pacifica Mall", phase: "running",
        timer: { remainingMs: 252000, label: "TIME LEFT" },
        teams: [{ name: "Tyger Claws", color: "#ff2e3c", score: "18" }, { name: "Valentinos", color: "info", score: "21", self: true }],
        stats: [{ label: "Kills", value: "6" }, { label: "Deaths", value: "2" }, { label: "Streak", value: "3" }, { label: "Score", value: "640" }],
        scoreboard: { columns: ["K", "D", "PTS"], rows: names.map((name, i) => ({ name, values: [String(9 - i), String(2 + (i % 3)), String(900 - i * 70)], team: i % 2 === 0 ? 1 : 2, self: name === "Lena Mori" || undefined })) },
        hints: [{ key: "TAB", label: "Scores" }, { key: "/arena.leave", label: "Quit" }],
      });
      ["Kei Mori ▸ Rook", "You ▸ Saul K", "Tess Varga ▸ You"].forEach((text, i) =>
        later(500 + i * 1500, () => send({ op: "push", kind: "feed", item: { text, tone: text.startsWith("You") ? "accent" : text.endsWith("You") ? "danger" : undefined } })));
    },
    turf: () => show({
      activity: "turf.war", title: "Turf War", subtitle: "Kabuki", phase: "running",
      timer: { remainingMs: 9000, label: "CAPTURE" }, objective: "Hold Kabuki Market",
      teams: [{ name: "Maelstrom", color: "#ff2e3c", score: "2" }, { name: "6th Street", color: "info", score: "1" }, { name: "Valentinos", color: "success", score: "3", self: true }, { name: "Mox", color: "#ff3fb4", score: "0" }],
      progress: [{ id: "zone", label: "Market control", value: 0.72, tone: "success" }, { id: "contest", label: "Contested by Maelstrom", value: 0.31, tone: "danger" }],
      stats: [{ label: "Zones held", value: "3" }, { label: "Crew alive", value: "4/5" }],
      hints: [{ key: "/turf.leave", label: "Quit" }],
    }),
    lobby: () => show(lobby()),
    countdown: () => show({ activity: "race.grid", title: "Street Race", subtitle: "Watson Loop", phase: "countdown", countdown: 8000,
      stats: [{ label: "Grid", value: "3/8" }], hints: [{ key: "/race.leave", label: "Quit" }] }),
    result: () => {
      show({ ...race(182480, 12), phase: "ended", timer: { remainingMs: 15000, label: "BACK IN" } });
      result();
    },
    editor: () => show({
      activity: "race.editor", title: "Course editor", subtitle: "watson-loop", phase: "lobby",
      objective: "Checkpoint 4 placed",
      stats: [{ label: "Checkpoints", value: "4" }, { label: "Grid", value: "8" }, { label: "Start", value: "Set" }, { label: "Laps", value: "3" }],
      hints: [{ key: "E", label: "Checkpoint" }, { key: "G", label: "Grid slot" }, { key: "BACKSPACE", label: "Undo" }, { key: "/race.save", label: "Save" }],
    }),
    demo: () => {
      show(lobby());
      later(3000, () => show({ activity: "race.grid", title: "Street Race", subtitle: "Watson Loop · Quadra Turbo-R", phase: "countdown", objective: "Loading the grid" }));
      later(4000, () => show({ activity: "race.grid", title: "Street Race", subtitle: "Watson Loop · Quadra Turbo-R", phase: "countdown", countdown: 4000, hints: [{ key: "/race.leave", label: "Quit" }] }));
      later(8000, () => { show(race(0, 0)); send({ op: "push", kind: "banner", item: { title: "GO", tone: "success", durationMs: 1200 } }); });
      for (let cp = 1; cp <= 12; cp++) later(8000 + cp * 1100, () => {
        show(race(cp * 1100, cp));
        send({ op: "push", kind: "feed", item: { text: `Checkpoint ${cp} · ${cp % 3 ? "+" : "-"}0.${cp}4`, tone: cp % 3 ? undefined : "success" } });
        if (cp === 8) send({ op: "push", kind: "banner", item: { title: "FINAL LAP", durationMs: 2400 } });
      });
      later(22000, () => { send({ op: "push", kind: "banner", item: { title: "FINISH", tone: "success", durationMs: 2000 } });
        show({ ...race(13200, 12), phase: "ended" }); });
      later(23500, () => { show({ ...race(13200, 12), phase: "ended", timer: { remainingMs: 8000, label: "BACK IN" } }); result(); });
      later(31500, () => send({ op: "clear", reason: "cleared" }));
    },
  };

  return {
    boot() {
      if (!kind) return;
      (scenarios[kind] ?? scenarios.race!)();
    },
  };
}
