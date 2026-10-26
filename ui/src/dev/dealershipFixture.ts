import type { DealershipDialogPayload } from "@/bridge/protocol";
export function dealershipFixture(): DealershipDialogPayload {
  return { kind: "dealership", session: "dealer-preview", nextRequest: 1,
    dealer: { id: "citycenter", name: "City Motors", subtitle: "Your next chapter starts here." },
    garage: { id: "citycenter", name: "City Center // Public Garage" }, money: { currency: "€$", cash: 5200, bank: 48000 },
    stock: [
      { key: "maimai", label: "Makigai MaiMai", category: "Street", price: 4000, description: "A small footprint. A big city. Your first set of keys." },
      { key: "galena", label: "Thorton Galena", category: "Street", price: 6500, description: "A practical everyday ride for getting your life in Night City started." },
      { key: "apollo", label: "Brennan Apollo", category: "Bikes", price: 5000, description: "Two wheels, a clear road and a little room to explore." },
      { key: "hella", label: "Archer Hella", category: "Street", price: 10000, description: "An understated daily driver, ready for the next shift." },
      { key: "colby", label: "Thorton Colby", category: "Street", price: 12000 },
      { key: "supron", label: "Mahir Supron", category: "Utility", price: 14000 },
      { key: "quartz", label: "Archer Quartz", category: "Street", price: 16000 },
      { key: "cortes", label: "Villefort Cortes", category: "Street", price: 28000 },
      { key: "kusanagi", label: "Yaiba Kusanagi", category: "Bikes", price: 45000 },
      { key: "semimaru", label: "Yaiba Semimaru", category: "Sport", price: 60000 },
    ] };
}
