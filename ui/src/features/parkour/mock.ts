import { PAGE_EVENTS } from "@/bridge/protocol";
import type { BoardRow, Course, CourseCard } from "./model";

/* Dev mock (no Open77 bridge):
   ?parkour=hud      a run in progress (clock, 3 of 6 checkpoints, deltas, splits)
   ?parkour=count    the 3-2-1-GO
   ?parkour=go       GO just after the start (with the bearing)
   ?parkour=result   the result card (new personal best, rank 2 / 37)
   ?parkour=record   the result card with a course record
   ?parkour=dnf      the DNF card
   ?parkour=browser  F1 > Parkour with 4 courses and a 37-runner board
   ?parkour=editor   the staff editor on the course list (and build=1: the build bar) */
type Fire = (name: string, payload: unknown) => void;

const COURSE = {
  id: "pk1", name: "Kabuki Rooftops", difficulty: "hard" as const, revision: 3, length: 412.6, timeLimit: 0,
  start: { x: -1430, y: 140, z: 30, radius: 2.5, heading: 90 },
  checkpoints: Array.from({ length: 6 }, (_, i) => ({ x: -1420 + i * 50, y: 150, z: 32 + i, radius: 3 })),
  finish: { x: -1100, y: 160, z: 40, radius: 3 },
};
const NAMES = ["Vi Asada", "Kei Mori", "Rosa Vasquez", "Jack Okoro", "Nix", "Ledger", "Panam R.", "Yuki", "w0dm4n", "Delamain", "Mama Okoro", "Ozob"];
const board = (_page: number): BoardRow[] => Array.from({ length: 37 }, (_, i) => i).map((i) => ({
  rank: i + 1, name: NAMES[i % NAMES.length]! + (i >= NAMES.length ? ` ${Math.floor(i / NAMES.length) + 1}` : ""), timeMs: 61234 + i * 1870 + (i * i * 13),
  splits: COURSE.checkpoints.map((_, k) => 8000 + k * 8700 + i * 260 + k * i * 9).join(","), runs: 1 + (i % 7), at: Date.now() - i * 86400e3 / 3, me: i === 1 || undefined,
}));
const CARDS: CourseCard[] = [
  { id: "pk1", name: "Kabuki Rooftops", description: "From the market roofs to the Kabuki gate: two gaps, a crane and the long billboard run.", difficulty: "hard",
    checkpoints: 6, length: 412.6, timeLimit: 0, fallLine: true, author: "Yuki", finishes: 412, attempts: 1290, runners: 37,
    record: { timeMs: 61234, name: "Vi Asada" }, best: { timeMs: 63104, rank: 2, runs: 14 }, distance: 3, start: COURSE.start },
  { id: "pk2", name: "Japantown Sprint", description: "Street level, then the stairs up to the Jig-Jig roofs.", difficulty: "easy",
    checkpoints: 3, length: 220, timeLimit: 2, author: "w0dm4n", finishes: 88, attempts: 140, runners: 21, record: { timeMs: 31877, name: "Kei Mori" }, distance: 954, start: COURSE.start },
  { id: "pk3", name: "Corpo Plaza Vertical", description: "Arasaka's balconies, all the way up. Do not look down.", difficulty: "extreme",
    checkpoints: 14, length: 1240, timeLimit: 10, fallLine: true, author: "Yuki", finishes: 9, attempts: 230, runners: 6, record: { timeMs: 248901, name: "Rosa Vasquez" }, distance: 2830, start: COURSE.start },
  { id: "pk4", name: "Northside Docks", description: "", difficulty: "medium", checkpoints: 0, length: 96, timeLimit: 0, finishes: 0, attempts: 3, runners: 0, distance: 4120, start: COURSE.start },
];
const EDITOR_COURSES: Course[] = [
  { ...COURSE, status: "published", description: "From the market roofs to the Kabuki gate.", timeLimit: 0, floorZ: 22, authorName: "Yuki", attempts: 1290, finishes: 412, runners: 37, record: { timeMs: 61234, name: "Vi Asada" } },
  { ...COURSE, id: "pk5", name: "Draft: Watson Docks", status: "draft", description: "", difficulty: "medium", revision: 1, checkpoints: COURSE.checkpoints.slice(0, 2), timeLimit: 0 },
];

export function parkourMock(fire: Fire, params: URLSearchParams) {
  const mode = params.get("parkour");
  const run = () => fire(PAGE_EVENTS.parkour, { kind: "run", phase: "loading", course: COURSE, attempt: 3,
    best: { timeMs: 63104, splits: COURSE.checkpoints.map((_, k) => 8300 + k * 8800).join(",") },
    record: { timeMs: 61234, name: "Vi Asada", splits: COURSE.checkpoints.map((_, k) => 8000 + k * 8700).join(",") } });
  return {
    boot() {
      if (!mode) return;
      if (mode === "browser") { fire(PAGE_EVENTS.dialog, { kind: "parkour", courses: CARDS, selected: "pk1", here: "pk1", staff: true }); return; }
      if (mode === "editor") { fire(PAGE_EVENTS.parkourEditor, { kind: "open" }); if (params.get("build") === "1") setTimeout(() => fire(PAGE_EVENTS.parkourEditor, { kind: "editor", mode: "world" }), 1400); return; }
      run();
      if (mode === "count") { fire(PAGE_EVENTS.parkour, { kind: "countdown", goInMs: 3000, attempt: 3 }); return; }
      fire(PAGE_EVENTS.parkour, { kind: "countdown", goInMs: 0, attempt: 3 });
      fire(PAGE_EVENTS.parkour, { kind: "go", attempt: 3 });
      const cps = mode === "hud" ? 3 : mode === "go" ? 0 : 6;
      for (let i = 1; i <= cps; i += 1) fire(PAGE_EVENTS.parkour, { kind: "cp", index: i, total: 6, elapsedMs: 8100 + (i - 1) * 8790 + (i === 3 ? 400 : 0), bestMs: 8300 + (i - 1) * 8800, attempt: 3 });
      // the bearing to checkpoint 4: ahead on the right, up on a roof (?parkour=go: GO still up)
      setTimeout(() => fire(PAGE_EVENTS.parkour, { kind: "bearing", label: "CP 4", angle: -38, distance: 42, rise: 6 }), 50);
      if (mode === "hud" || mode === "go") return;
      if (mode === "dnf") { fire(PAGE_EVENTS.parkour, { kind: "dnf", reason: "time", text: "Time limit reached.", attempt: 3, checkpoint: 4, checkpoints: 6 }); return; }
      const time = mode === "record" ? 60877 : 62480;
      fire(PAGE_EVENTS.parkour, { kind: "finish", timeMs: time, splits: "", attempt: 3 });
      setTimeout(() => fire(PAGE_EVENTS.parkour, { kind: "result", timeMs: time, attempt: 3, checkpoints: 6, course: "pk1", name: COURSE.name,
        splits: COURSE.checkpoints.map((_, k) => 8100 + k * 8790).join(","), improved: true, rank: mode === "record" ? 1 : 2, total: 37,
        previous: { timeMs: 63104 }, recordBroken: mode === "record" || undefined, record: { timeMs: mode === "record" ? time : 61234, name: mode === "record" ? "Kei Mori" : "Vi Asada" },
        top: board(1).slice(0, 5).map((r, i) => ({ rank: r.rank, name: i === (mode === "record" ? 0 : 1) ? "Kei Mori" : r.name, timeMs: i === (mode === "record" ? 0 : 1) ? time : r.timeMs, me: i === (mode === "record" ? 0 : 1) || undefined })) }), 400);
    },
    /** F1 > Parkour's actions. */
    action(a: { type: string; course?: string; page?: number }): boolean {
      if (!a.type.startsWith("parkour.")) return false;
      if (a.type === "parkour.board") {
        const rows = a.course === "pk1" ? board(a.page ?? 1) : a.course === "pk4" ? [] : board(1).slice(0, 12);
        setTimeout(() => fire(PAGE_EVENTS.parkour, { kind: "board", course: a.course, page: 1, pages: 1, total: rows.length, shown: rows.length, rows, checkpoints: 6,
          best: { timeMs: 63104, rank: 2, runs: 14, splits: "" }, record: rows[0] ? { timeMs: rows[0].timeMs, name: rows[0].name, splits: rows[0].splits } : undefined }), 120);
      }
      if (a.type === "parkour.gps") fire(PAGE_EVENTS.result, { ok: true, text: "Route set to the start orb.", action: a.type });
      return true;
    },
    /** The editor's requests. */
    editor(payload: unknown): boolean {
      const p = payload as { operation?: string; request?: string };
      if (!p?.request) return true;
      const reply = (data: unknown) => setTimeout(() => fire(PAGE_EVENTS.parkourEditor, { kind: "response", request: p.request, ok: true, data }), 80);
      if (p.operation === "list") reply({ ready: true, courses: EDITOR_COURSES });
      else if (p.operation === "capture") reply({ position: { x: -1400 + Math.random() * 20, y: 150, z: 31 }, heading: 90 });
      else reply({ course: EDITOR_COURSES[0] });
      return true;
    },
  };
}
