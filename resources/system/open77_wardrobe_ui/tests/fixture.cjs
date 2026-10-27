// The real catalogue for page tests: every selectable record of
// open77_appearance/server/catalog.lua for one body family, with the slot the
// server admits it in. Labels are derived like WardrobeModel.title (the game's
// localized names only exist in a running client).
const fs = require('node:fs');
const path = require('node:path');

const CATALOG = path.resolve(__dirname, '../../open77_appearance/server/catalog.lua');

function catalogue(family = 'm') {
  const mask = family === 'f' ? 2 : 1;
  const seen = new Set(), items = [];
  for (const line of fs.readFileSync(CATALOG, 'utf8').split('\n')) {
    const m = line.match(/^add\("([^"]+)", "0x([0-9A-F]+)", "(\w+)", (\d+)/);
    if (!m) continue;
    const [, record, hash, slot, flagText] = m, flags = Number(flagText);
    if (!(flags & mask) || !(flags & 4) || seen.has(record) || slot.startsWith('Underwear')) continue;
    seen.add(record);
    items.push({ record, slot, tweakDbId: '0x' + hash, nonvisual: false });
  }
  return items;
}

function openState(overrides = {}) {
  return Object.assign({
    available: true, revision: 3, characterKey: 'default', family: 'male', persistence: 'ready',
    orbitAvailable: true, framingAvailable: true, takeAway: true,
    equipment: { Head: false, Face: 'Items.Cop_01_Set_Glasses', InnerChest: false, OuterChest: false, Legs: false, Feet: false, Outfit: false,
      UnderwearTop: false, UnderwearBottom: 'Items.Underwear_Basic_01_Bottom' },
    wardrobe: { active: false, outfits: {}, names: { 0: 'Night out' } },
  }, overrides);
}

module.exports = { catalogue, openState };
