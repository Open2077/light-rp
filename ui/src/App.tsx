import { useEffect } from "react";
import { announceReady, on } from "@/bridge/open77";
import { PAGE_EVENTS, type HudState, type MenuView, type NoticePayload, type ResultPayload, type UiStatePatch } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Hud } from "@/features/hud/Hud";
import { Menu } from "@/features/menu/Menu";
import { CharacterWizard } from "@/features/character/CharacterWizard";
import { NoticeLane } from "@/features/notices/NoticeLane";
import { WelcomeModal } from "@/features/welcome/WelcomeModal";

/* The one surface of the framework. Lua -> page events land in the store; the
   features read the store and raise actions back through the bridge. */
export function App() {
  const applyState = useStore((s) => s.applyState);
  const setHud = useStore((s) => s.setHud);
  const openMenu = useStore((s) => s.openMenu);
  const closeMenu = useStore((s) => s.closeMenu);
  const pushNotice = useStore((s) => s.pushNotice);
  const setResult = useStore((s) => s.setResult);
  const setConnected = useStore((s) => s.setConnected);

  useEffect(() => {
    const offs = [
      on<UiStatePatch>(PAGE_EVENTS.state, (patch) => { applyState(patch ?? {}); setConnected(true); }),
      on<HudState>(PAGE_EVENTS.hud, (hud) => { if (hud) setHud(hud); }),
      on<{ view?: MenuView }>(PAGE_EVENTS.open, (p) => openMenu(p?.view)),
      on(PAGE_EVENTS.closed, () => closeMenu()),
      on<NoticePayload>(PAGE_EVENTS.notice, (n) => pushNotice({
        id: n?.id, kind: n?.kind ?? "info", title: n?.title, body: n?.body, source: n?.source, durationMs: n?.durationMs ?? 8000,
      })),
      on<ResultPayload>(PAGE_EVENTS.result, (r) => {
        if (!r) return;
        setResult(r.ok, r.text);
        pushNotice({ kind: r.ok ? "success" : "error", title: r.ok ? undefined : "DENIED", body: r.text, source: "LIGHT RP", durationMs: 6000 });
      }),
    ];
    announceReady();
    return () => offs.forEach((off) => off());
  }, [applyState, setHud, openMenu, closeMenu, pushNotice, setResult, setConnected]);

  return (
    <>
      <Hud />
      <NoticeLane />
      <CharacterWizard />
      <WelcomeModal />
      <Menu />
    </>
  );
}
