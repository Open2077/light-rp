import type { InventoryItem } from "@/bridge/protocol";

// Browser-only visual fixture. Gameplay data always comes from shared/items.lua
// through authoritative server snapshots, never from this preview.
const foods = [
  ["burrito", "Burrito", .4, 10, 35, 0], ["synthmeat", "Synth-Meat Skewer", .3, 10, 25, 0],
  ["apple", "Apple", .2, 20, 12, 5], ["candy", "Candy Bar", .1, 20, 8, 0],
  ["noodles", "Street Ramen", .5, 8, 40, 5], ["dumplings", "Dumpling Box", .35, 8, 30, 0],
  ["pizza", "Synth-Pepperoni Slice", .3, 10, 28, 0], ["onigiri", "Onigiri", .15, 15, 18, 0],
  ["proteinbar", "Protein Ration", .12, 20, 22, 0],
] as const;
const drinks = [
  ["water", "Bottle of Water", .5, 10, 0, 30], ["soda", "NiCola", .4, 10, 5, 20],
  ["coffee", "Synth-Coffee", .3, 8, 0, 18], ["energydrink", "Volt Energy", .35, 10, 4, 22],
  ["electrolyte", "Electrolyte Mix", .5, 10, 0, 40], ["juice", "Citrus Blend", .25, 12, 6, 25],
] as const;
export const itemCatalogue: InventoryItem[] = [
  ...foods.map(([name, label, weight, stack, food, drink]) => ({ name, label, weight, stack, category: "food", icon: "sandwich", effects: { food, drink } })),
  ...drinks.map(([name, label, weight, stack, food, drink]) => ({ name, label, weight, stack, category: "drink", icon: "droplet", effects: { food, drink } })),
  { name: "bandage", label: "Bandage", weight: .2, stack: 10, category: "medical", icon: "bandage", effects: { health: 25 } },
  { name: "medkit", label: "MaxDoc", weight: .6, stack: 5, category: "medical", icon: "pill", effects: { health: 70 } },
  { name: "firstaid", label: "Field First Aid Kit", weight: 1, stack: 3, category: "medical", icon: "briefcase-medical", effects: { health: 45 } },
].map((item, i) => ({ ...item, slot: i + 1, count: 2, usable: true, image: `img/items/${item.name}.png`, description: "Catalogue preview · values and descriptions can be configured in shared/items.lua." }));
itemCatalogue.push({ name: "cash", label: "Eurodollars", slot: 19, count: 12500, weight: 0, stack: 1000000000, usable: false,
  category: "currency", icon: "banknote", image: "img/items/cash.png", description: "Physical cash. One unit is worth €$1. Split, give or store it like any other item. Only the cash in your pockets can be spent." });
