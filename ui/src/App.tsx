import { useEffect } from "react";
import { announceReady, on, requestClose } from "@/bridge/open77";
import { PAGE_EVENTS, type DialogPayload, type HudState, type InventorySnapshot, type NoticePayload, type ResultPayload, type UiStatePatch } from "@/bridge/protocol";
import { useStore } from "@/state/store";
import { Hud } from "@/features/hud/Hud";
import { PlayerMenu } from "@/features/menu/PlayerMenu";
import { CharacterWizard } from "@/features/character/CharacterWizard";
import { NoticeLane } from "@/features/notices/NoticeLane";
import { WelcomeModal } from "@/features/welcome/WelcomeModal";
import { Tutorial } from "@/features/tutorial/Tutorial";
import { SupportDesk } from "@/features/support/SupportDesk";
import { RentalDialog } from "@/features/rental/RentalDialog";
import { InventoryDialog } from "@/features/inventory/Inventory";
import { JobCenterDialog } from "@/features/jobs/JobCenterDialog";
import { JobRunHud } from "@/features/jobs/JobRunHud";
import { JobGuide } from "@/features/jobs/JobGuide";
import { ErrorBoundary } from "@/design/ErrorBoundary";
import { InteractPrompt } from "@/features/hud/InteractPrompt";
import { Actions } from "@/features/actions/Actions";
import { ShopDialog } from "@/features/shop/ShopDialog";
import { VehicleCustomization } from "@/features/customization/VehicleCustomization";
import { GarageDialog } from "@/features/garage/GarageDialog";
import { HousingDialog } from "@/features/housing/HousingDialog";
import { DealershipDialog } from "@/features/dealership/DealershipDialog";
import { FuelDialog, FuelApproach } from "@/features/fuel/FuelDialog";
import { AnimationMenu } from "@/features/animations/AnimationMenu";
import { Freecam } from "@/features/freecam/Freecam";
import { MissionDialog } from "@/features/missions/MissionDialog";
import { ActivitiesDialog } from "@/features/activities/ActivitiesDialog";
import { MissionQueueHud } from "@/features/missions/MissionQueueHud";
import { FixerGigHud } from "@/features/missions/FixerGigHud";
import { MissionSquadHud } from "@/features/missions/MissionSquadHud";
import { RaidHud } from "@/features/missions/RaidHud";
import { ActivityHud } from "@/features/activityhud/ActivityHud";
import { Medical } from "@/features/medical/Medical";
import { Safezones } from "@/features/safezones/Safezones";
import { MissionEditor } from "@/features/missioneditor/MissionEditor";
import { MissionObjectiveHud } from "@/features/missions/MissionObjectiveHud";
import { WeaponWheel } from "@/features/weaponwheel/WeaponWheel";

/* The one surface of the framework. Lua -> page events land in the store; the
   features read the store and raise actions back through the bridge. */
export function App() {
  const customizationActive = useStore(s => s.customizationActive);
  const applyState = useStore((s) => s.applyState);
  const setHud = useStore((s) => s.setHud);
  const openMenu = useStore((s) => s.openMenu);
  const closeMenu = useStore((s) => s.closeMenu);
  const pushNotice = useStore((s) => s.pushNotice);
  const setResult = useStore((s) => s.setResult);
  const setConnected = useStore((s) => s.setConnected);
  const openDialog = useStore((s) => s.openDialog);
  const updateInventories = useStore((s) => s.updateInventories);

  useEffect(() => {
    const offs = [
      on<UiStatePatch>(PAGE_EVENTS.state, (patch) => { applyState(patch ?? {}); setConnected(true); }),
      on<HudState>(PAGE_EVENTS.hud, (hud) => { if (hud) setHud(hud); }),
      // The player menu waits for an active character: during creation or the
      // briefing the key hands the focus straight back.
      on(PAGE_EVENTS.open, () => {
        const c = useStore.getState().state.character;
        if (c.status !== "active" || c.welcomePending || useStore.getState().welcomeReplay) { requestClose(); return; }
        openMenu();
      }),
      on(PAGE_EVENTS.closed, () => closeMenu()),
      on<NoticePayload>(PAGE_EVENTS.notice, (n) => pushNotice({
        id: n?.id, kind: n?.kind ?? "info", title: n?.title, body: n?.body, source: n?.source, durationMs: n?.durationMs ?? 8000,
      })),
      on<ResultPayload>(PAGE_EVENTS.result, (r) => {
        if (!r) return;
        setResult(r.ok, r.text, r.action);
        pushNotice({ kind: r.ok ? "success" : "error", title: r.ok ? undefined : "DENIED", body: r.text, source: "LIGHT RP", durationMs: 6000 });
      }),
      on<DialogPayload>(PAGE_EVENTS.dialog, (d) => { if (d?.kind) openDialog(d); }),
      on<{ inventories?: InventorySnapshot[] }>(PAGE_EVENTS.inventory, (p) => { if (Array.isArray(p?.inventories)) updateInventories(p.inventories); }),
    ];
    announceReady();
    return () => offs.forEach((off) => off());
  }, [applyState, setHud, openMenu, closeMenu, pushNotice, setResult, setConnected, openDialog, updateInventories]);

  return (
    <>
      <div className="gameplay-interface" hidden={customizationActive}>
      <ErrorBoundary name="safezones"><Safezones /></ErrorBoundary>
      <ErrorBoundary name="mission-editor"><MissionEditor /></ErrorBoundary>
      <ErrorBoundary name="hud"><Hud /></ErrorBoundary>
      <ErrorBoundary name="work-order"><JobRunHud /></ErrorBoundary>
      <ErrorBoundary name="fuel-route"><FuelApproach /></ErrorBoundary>
      <ErrorBoundary name="mission-queue"><MissionQueueHud /></ErrorBoundary>
      <ErrorBoundary name="fixer-gig"><FixerGigHud /></ErrorBoundary>
      <ErrorBoundary name="mission-squad"><MissionSquadHud /></ErrorBoundary>
      <ErrorBoundary name="mission-objective"><MissionObjectiveHud /></ErrorBoundary>
      <ErrorBoundary name="raid"><RaidHud /></ErrorBoundary>
      <ErrorBoundary name="activity-hud"><ActivityHud /></ErrorBoundary>
      <ErrorBoundary name="interact"><InteractPrompt /></ErrorBoundary>
      <ErrorBoundary name="weapon-wheel"><WeaponWheel /></ErrorBoundary>
      <ErrorBoundary name="freecam"><Freecam /></ErrorBoundary>
      <ErrorBoundary name="notices"><NoticeLane /></ErrorBoundary>
      <ErrorBoundary name="wizard"><CharacterWizard /></ErrorBoundary>
      <ErrorBoundary name="welcome"><WelcomeModal /></ErrorBoundary>
      <ErrorBoundary name="tutorial"><Tutorial /></ErrorBoundary>
      <ErrorBoundary name="support"><SupportDesk /></ErrorBoundary>
      <ErrorBoundary name="rental"><RentalDialog /></ErrorBoundary>
      <ErrorBoundary name="shop"><ShopDialog /></ErrorBoundary>
      <ErrorBoundary name="garage"><GarageDialog /></ErrorBoundary>
      <ErrorBoundary name="housing"><HousingDialog /></ErrorBoundary>
      <ErrorBoundary name="dealership"><DealershipDialog /></ErrorBoundary>
      <ErrorBoundary name="mission"><MissionDialog /></ErrorBoundary>
      <ErrorBoundary name="activities"><ActivitiesDialog /></ErrorBoundary>
      <ErrorBoundary name="fuel"><FuelDialog /></ErrorBoundary>
      <ErrorBoundary name="inventory"><InventoryDialog /></ErrorBoundary>
      <ErrorBoundary name="jobcenter"><JobCenterDialog /></ErrorBoundary>
      <ErrorBoundary name="job-guide"><JobGuide /></ErrorBoundary>
      <ErrorBoundary name="menu"><PlayerMenu /></ErrorBoundary>
      <ErrorBoundary name="actions"><Actions /></ErrorBoundary>
      <ErrorBoundary name="medical"><Medical /></ErrorBoundary>
      <ErrorBoundary name="animations"><AnimationMenu /></ErrorBoundary>
      </div>
      <ErrorBoundary name="customization"><VehicleCustomization /></ErrorBoundary>
    </>
  );
}
