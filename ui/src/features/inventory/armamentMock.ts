import { PAGE_EVENTS, type ArmamentArgs, type ArmamentHand, type ArmamentOperation, type ArmamentState, type ArmamentWeapon, type InventoryDialogPayload, type InventoryItem } from "@/bridge/protocol";

export function armamentMock(fire: (name: string, value: unknown) => void, params: URLSearchParams) {
  const copy = <T,>(v: T): T => JSON.parse(JSON.stringify(v)) as T;
  const pistol = (slot: number, name: string, label: string, instanceId: string): InventoryItem => ({ slot, name, label, count: 1, stack: 1, weight: 1.2, usable: true, category: "weapon", icon: "crosshair", metadata: { instanceId }, description: "A serialized pistol. Equip it from your pockets." });
  const inventory: InventoryDialogPayload = { kind: "inventory", toggleKey: "I", left: { id: "player:1", kind: "player", label: "Yuki Tanaka", slots: 30, maxWeight: 40, weight: 4.1, items: [
    pistol(1, "weapon_lexington", "Militech Lexington", "11111111-1111-4111-8111-111111111111"),
    pistol(2, "weapon_nue", "Tsunami Nue", "22222222-2222-4222-8222-222222222222"),
    { slot: 3, name: "ammo_pistol_box", label: "Pistol ammunition box", count: 3, stack: 10, weight: 0.3, icon: "package", usable: true, category: "ammo", description: "A sealed box. Its contents are added to your shared pistol ammunition." },
    { slot: 4, name: "water", label: "Bottle of Water", count: 3, stack: 10, weight: 0.5, icon: "droplet", usable: true, category: "drink" },
  ] }, right: { id: "trunk:7306", kind: "trunk", label: "Archer Hella", slots: 20, maxWeight: 80, weight: 3, items: [{ slot: 1, name: "repairkit", label: "Repair Kit", count: 1, stack: 2, weight: 3, icon: "wrench", usable: false }] } };
  const state: ArmamentState = { ready: true, busy: false, revision: 0, ammo: { pistol: { remaining: 0, label: "Pistol rounds" } } };
  const completed = new Map<string, { state: ArmamentState }>();
  const push = () => fire(PAGE_EVENTS.armament, { kind: "state", state: copy(state) });
  const inventoryPush = () => fire(PAGE_EVENTS.inventory, { inventories: [copy(inventory.left)] });
  const boot = () => { push(); if (params.get("weapons") === "1") fire(PAGE_EVENTS.dialog, copy(inventory)); };
  const receive = (raw: unknown) => {
    const p = raw as ArmamentArgs & { operation: ArmamentOperation; request: string; mutation?: string };
    const reply = (ok: boolean, data?: { state: ArmamentState }, error?: string) => fire(PAGE_EVENTS.armament, { kind: "response", request: p.request, ok, data, error });
    if (p.operation === "state") { setTimeout(() => reply(true, { state: copy(state) }), 80); return; }
    const cached = p.mutation ? completed.get(p.mutation) : undefined;
    if (cached) { setTimeout(() => reply(true, cached), 80); return; }
    if (state.busy) { reply(false, undefined, "Equipment synchronization is already in progress."); return; }
    if (p.baseRevision !== state.revision) { reply(false, undefined, "Your equipment changed. Refresh its status before trying again."); return; }
    const item = inventory.left.items.find(i => i.slot === p.slot);
    let error: string | undefined;
    if (p.operation === "equip") {
      if (item?.category !== "weapon" || item.metadata?.instanceId !== p.instanceId || !p.hand) error = "This weapon is not in your pockets.";
      const other = p.hand === "left" ? state.right : state.left;
      if (other?.instanceId === p.instanceId) error = "One weapon cannot occupy both hands.";
      else if (other?.name === item?.name) error = "Pairs of the same pistol model are not supported.";
      else if (other && state.ammo.pistol.remaining < 62) error = "Not enough ammunition for two pistols. Open more boxes before trying again.";
      if (p.hand === "left" && !state.right) error = "Equip a right-hand pistol first.";
    } else if (p.operation === "ammo" && (item?.name !== "ammo_pistol_box" || item.count < 1)) error = "There is no sealed ammunition box in this slot.";
    if (error) { state.error = error; push(); reply(false, undefined, error); return; }
    state.busy = true; state.error = undefined; push();
    setTimeout(() => {
      if (p.operation === "equip" && item && p.hand) {
        const weapon: ArmamentWeapon = { instanceId: p.instanceId!, name: item.name, label: item.label,
          record: item.name === "weapon_nue" ? "Items.Preset_Nue_Default" : "Items.Preset_Lexington_Default", nativeSlot: p.hand === "right" ? 1 : 4 };
        state[p.hand] = weapon;
      } else if (p.operation === "unequip" && p.hand) { delete state[p.hand as ArmamentHand]; }
      else if (p.operation === "ammo" && item) {
        item.count--; if (!item.count) inventory.left.items = inventory.left.items.filter(i => i !== item);
        inventory.left.weight = Math.max(0, inventory.left.weight - item.weight);
        state.ammo.pistol.remaining += 30; inventoryPush();
      }
      state.busy = false; state.revision++; push();
      const data = { state: copy(state) }; if (p.mutation) completed.set(p.mutation, data);
      reply(true, data);
    }, 420);
  };
  return { boot, receive };
}
