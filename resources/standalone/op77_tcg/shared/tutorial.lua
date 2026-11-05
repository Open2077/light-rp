-- The NEON DECK tutorial: a scripted demonstration duel against the house at a real duel table. The decks, the
-- order of the cards and the dice are fixed, so every rule is shown on a concrete move; a coach (the page) explains
-- each step and points at the table, the overlay and the 3D zones. Steps:
--   next = true          the player reads, then clicks Next
--   expect = { ... }     the player must make this move (other moves are refused with the step's hint)
--   house = { ... }      the house plays these moves, one by one, while the coach explains
--   settle = true        advances once no card choice is pending (a prompt was answered)
--   ui = { ... }         overlay elements to highlight (web/table.js COACH_TARGETS); card = a hand card to highlight
--   zones = { ... }      zones of the player's mat labelled in 3D on the table (client/duel.lua)
-- What the player reads (English or French, concept windows with pictures) lives in web/tutorial.js, keyed by id;
-- title/text here are the fallback and what the tests read.
-- The player is seat 1 (south), the house seat 2; the house goes first (the player's Legends are all ready).
TcgTutorial = {}

local filler = { "psycho_squad", "rockn_rockerboy", "maxtac_squadron", "delamain_cab", "emergency_atlus", "maelstrom_goons",
    "ruthless_lowlife", "6th_street_recruits", "riding_nomad", "swordwise_huscle" }
local function deck(top, n)
    -- The library draws from its end: `top` lists the next draws in order.
    local lib = {}
    for i = 1, n do lib[i] = filler[(i - 1) % #filler + 1] end
    for i = #top, 1, -1 do lib[#lib + 1] = top[i] end
    return lib
end

TcgTutorial.player = {
    name = "Tutorial",
    legends = { "dexter_deshawn_off_the_grid", "muamar_reyes_el_capitan", "wakako_okada_peace_and_harmony" },
    hand = { "mantis_blades", "emergency_atlus", "japantown_jonin", "corporate_surveillance", "kiroshi_optics", "floor_it" },
    library = function() return deck({ "field_operator", "swordwise_huscle", "delamain_rideshare_ai", "industrial_assembly" }, 30) end,
}
TcgTutorial.house = {
    legends = { "saburo_arasaka_stubborn_patriarch", "yorinobu_arasaka_embracing_destruction", "jackie_welles_pour_one_out_for_me" },
    hand = { "kiroshi_optics", "corpo_security", "psycho_squad", "maxtac_av", "minotaur", "rockn_rockerboy" },
    library = function() return deck({ "riding_nomad", "delamain_cab", "maelstrom_goons", "6th_street_recruits" }, 30) end,
}
-- The d20 for the first player, then every Gig roll in order (house 4, you 3, house 7, you 5, house 8, you 2).
TcgTutorial.d20 = { player = 9, house = 17 }
TcgTutorial.rolls = { 4, 3, 7, 5, 8, 2, 6, 4, 9, 3, 5, 6 }

TcgTutorial.steps = {
    -- The page shows two buttons (English / French): the coach's texts and the 3D labels follow the choice (web/tutorial.js).
    { id = "language", title = "Language", next = true, text = "Choose the language of the tutorial." },
    { id = "welcome", title = "Welcome to NEON DECK", next = true,
      text = "This is a demonstration duel against the house. Goal of the game: start one of your turns holding 7 Gigs (dice in your Gig area). You own only 6 dice, so you will have to steal at least one from your rival." },
    { id = "table", title = "Your side of the table", next = true, zones = { "fixer", "legends", "field", "eddies", "deck", "trash", "gigs" },
      text = "Look at your playmat: the labels show its areas. FIXER: your 6 dice waiting to be rolled. LEGENDS: your 3 Legend cards. FIELD: your Units. EDDIES: cards you sold, your money. DECK and TRASH on the right. GIGS: the dice you rolled in." },
    { id = "legends", title = "Your Legends", next = true, ui = { "legends" }, zones = { "legends" },
      text = "Your 3 Legends start face down: even you don't know which is where. Each one can pay 1 €$ by being spent (turned sideways). For 1 €$ you can Call one: it flips face up and its CALL effect happens." },
    { id = "hand", title = "Your hand", next = true, ui = { "hand" },
      text = "You drew 6 cards. Hover a card to read it large on the right: its cost (top left), its power (bottom right), its type, its rules text. The €$ icon under the cost is a Sell Tag." },
    { id = "d20", title = "Who goes first", next = true, ui = { "rival" },
      text = "Before the game both players rolled a d20: the house won (17 against 9) and chose to go first. The first player starts with two of its Legends spent, so it has less money on its first turn." },
    { id = "house1", title = "The house's first turn", ui = { "rivalBoard" },
      house = { { "roll", "d6" }, { "sell", "kiroshi_optics" }, { "play", "corpo_security" }, { "endTurn" } },
      text = "Watch the house: it rolls one die into its Gig area, sells Kiroshi Optics for an Eddie, then plays Corpo Security (2 €$). Corpo Security has BLOCKER: it can't attack, but it can step in front of an attack." },
    { id = "draw", title = "Your turn begins", next = true, ui = { "hand" },
      text = "At the start of your turn your spent cards ready and you draw 1 card (Field Operator just arrived in your hand). Then you roll one die from your fixer into your Gig area." },
    { id = "roll", title = "Roll a Gig in", ui = { "panel" }, zones = { "fixer" }, expect = { type = "roll" },
      text = "Click a die in the panel on the right. Any die is fine except the d20, which always comes last. Small dice show small values, big dice big ones." },
    { id = "gigs", title = "Gigs and Street Cred", next = true, ui = { "myGigs" }, zones = { "gigs" },
      text = "Your die is now a Gig. Each Gig counts toward the 7 you need, whatever its value. The values add up to your Street Cred, which some cards care about (\"if you have more Street Cred than a rival...\")." },
    { id = "sell", title = "Sell a card for money", ui = { "hand" }, card = "mantis_blades", expect = { type = "sell", card = "mantis_blades" },
      text = "Mantis Blades has a Sell Tag. Click it in your hand, then Sell: it goes face down into your Eddies and pays 1 €$ every turn from now on. You may sell one card per turn." },
    { id = "money", title = "How you pay", next = true, ui = { "money", "legends" }, zones = { "eddies", "legends" },
      text = "You now have 4 €$ ready: your 3 Legends and your new Eddie. Paying a cost spends them (they turn sideways) until your next turn." },
    { id = "play", title = "Play a Unit", ui = { "hand" }, card = "emergency_atlus", expect = { type = "play", card = "emergency_atlus" },
      text = "Click Emergency Atlus, then Play (3 €$). A Unit goes to your field, on the table in front of you." },
    { id = "lag", title = "Lag", next = true, ui = { "myBoard" }, zones = { "field" },
      text = "A Unit enters with LAG: it can't attack the turn it's played (cards with ADRENALINE or GO SOLO can). Next turn it will be ready to attack." },
    { id = "call", title = "Call a Legend", ui = { "legends" }, expect = { type = "call" },
      text = "You have 1 €$ left. Click one of your face-down Legends, then Call: it flips face up and its CALL effect triggers. One Call per turn." },
    { id = "choice", title = "Card choices", ui = { "panel" }, settle = true,
      text = "Its effect asks you to choose: the choices appear in the panel on the right. Whenever a card needs a target or a decision, it asks you there." },
    { id = "end1", title = "End your turn", ui = { "endTurn" }, expect = { type = "endTurn" },
      text = "You have nothing left to pay with. Click End turn: Lag wears off and the house plays." },
    { id = "house2", title = "The house's second turn", ui = { "rivalBoard" },
      house = { { "roll", "d8" }, { "play", "psycho_squad" }, { "endTurn" } },
      text = "The house rolls another Gig and plays Psycho Squad: 6 power. Remember it: next turn it can attack." },
    { id = "roll2", title = "Roll a Gig in", ui = { "panel" }, expect = { type = "roll" },
      text = "Your turn again: roll another die from your fixer." },
    { id = "attack", title = "Attack", ui = { "myBoard", "rivalGigs" }, expect = { type = "attack", target = "gigs" },
      text = "Emergency Atlus has no Lag any more. Click it in your board (bottom left), then click the house's Gigs (top left). Attacking spends the Unit. A Unit may attack the rival's Gigs, or a SPENT rival Unit." },
    { id = "block", title = "Blocker!", ui = { "rivalBoard" }, house = { { "block", "corpo_security" }, { "resolve" } },
      text = "The house reacts: Corpo Security uses BLOCKER and becomes the target. It's a fight: 4 power against 2. The higher power wins and the loser is defeated. A blocked attack on Gigs steals nothing." },
    { id = "fight", title = "Fights", next = true, ui = { "log" },
      text = "Corpo Security went to the trash. In a fight the higher power wins; equal power defeats both; a Unit with 0 power defeats nothing." },
    { id = "end2", title = "End your turn", ui = { "endTurn" }, expect = { type = "endTurn" },
      text = "Click End turn." },
    { id = "house3", title = "You are attacked", ui = { "rivalBoard", "myGigs" }, house = { { "roll", "d10" }, { "attack", "psycho_squad", "gigs" } },
      text = "The house rolls, then Psycho Squad attacks YOUR Gigs." },
    { id = "react", title = "Your React step", ui = { "panel" }, expect = { type = "resolve" },
      text = "When you are attacked you may react: block with a ready Unit that has BLOCKER, Call a Legend, or use a QUICK card. You have no Blocker: click Let it through." },
    { id = "stolen", title = "Stealing", ui = { "myGigs", "rivalGigs" }, house = { { "steal" }, { "endTurn" } },
      text = "Psycho Squad has 6 power: it steals 1 Gig (power 0: none, 1-9: one, 10-19: two...). The stealer picks which, and the Gig keeps its value." },
    { id = "roll3", title = "Roll a Gig in", ui = { "panel" }, expect = { type = "roll" },
      text = "Your turn: roll a die." },
    { id = "attack2", title = "Steal back", ui = { "myBoard", "rivalGigs" }, expect = { type = "attack", target = "gigs" },
      text = "The house has no Blocker left. Attack its Gigs with Emergency Atlus." },
    { id = "pick", title = "Pick the Gig", ui = { "rivalGigs", "panel" }, expect = { type = "steal" },
      text = "Click the house's Gig you take, then Steal. Taking a high one raises your Street Cred; taking any one brings you closer to 7 Gigs." },
    { id = "done", title = "You know the basics", next = true, final = true,
      text = "That's the game: roll Gigs, sell and pay, play Units, Gear and Programs, Call Legends, attack, block, steal, and start a turn with 7 Gigs. Hover any card to read what it does. Keep playing this duel against the house, or leave the table." },
}

TcgTutorial.byId = {}
for i, s in ipairs(TcgTutorial.steps) do s.index = i; TcgTutorial.byId[s.id] = s end
