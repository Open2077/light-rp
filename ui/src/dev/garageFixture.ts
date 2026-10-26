import type { GarageDialogPayload } from "@/bridge/protocol";

export function garageFixture(): GarageDialogPayload {
  return { kind: "garage", session: "garage:preview", nextRequest: 1, maxOutside: 1,
    spot: { id: "citycenter", name: "City Center // Public Garage" }, vehicles: [
      { id: "5be3a91c-a", key: "hella", label: "Archer Hella", category: "Street", status: "stored", garageId: "citycenter", garageName: "City Center // Public Garage", health: .84, canRetrieve: true, canStore: false },
      { id: "98f07e21-b", key: "apollo", label: "Brennan Apollo", category: "Bikes", status: "stored", garageId: "citycenter", garageName: "City Center // Public Garage", health: 1, canRetrieve: true, canStore: false },
      { id: "31c759ad-c", key: "galena", label: "Thorton Galena", category: "Street", status: "stored", garageId: "citycenter", garageName: "City Center // Public Garage", health: .62, canRetrieve: true, canStore: false },
    ] };
}
