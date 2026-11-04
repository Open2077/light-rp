# Cyberpunk TCG: how the game is played

A working reference for building a playable mode on top of op77_tcg. It is a summary in our own words, not the official text.
- **Sources:**
  - WeirdCo's Comprehensive Rules (updated 2026-10-29, 11 sections), <https://cyberpunktcg.com/comprehensive-rules>;
  - the Gameplay Guide and its printable reminder sheet, <https://cyberpunktcg.com/gameplay-guide>;
  - the "Alpha to Beta" dev blog of 2026-05-29;
  - the Tournament Rules (2026-10-28).
- **Rule numbers** in brackets, such as [9.20], point to the Comprehensive Rules.
- **Precedence:** the current game is the **Beta** ruleset. Some guides still describe the older Alpha ruleset (Ready/Play/Attack phases, 6 Gigs to win, 2 €$ to Call), so check their date.
- **Local copies:** the full text, the guide PDFs and the four official figures (playmat, card anatomy, rarities, RAM colours) were saved on the development machine in `E:/Open77/tmp/tcg-rules/`. They are not shipped.

## 1. Goal and end of the game

- **Players.** There are two. Each player's opponent is their **Rival**.
- **Gigs.** Each player brings 6 polyhedral dice: a d4, d6, d8, d10, d12 and d20. One die is one **Gig**, whatever it shows.
- **Win.** You win if you start your turn with **7 or more Gigs** in your friendly Gig area. The check happens before the Ready step [1.10].
  - You only own 6 dice, so a win always needs at least one stolen Gig.
- **Overtime.** It begins after two consecutive turns in which both players began with an empty fixer area, which usually means after 7 turns each [1.11.1].
  - Overtime is sudden death: whoever controls 7+ Gigs at any moment wins at once.
  - If a player already has 7+ Gigs when overtime begins, they win immediately.
- **Lose.** You lose if you must draw from an empty deck. When an effect draws X cards, the first card you cannot draw is the losing draw [1.14]. You can also concede at any time.
- **Ties.** If both players win or lose simultaneously, the game is a tie.
- **Card effects** may add other ways to win or lose.

## 2. Golden rules [2]

- **Resolve everything.** Resolve as much of an effect as possible. "You may" parts are optional, "up to X" allows 0, and effects resolve in the order they are written.
- **Card text beats the rules.**
- **"Can't" beats "can".** A preventing effect beats a permitting one.
- **Costs are optional.** You may decline to pay a cost, and the effect then does not happen.
- **Simultaneous actions.** When both players act at the same time, the turn player goes first.
- **Negative numbers** exist but are treated as 0 in every comparison. **Null** (–) is not a number: it is not 0, and it is neither even nor odd.

## 3. Card anatomy [3]

- **Cost:** the top-left number, in €$. A **Sell Tag** (€$ icon) under the cost means the card can be sold for an Eddie.
  - Legends may have a **null cost** (–). Such a Legend cannot be played to the field, and its cost counts as 0 when an effect references it.
- **Type:** the top-right label: Legend, Unit, Gear or Program. A Legend on the field is both a Legend and a Unit.
- **RAM:** a number and a colour (Red, Green, Blue or Yellow) next to the type. It only matters for deck building (§6).
- **Name and subtitle.** The name identifies the card for rules. The subtitle tells versions apart: "V: Streetkid" and "V: Corporate Exile" are different cards with the same name.
  - A name with "&" counts as both names plus the combined name.
- **Tags** (MERC, CORPO, ARASAKA, NETRUNNER, NCPD, BRAINDANCE, …) have no rules meaning of their own. They matter only when an effect names them.
- **Power:** the bottom-right number. A Unit's power is its printed power plus its equipped Gear plus any modifiers.
- **Textbox:**
  - Effect text uses keywords and icons (§9).
  - Reminder text is italic, in parentheses, and has no game effect.
  - Flavour text is italic.
- **Printing details:** set information, card number, illustrator and **rarity**.
- **Rarities (7):** Common, Uncommon, Rare, Epic Rare, Secret Rare, Iconic Rare and Nova Rare.
  - The NetDeck card API also reports "Iconic Secret".
  - Our catalogue maps these onto tiers 1 to 6.
- **Orientation:**
  - **Ready** = upright; **spent** = sideways.
  - **Face-down** cards have no information except whether they are a Legend: Legends have their own card back.

## 4. Card types [4]

- **Legend**
  - **Deck:** exactly 3 per deck. They start face-down, in random order, in the Legends area.
  - **Valid areas:** a Legend may only be in the Legends area or on the field. Anywhere else, it is **removed from the game**.
  - **Call a Legend:** once per turn, flip one face-up for 1 €$ (§7).
  - **Paying with Legends:** any Legend in the Legends area can be spent to pay 1 €$, face-down or face-up. A face-up Legend can only do this if it has a Sell Tag. A Legend is never an Eddie.
  - **Playing to the field:** you may pay a Legend's cost to play it from the Legends area to the field as a Unit. It keeps its orientation and enters with Lag. GO SOLO Legends are the exception.
- **Unit**
  - Reveal it, pay its cost, and put it ready on the field. It enters with **Lag**.
  - There is no limit to the number of Units on the field.
- **Gear**
  - Pay its cost and equip it to a friendly Unit or friendly face-up Legend, by placing it under that card. There is no limit per Unit.
  - **Top textbox:** effects of the Gear itself, which matter when you play it.
  - **Bottom textbox:** text the Unit or Legend inherits, along with the Gear's power. Tags are not inherited.
  - **Moving:** Gear moves with its card to any area. Outside the field and Legends area it is no longer equipped, so if that card is played again later, the Gear stays where it is.
- **Program:** pay its cost and resolve it. While it resolves it is in no area; afterwards it goes to the trash, unless an effect top-decks or bottom-decks it.

## 5. Game areas (the playmat) [5]

The official playmat, seen from the player:

```
+---------+----[ RIVAL GIGS ]-----------+----[ FRIENDLY GIGS ]------+--------+
| FIXER   |                                                         |        |
|  d20    |                        FIELD                            |  DECK  |
|  d12    |              (your Units, no limit)                     |        |
|  d10    +---------------------------------+-----------------------+        |
|  d8     |  LEGENDS  [L1]  [L2]  [L3]      |        EDDIES         |  TRASH |
|  d6     |                                 |  (face-down cards)    |        |
|  d4     |                                 |                       |        |
+---------+---------------------------------+-----------------------+--------+
```

| Area | Visibility | Rules |
|---|---|---|
| Hand | hidden | No size limit. The Rival may always know how many cards are in it. |
| Deck | hidden | Single face-down stack. Never look at it or reorder it. Its card count is public. |
| Field | public | Units and played Legends. |
| Legends | public (face-down cards hidden) | 3 Legends. A Legend you have learned the identity of must be marked as known. |
| Eddies | public (contents hidden) | Each face-down card is 1 Eddie. Sold cards enter it **ready**. No limit. |
| Trash | public | Face-up pile. Either player may look through it. The owner may reorder it. |
| Fixer | public | Your 6 dice before they are rolled in. They are **not** your Gigs and do not count for Street Cred. |
| Friendly Gig area | public | Your Gigs. Their face values add up to your **Street Cred**. |
| Rival Gig area | public | A valid attack target while it holds at least 1 Gig. |
| Removed from game | public pile | Out of the game unless an effect brings a card back. |

- **Hidden areas:** a card entering a hidden area loses its modifiers.
- **Searches:** when you search a hidden area for specific cards, you may choose to "fail to find" and reveal nothing.

## 6. Deck building [7.3, 3.20]

- **Legends:** exactly **3**, all with different names (two "V" Legends cannot share a deck).
- **Main deck:** **40 to 50** non-Legend cards, with at most **3 copies** of each name + subtitle combination.
- **RAM limits:**
  - Each colour's limit is the sum of your Legends' RAM in that colour; every colour starts at 0.
  - A card is legal only if its RAM is at most the limit of its colour.
  - Example: Goro Takemura: Hands Unclean (2 Green), Saburo Arasaka: Stubborn Patriarch (2 Green) and Yorinobu Arasaka: Embracing Destruction (2 Red) give limits of **4 Green and 2 Red**. Blue and Yellow cards are not allowed.
  - The limits are fixed when the deck is built. Losing a Legend during play does not change them, and RAM never restricts what you may *play*.
- **Tournament sideboard:** 7 cards. The latest rules text says "0 or 7", while its appendix still requires exactly 7.

## 7. Setup [7.4–7.9]

1. **Choose who goes first.** Both players roll a d20 (reroll ties). The higher roller decides who goes first.
2. **Shuffle the deck.** Each player shuffles their main deck. The Rival may cut or shuffle it.
3. **Place the Legends.** Shuffle the 3 Legends and place them face-down, in random order. The Rival may also cut or shuffle them.
   - **The first player spends their 2 left-most Legends.** These do not ready during that player's first turn, which offsets the advantage of going first.
4. **Place the dice.** Put the dice in the fixer area, d4 at the bottom up to d20 at the top.
5. **Draw 6.** Each player may **mulligan once**: shuffle the hand back into the deck and draw 6 new cards. The first player decides and completes their mulligan before the second player decides.

## 8. Turn structure [8]

**Start phase.** Every step is mandatory and happens in this order:
1. Win check: do you control 7+ Gigs?
2. Start-of-turn effects. Effects that lasted "until the start of your next turn" end.
3. **Ready** every spent card in your Legends area, field and Eddies area.
4. **Draw 1.** An empty deck means you lose.
5. **Roll in a Gig.** Choose a die from your fixer area, roll it, and put it in your Gig area, keeping the rolled value.
   - You may pick any die, but the **d20 only when it is the last one** left.

**Main phase.** Every action is optional, in any order, and repeatable unless stated otherwise:
- **Sell for turn (once per turn).** Reveal a card with a Sell Tag from your hand and put it face-down and ready in your Eddies area.
  - The sold card is worth 1 €$ per turn from then on, whatever its cost.
  - Selling through card effects has no limit. An effect that says "sell" uses up this once-per-turn action, though.
- **Play a card.**
  - Pay with Eddies and/or Legends, at 1 €$ each.
  - Cost reductions cannot bring a payment below 1 €$.
  - A card played "for free" ignores cost changes but must still meet its other requirements.
- **Call a Legend (once per turn).**
  - Pay 1 €$ and flip one of your face-down Legends face-up **without looking at it first**. It keeps its orientation, and its CALL effect triggers.
  - You may also Call during the Rival's React step (§9). The once-per-turn limit counts across both turns: a Call made as a reaction uses up that turn's Call.
- **Activate effects.** Use the effects of friendly Units and face-up Legends, including spend-icon effects. Lagging Units cannot use their spend-icon effects.
- **Attack** with a Unit (§9). There are as many attacks as you have Units able to attack.
- **Pass.** The turn ends:
  - end-of-turn effects resolve;
  - "this turn" effects end;
  - all Units lose their **Lag**;
  - overtime starts if its condition is met;
  - the Rival's turn begins.

## 9. Attack, fight, steal [9, 11.4, 11.5]

**Declare the attack.**
- **Attacker:** a friendly **ready, non-lagging** Unit, which you **spend**.
- **Targets:**
  - a **spent** rival Unit, which starts a fight (ready Units cannot be attacked);
  - the **rival Gig area**, which steals Gigs; it must hold at least 1 Gig.
- **Triggers:** ATTACK effects and "when spent" effects resolve before the React step.
- **Ending early:** if the attacker or the defending Unit has left the field, the attack ends. No fight happens and nothing is stolen.

**React step.** The defending player may react any number of times:
- **Call a Legend**, if they have not already Called this turn.
- Use **BLOCKER**: spend a ready Unit to make it the new target. If a Gig-area attack is redirected this way, **nothing is stolen**, even if the attacker wins the fight.
- Use **QUICK** effects, or play QUICK Programs from hand.

Each reaction's triggers resolve before the next reaction. The defender ends the step when they choose to.

**Fight** (the target is a Unit):
1. "While fighting" effects apply.
2. Compare power. The higher one **wins**; equal power means **both lose**.
3. Losers are **defeated**: they go to the trash with their Gear, and their DEFEATED effects trigger.
   - A Unit with power 0 never defeats anything.
   - An effect may declare a winner or loser outright.

**Steal** (the target is the Gig area):
- **How many Gigs.** It depends on the attacker's power: X = floor(power / 10) + 1.

  | Attacker's power | Gigs stolen |
  |---|---|
  | 0 | none |
  | 1 to 9 | 1 |
  | 10 to 19 | 2 |
  | 20 to 29 | 3, and so on |

- **Choosing the Gigs.** The stealer picks the Gigs one at a time, any values. They then move together and **keep their values**.
  - "Would be stolen" effects resolve after a Gig is picked and before it moves.
  - "When stolen" effects trigger after it moves.
- **Swapping** a friendly Gig with a rival Gig is **not** stealing.

## 10. Effects and timing [10]

- **Effect kinds:**
  - **triggered** (has a trigger condition);
  - **activated** (main phase only, cost before the colon);
  - **persistent** (always on while the card is in the right area);
  - **replacement** ("would … instead").
- **Pending effects:**
  - An effect never interrupts another one. Effects triggered meanwhile become **pending**, and no action can be taken while anything is pending.
  - The turn player resolves all their pending effects first, then the Rival.
  - Each player chooses the order of their own pending effects.
  - If an effect triggers several times, it becomes pending once per trigger.
- **Conditions** of a triggered effect, beyond its trigger, are checked when it **resolves**, not when it triggers.
- **Missing targets:** an effect that needs a target or choice that does not exist is invalid. An effect that becomes invalid after triggering still resolves as much as it can, using the last known information.
- **Replacement order:** mandatory replacement effects apply before optional ones. Each replacement effect applies at most once per event.

## 11. Keywords, icons and terms [11]

**Trigger keywords** (highlighted labels on cards):

| Keyword | Meaning |
|---|---|
| **PLAY** | When you play this card. |
| **ATTACK** | When this Unit attacks: it is spent to declare the attack, and the effect resolves before the React step. |
| **CALL** | When this Legend is flipped face-up by Call a Legend. |
| **DEFEATED** | When this Unit, Legend or Gear is defeated. Use its last known state on the field (power, Gear). |

**Effect keywords:**

| Keyword | Meaning |
|---|---|
| **ADRENALINE** | This Unit can attack the turn it is played: it ignores Lag for attacking. |
| **BLOCKER** | When a rival Unit attacks, you may spend this Unit to make it the attack's target instead. A Unit cannot redirect an attack that already targets it. |
| **GO SOLO** | Pay this Legend's cost to play it as a **ready** Unit that can attack this turn. If it leaves the field, it is removed from the game. |
| **QUICK** | This effect, or this Program, can also be used as a reaction during the Rival's React step. Its cost is still paid. |

**Icons:**
- **Spend icon:** "spend this Unit or Legend to activate the following effect". Lagging Units cannot use it, and spending the card for another reason does not activate it.
- **★:** Street Cred.
- **X €$** before a colon: pay X with Eddies and/or Legends.

**Terms:**

| Term | Meaning |
|---|---|
| Street Cred | The sum of your Gig dice values. With no Gigs it is **null**, which is lower than 0 and neither even nor odd. |
| Lag | Entering Units cannot attack or use spend-icon effects until the end of the turn. |
| Draw X | Draw one card at a time, X times. |
| Trash X | Reveal the top card of your deck and put it in your trash, X times. |
| Search X | Look at the top X cards. Unless told otherwise, put them back in the same order. |
| Bottom-deck / Top-deck | Put cards under or on top of your deck, randomised, unless the effect says "in any order". You cannot do this to cards you do not own. |
| Reveal | Show a card to the Rival. |
| Flip | Turn a card face-up or face-down. |
| Equip / Move (Gear) | Attach a Gear under a card / move a Gear to another valid card. |
| Adjust / Increase / Decrease | Change a Gig's value. It must actually change: adjusting to the current value fails. |
| Set | Put a Gig on a specific face, which must exist on that die. |
| Min / max Gig | A die showing its lowest (1) / highest (its number of sides) face. A d10's "0" is 10. |
| Value-pair | Two of your dice showing the same value. Each die counts in one pair only. |
| Swap | Exchange one friendly Gig with one rival Gig, values unchanged. This is not stealing. |
| Defeat | Move a Unit, Legend or Gear from the field or Legends area to the trash. |
| Sell | Put a card face-down and ready in your Eddies area. |

## 12. Tournament play (organized play)

- **Constructed:**
  - **Swiss rounds:** **best-of-3** in 50 minutes at competition level. Local stores may also run 30-minute best-of-1 rounds.
  - **Top cut:** best-of-3 in 75 minutes, or best-of-1 in 55.
  - **Sideboarding:** 2 minutes between games, or 3 minutes before a best-of-1.
- **Time called:**
  - The current turn finishes, then each player gets one more turn of up to 5 minutes. If a player then controls 7+ Gigs, they win; otherwise the game is a draw.
  - In top cut, play continues until one player has more Gigs than the other.
- **Sealed / pre-release:**
  - **6 boosters of 12 cards**, 3 promo Legends, a promo card and dice.
  - A main deck of at least **30 cards**, up to 3 colours, **no RAM limits** and **no copy limit**.
  - Variants with fewer Legends add a blank Eddie for each missing Legend.
- **Dice checks:** a suspect die is rolled up to 80 times.
- **Sources for these points:** the official Tournament Rules, and a fan summary on gamertagmythras.com. The fan summary notes inconsistencies between versions of the rules.

## 13. Colours (play styles, not factions)

From a fan analysis (gamertagmythras.com), not official text:
- **Red:** maximise; high Gig values, power checks, destruction.
- **Green:** align; value-pairs, even Street Cred, Gigs matching Unit power.
- **Blue:** minimise and disable; low Street Cred, Programs and Braindance, bottom-decking threats.
- **Yellow:** diverge and repurpose; every Gig on a different value, Gear, sacrifice and scavenging.

## 14. Notes for op77_tcg

- **Card data:**
  - The NetDeck card API (`api.netdeck.gg/api/cards/cyberpunk[/<slug>]`, already used by `tools/fetch_official.py`) returns, per card, everything a rules engine needs: cost, power, RAM, colour, card type, keywords, tags, Sell Tag and rules text.
  - Card effects are free text: a full engine would need each of the 151 cards scripted. A simplified mode (cost, power and keywords only) is possible without scripting.
- **Rarity:** the official game has 7 rarities, and our catalogue has 6 tiers. The API's "Iconic Secret" editions are tier 6 (Secret) here.
- **Booster contents:**
  - A real booster has **12 cards** and a display holds **24 boosters**, as in op77_tcg.
  - WeirdCo has published **no pull rates**. Our booster composition (9 Common, 2 Uncommon, 1 Rare-or-better slot; `shared/config.lua` `pack`) is an assumption.
- **Table layout:** a playable table needs these areas per player: fixer, Gig area, field, Legends, Eddies, deck and trash (§5), plus 6 dice.
