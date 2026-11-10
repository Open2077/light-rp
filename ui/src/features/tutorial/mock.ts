import { PAGE_EVENTS, type TutorialState } from "@/bridge/protocol";

type Fire = (name: string, value: unknown) => void;

/* ?tutorial=walk|edge|near|reveal (with ?registered=1): the first day guide on its way to a stop,
   as the client feeds it. walk: the objective in view; edge: behind the camera (&angle=-120);
   near: within reach; reveal: the flight to the next stop. The page draws none of it any more:
   the card, the way and the flight are NativeUI (client/native/tutorial.lua, guide_pointer.lua;
   tools/native-lab/scenes/60_tutorial.lua plays them). The page's dialogs read this state. */
export function tutorialMock(fire: Fire, params: URLSearchParams) {
  const mode = params.get("tutorial");
  const tutorial: TutorialState | undefined = mode ? {
    active: true, available: true, status: "active", key: "default", step: "bank", revision: 4, index: 8, total: 15,
    title: "Open your bank account", guide: "Mara", where: "lobby", place: "Night City Bank", direction: "North of the square",
    line: "Idris keeps the bank. Tell him I sent you.",
    todo: [{ text: "Follow the arrow to the bank" }, { key: "interact", text: "Talk to Idris" }],
    objective: { position: { x: 0, y: 27.3, z: 0 }, label: "Idris, the banker", radius: 2.7, kind: "talk" },
  } : undefined;
  return {
    tutorial,
    boot() {
      if (!mode) return;
      fire(PAGE_EVENTS.tutorial, { phase: mode === "reveal" ? "reveal" : "idle", keys: { menu: "F1", inventory: "I", interact: "E", way: "G", quit: "F6", skip: "SPACE" },
        reveal: mode === "reveal" ? { name: "Night City Bank", direction: "North of the square", distance: 46, index: 8, total: 15, durationMs: 5600 } : false });
      if (mode === "reveal") return;
      const angle = Number(params.get("angle") ?? (mode === "edge" ? -128 : 6));
      const distance = mode === "near" ? 2 : Number(params.get("distance") ?? 46);
      const t0 = performance.now();
      const tick = () => {
        const t = (performance.now() - t0) / 1000;
        const drift = params.get("still") === "1" ? 0 : Math.sin(t * 0.7);
        fire(PAGE_EVENTS.tutorialGuide, { label: "Idris, the banker", distance, angle: Math.round(angle + drift * 4), rise: Number(params.get("rise") ?? 0) });
      };
      tick();
      window.setInterval(tick, 125);
      if (mode !== "walk") return;
      window.setInterval(() => {
        const t = (performance.now() - t0) / 1000;
        const drift = params.get("still") === "1" ? 0 : Math.sin(t * 0.7);
        fire("open77:anchors", { anchors: [{ id: "9", tag: "tutorial.guide", kind: "position", x: 0.47 + drift * 0.01, y: 0.4, depth: distance, distance, onScreen: true }] });
      }, 33);
    },
  };
}
