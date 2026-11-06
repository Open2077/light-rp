/* Dev mock (no Open77 bridge), with ?registered=1:
   ?death=1       an activity death: the flatline cover, held (no medical panel);
   ?death=downed  a city death: the cover, then the server's unconscious state 500 ms later;
   ?death=revive  the city death, revived after 3.5 s: the reboot plays out;
   ?death=loop    dies every 6 s, respawns 2.5 s later (gun game pace). */
type Fire = (name: string, payload: unknown) => void;
const PAGE = "lightrp:ui:medical";
const downedState = { downed: true, persisted: true, phase: "downed", remainingMs: 240000, canGiveUp: false, receiving: false, bill: 850 };
export function deathMock(fire: Fire, params: URLSearchParams) {
  const mode = params.get("death");
  const cover = (down: boolean) => fire(PAGE, { kind: "cover", down, cause: "firearm" });
  return {
    boot() {
      if (!mode) return;
      if (mode === "loop") {
        const cycle = () => { cover(true); window.setTimeout(() => cover(false), 2500); };
        window.setTimeout(cycle, 400); window.setInterval(cycle, 6000);
        return;
      }
      window.setTimeout(() => cover(true), 400);
      if (mode === "downed" || mode === "revive") window.setTimeout(() => fire(PAGE, { kind: "state", state: downedState }), 900);
      if (mode === "revive") window.setTimeout(() => { cover(false); fire(PAGE, { kind: "state", state: { downed: false, phase: "healthy" } }); }, 4400);
    },
  };
}
