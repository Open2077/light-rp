/* Cyberpunk TCG, the tutorial's coach (English / French). The server scripts the demonstration duel (shared/tutorial.lua)
   and says which step is on; this page explains it like to someone who never played a card game:
   - the coach panel: what happens, why, and for a move to make, numbered clicks ("Do this");
   - concept windows: one idea per window (a Gig, a Unit, Lag...) with a picture, a plain explanation and an example.
     They open by themselves the first time a step needs them; the chips under the text and the Glossary reopen them;
   - the language is picked on the first step (English or French) and kept for the next tutorial.
   The game's own buttons stay in English: the coach quotes them as they are written ("Sell for 1 €$"). */
(function () {
  "use strict";
  var X = null;
  var $ = function (id) { return document.getElementById(id); };
  var KEY = "op77_tcg_tutorial_lang";
  var lang = "en";
  try { lang = localStorage.getItem(KEY) === "fr" ? "fr" : "en"; } catch (e) { /* no storage: English */ }
  var seen = {};              // concepts already shown this tutorial
  var queue = [];             // concepts waiting to open
  var lastStep = null;

  function esc(s) { return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function L(o) { return o ? (o[lang] || o.en) : ""; }
  function el(tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  function img(slug) { return X && X.cardImg ? X.cardImg(slug) : tcgAsset("img/backside.webp"); }

  /* ------------------------------------------------------------------------------------------------ words */
  var UI = {
    tutorial: { en: "TUTORIAL", fr: "TUTORIEL" },
    next: { en: "Next", fr: "Suivant" },
    leave: { en: "Leave the tutorial", fr: "Quitter le tutoriel" },
    keep: { en: "Keep playing", fr: "Continuer la partie" },
    leaveTable: { en: "Leave the table", fr: "Quitter la table" },
    doThis: { en: "Do this", fr: "À toi de jouer" },
    waitHouse: { en: "The house is playing, watch the table", fr: "La maison joue, regarde la table" },
    resolving: { en: "A card effect resolves", fr: "Un effet de carte se résout" },
    learn: { en: "Learn", fr: "Comprendre" },
    glossary: { en: "Glossary", fr: "Lexique" },
    gotIt: { en: "Got it", fr: "J'ai compris" },
    example: { en: "Example", fr: "Exemple" },
    allConcepts: { en: "Every word of the game", fr: "Tous les mots du jeu" },
    close: { en: "Close", fr: "Fermer" },
    pick: { en: "Choose the language of the tutorial", fr: "Choisis la langue du tutoriel" }
  };

  /* ------------------------------------------------------------------------------------------------ pictures */
  var DIE_SIDES = { d4: 3, d6: 4, d8: 4, d10: 5, d12: 5, d20: 6 };
  function dieSvg(kind, value, colour, size) {
    var n = DIE_SIDES[kind] || 4, r = 22, pts = [];
    for (var i = 0; i < n; i++) { var a = -Math.PI / 2 + i * 2 * Math.PI / n; pts.push((26 + r * Math.cos(a)).toFixed(1) + "," + (27 + r * Math.sin(a)).toFixed(1)); }
    if (n === 4) pts = ["6,7", "46,7", "46,47", "6,47"];
    return '<svg class="tu-die" viewBox="0 0 52 54" width="' + (size || 52) + '" height="' + (size || 52) + '"><polygon points="' + pts.join(" ") +
      '" fill="rgba(0,0,0,.35)" stroke="' + (colour || "#22d8e2") + '" stroke-width="2.5"/><text x="26" y="' + (value != null ? 32 : 31) +
      '" text-anchor="middle" font-size="' + (value != null ? 17 : 12) + '" font-weight="800" fill="#f2f6f8">' + (value != null ? value : kind) + "</text></svg>";
  }
  function cardPic(slug, cls) { return '<img class="tu-card ' + (cls || "") + '" alt="" src="' + img(slug) + '">'; }
  function back(cls) { return '<img class="tu-card ' + (cls || "") + '" alt="" src="' + tcgAsset("img/backside.webp") + '">'; }
  function arrow(label) { return '<div class="tu-arrow"><span>' + (label || "") + "</span></div>"; }
  function tag(text, cls) { return '<span class="tu-tag ' + (cls || "") + '">' + text + "</span>"; }
  function pin(n, x, y) { return '<i class="tu-pin" style="left:' + x + "%;top:" + y + '%">' + n + "</i>"; }

  // The playmat drawn as a plan, with the zones where they are on the real mat (client/duel.lua ZONES).
  function matPlan() {
    var z = [
      ["fixer", 1, 30, 13, 46, { en: "FIXER", fr: "FIXER" }, { en: "6 dice", fr: "6 dés" }],
      ["gigs", 52, 3, 38, 18, { en: "GIGS", fr: "GIGS" }, { en: "rolled dice", fr: "dés lancés" }],
      ["field", 17, 26, 64, 36, { en: "FIELD", fr: "TERRAIN" }, { en: "your Units", fr: "tes Units" }],
      ["legends", 17, 67, 30, 28, { en: "LEGENDS", fr: "LÉGENDES" }, { en: "3 cards", fr: "3 cartes" }],
      ["eddies", 51, 67, 30, 28, { en: "EDDIES", fr: "EDDIES" }, { en: "your money", fr: "ton argent" }],
      ["deck", 85, 30, 14, 34, { en: "DECK", fr: "PIOCHE" }, { en: "draw here", fr: "on pioche" }],
      ["trash", 85, 67, 14, 28, { en: "TRASH", fr: "DÉFAUSSE" }, { en: "used cards", fr: "cartes jetées" }]
    ];
    var h = '<div class="tu-mat">';
    z.forEach(function (q) {
      h += '<div class="tu-zone z-' + q[0] + '" style="left:' + q[1] + "%;top:" + q[2] + "%;width:" + q[3] + "%;height:" + q[4] + '%"><b>' + L(q[5]) + "</b><small>" + L(q[6]) + "</small></div>";
    });
    return h + '<div class="tu-you">' + (lang === "fr" ? "TOI (tu es assis ici)" : "YOU (you sit here)") + "</div></div>";
  }

  var CONCEPTS = {
    goal: {
      icon: "7", t: { en: "How you win", fr: "Comment on gagne" },
      art: function () {
        var h = '<div class="tu-row">';
        for (var i = 0; i < 7; i++) h += dieSvg(["d4", "d6", "d8", "d10", "d12", "d20", "d8"][i], null, i === 6 ? "#ff7a1a" : "#3fd28c", 46);
        return h + '</div><div class="tu-cap">' + (lang === "fr" ? "6 dés à toi + 1 volé = 7 Gigs = <b>VICTOIRE</b>" : "your 6 dice + 1 stolen = 7 Gigs = <b>YOU WIN</b>") + "</div>";
      },
      b: {
        en: "<p>Each player owns <b>6 dice</b>. During the game you throw them one by one onto the table: a thrown die is called a <b>Gig</b>.</p><p>You win when <b>one of your turns starts and you have 7 Gigs</b>.</p><p>But you only own 6 dice! So you <b>must steal at least one Gig</b> from your rival. That is the whole game: get your dice out, and steal.</p>",
        fr: "<p>Chaque joueur possède <b>6 dés</b>. Pendant la partie, tu les lances un par un sur la table : un dé lancé s'appelle un <b>Gig</b>.</p><p>Tu gagnes quand <b>un de tes tours commence et que tu as 7 Gigs</b>.</p><p>Mais tu n'as que 6 dés ! Donc tu <b>dois voler au moins un Gig</b> à ton adversaire. Tout le jeu est là : sortir tes dés, et voler.</p>"
      },
      ex: { en: "You have 6 Gigs. You attack, you steal 1 Gig from the house: 7. At the start of your next turn, you win.",
            fr: "Tu as 6 Gigs. Tu attaques et tu voles 1 Gig à la maison : 7. Au début de ton tour suivant, tu as gagné." }
    },
    mat: {
      icon: "▦", t: { en: "Your playmat", fr: "Ton tapis de jeu" },
      art: matPlan,
      b: {
        en: "<p>The mat in front of you has <b>7 areas</b>. Each kind of card always goes to the same place.</p><ul><li><b>FIXER</b>: your dice that are not thrown yet.</li><li><b>GIGS</b>: the dice you threw. You want 7 here.</li><li><b>FIELD</b>: your fighters (Units).</li><li><b>LEGENDS</b>: 3 special cards, face down.</li><li><b>EDDIES</b>: the cards you sold, your money.</li><li><b>DECK</b> and <b>TRASH</b>: where you draw, where used cards go.</li></ul><p>Look at the table: the same names float above your real mat.</p>",
        fr: "<p>Le tapis devant toi a <b>7 zones</b>. Chaque sorte de carte va toujours au même endroit.</p><ul><li><b>FIXER</b> : tes dés pas encore lancés.</li><li><b>GIGS</b> : les dés que tu as lancés. Tu en veux 7 ici.</li><li><b>TERRAIN</b> (Field) : tes combattants (les Units).</li><li><b>LÉGENDES</b> : 3 cartes spéciales, face cachée.</li><li><b>EDDIES</b> : les cartes que tu as vendues, ton argent.</li><li><b>PIOCHE</b> (Deck) et <b>DÉFAUSSE</b> (Trash) : où tu pioches, où vont les cartes utilisées.</li></ul><p>Regarde la table : les mêmes noms flottent au-dessus de ton vrai tapis.</p>"
      }
    },
    card: {
      icon: "#", t: { en: "How to read a card", fr: "Comment lire une carte" },
      art: function () {
        return '<div class="tu-anat">' + cardPic("emergency_atlus", "big") + pin(1, -9, 9) + pin(2, 109, 6) + pin(3, -9, 69) + pin(4, -9, 84) + pin(5, 109, 92) +
          '<i class="tu-lead" style="left:-6%;top:9%;width:7%"></i><i class="tu-lead r" style="left:99%;top:6%;width:7%"></i>' +
          '<i class="tu-lead" style="left:-6%;top:69%;width:12%"></i><i class="tu-lead" style="left:-6%;top:84%;width:12%"></i><i class="tu-lead r" style="left:95%;top:92%;width:11%"></i>'  + "</div>";
      },
      b: {
        en: "<ol><li><b>Cost</b> (top left): how much money (€$) you pay to play it. Here: 3.</li><li><b>Type</b> (top right): UNIT, GEAR, PROGRAM or LEGEND. It tells you what the card does.</li><li><b>Name</b>.</li><li><b>Text</b>: its special power, if it has one. Words like <b>BLOCKER</b> are rules you will learn.</li><li><b>Power</b> (bottom right): how strong it is in a fight. Here: 4.</li></ol><p>Hover any card with the mouse: it shows large on the right so you can read it.</p>",
        fr: "<ol><li><b>Coût</b> (en haut à gauche) : combien d'argent (€$) tu paies pour la jouer. Ici : 3.</li><li><b>Type</b> (en haut à droite) : UNIT, GEAR, PROGRAM ou LEGEND. Ça dit ce que fait la carte.</li><li><b>Nom</b>.</li><li><b>Texte</b> : son pouvoir spécial, si elle en a un. Les mots comme <b>BLOCKER</b> sont des règles que tu vas apprendre.</li><li><b>Puissance</b> (en bas à droite) : sa force en combat. Ici : 4.</li></ol><p>Passe la souris sur n'importe quelle carte : elle s'affiche en grand à droite pour la lire.</p>"
      }
    },
    legend: {
      icon: "★", t: { en: "Legends", fr: "Les Légendes" },
      art: function () {
        return '<div class="tu-row">' + back() + back("spent") + arrow(lang === "fr" ? "CALL" : "CALL") + cardPic("dexter_deshawn_off_the_grid") + "</div>" +
          '<div class="tu-cap">' + (lang === "fr" ? "face cachée &middot; tournée = dépensée &middot; retournée = appelée" : "face down &middot; sideways = spent &middot; flipped = Called") + "</div>";
      },
      b: {
        en: "<p>You start with <b>3 Legends</b>: famous characters of Night City, placed <b>face down</b>. Even you don't know which is where.</p><p>They do two things:</p><ul><li><b>They are money.</b> Each Legend can pay 1 €$ per turn: it turns sideways (it is <b>spent</b>).</li><li><b>You can Call one</b> (1 €$, once per turn): it flips face up and its <b>CALL</b> effect happens at once.</li></ul>",
        fr: "<p>Tu commences avec <b>3 Légendes</b> : des personnages célèbres de Night City, posés <b>face cachée</b>. Même toi tu ne sais pas laquelle est où.</p><p>Elles servent à deux choses :</p><ul><li><b>C'est de l'argent.</b> Chaque Légende peut payer 1 €$ par tour : elle se tourne sur le côté (elle est <b>dépensée</b>).</li><li><b>Tu peux en appeler une</b> (Call, 1 €$, une fois par tour) : elle se retourne face visible et son effet <b>CALL</b> se produit tout de suite.</li></ul>"
      },
      ex: { en: "You Call a Legend: Dexter DeShawn flips up and his Call effect lets you pick something. Legends that are face up stay in the Legends area.",
            fr: "Tu appelles une Légende : Dexter DeShawn se retourne et son effet Call te fait choisir quelque chose. Une Légende face visible reste dans la zone des Légendes." }
    },
    turn: {
      icon: "⟳", t: { en: "A turn, step by step", fr: "Un tour, étape par étape" },
      art: function () {
        var s = lang === "fr" ? ["Tout se redresse<br>+ pioche 1 carte", "Lance 1 dé<br>= 1 Gig", "Vends, joue,<br>appelle, attaque", "Fin du tour"] : ["Everything readies<br>+ draw 1 card", "Roll 1 die<br>= 1 Gig", "Sell, play,<br>Call, attack", "End turn"];
        return '<div class="tu-steps">' + s.map(function (x, i) { return '<div><i>' + (i + 1) + "</i><span>" + x + "</span></div>"; }).join("") + "</div>";
      },
      b: {
        en: "<p>Players play <b>one after the other</b>. Your turn is always the same 4 steps:</p><ol><li><b>Ready and draw.</b> Your sideways cards stand up again, and you take 1 card from your deck.</li><li><b>Roll a Gig.</b> You throw one die from your fixer: it becomes a Gig.</li><li><b>Do things</b> in any order: sell one card, play cards, Call a Legend, attack.</li><li><b>End turn.</b> Then it is your rival's turn.</li></ol><p>At the start, both players roll a d20 (a 20-sided die): the higher one chooses who goes first.</p>",
        fr: "<p>Les joueurs jouent <b>chacun leur tour</b>. Ton tour, c'est toujours les mêmes 4 étapes :</p><ol><li><b>Redresser et piocher.</b> Tes cartes tournées se redressent, et tu prends 1 carte de ta pioche.</li><li><b>Lancer un Gig.</b> Tu lances un dé de ton fixer : il devient un Gig.</li><li><b>Agir</b> dans l'ordre que tu veux : vendre une carte, jouer des cartes, appeler une Légende, attaquer.</li><li><b>Fin du tour.</b> C'est ensuite au tour de l'adversaire.</li></ol><p>Au début, chaque joueur lance un d20 (un dé à 20 faces) : le plus haut choisit qui commence.</p>"
      }
    },
    ready: {
      icon: "⟲", t: { en: "Ready and spent", fr: "Prête ou dépensée" },
      art: function () {
        return '<div class="tu-row">' + cardPic("emergency_atlus") + arrow(lang === "fr" ? "utilisée" : "used") + cardPic("emergency_atlus", "spent") + "</div>" +
          '<div class="tu-cap">' + (lang === "fr" ? "<b>debout</b> = prête &middot; <b>sur le côté</b> = dépensée" : "<b>upright</b> = ready &middot; <b>sideways</b> = spent") + "</div>";
      },
      b: {
        en: "<p>A card standing <b>upright is ready</b>: you can use it. When you use it (to pay, or to attack), it turns <b>sideways</b>: it is <b>spent</b>, and you cannot use it again this turn.</p><p>At the start of each of your turns, <b>everything stands up again</b>.</p>",
        fr: "<p>Une carte <b>debout est prête</b> : tu peux l'utiliser. Quand tu l'utilises (pour payer, ou pour attaquer), elle se tourne <b>sur le côté</b> : elle est <b>dépensée</b>, et tu ne peux plus l'utiliser ce tour-ci.</p><p>Au début de chacun de tes tours, <b>tout se redresse</b>.</p>"
      }
    },
    fixer: {
      icon: "⬡", t: { en: "Your 6 dice (the fixer)", fr: "Tes 6 dés (le fixer)" },
      art: function () {
        return '<div class="tu-row">' + ["d4", "d6", "d8", "d10", "d12", "d20"].map(function (d) { return '<div class="tu-dl">' + dieSvg(d, null, d === "d20" ? "#ff7a1a" : "#22d8e2", 50) + "<small>1-" + d.slice(1) + "</small></div>"; }).join("") + "</div>";
      },
      b: {
        en: "<p>Your 6 dice wait in the <b>FIXER</b> area: a d4 (numbers 1 to 4), d6, d8, d10, d12 and a d20 (1 to 20).</p><p>Each turn you throw <b>one</b> of them. Small dice give small numbers, big dice big numbers.</p><p>The <b>d20</b> is special: it can only be thrown <b>last</b>, when it is your only die left.</p>",
        fr: "<p>Tes 6 dés attendent dans la zone <b>FIXER</b> : un d4 (chiffres de 1 à 4), d6, d8, d10, d12 et un d20 (de 1 à 20).</p><p>À chaque tour tu en lances <b>un seul</b>. Les petits dés donnent des petits chiffres, les gros dés des gros chiffres.</p><p>Le <b>d20</b> est spécial : il ne peut être lancé qu'en <b>dernier</b>, quand c'est ton dernier dé.</p>"
      }
    },
    gig: {
      icon: "◆", t: { en: "What is a Gig?", fr: "C'est quoi un Gig ?" },
      art: function () {
        return '<div class="tu-row">' + '<div class="tu-box">' + dieSvg("d8", null, "#22d8e2", 50) + "<small>FIXER</small></div>" + arrow(lang === "fr" ? "lancé" : "rolled") +
          '<div class="tu-box on">' + dieSvg("d8", 6, "#3fd28c", 58) + "<small>GIGS</small></div></div>";
      },
      b: {
        en: "<p>A <b>Gig</b> is a die that was thrown: it lies in your <b>GIGS</b> area and shows a number.</p><ul><li><b>Every Gig counts as 1</b> toward the 7 you need, small or big.</li><li>Your rival can <b>steal</b> your Gigs by attacking you, and you can steal theirs. A stolen Gig keeps its number.</li></ul>",
        fr: "<p>Un <b>Gig</b>, c'est un dé qui a été lancé : il est posé dans ta zone <b>GIGS</b> et montre un chiffre.</p><ul><li><b>Chaque Gig compte pour 1</b> vers les 7 qu'il te faut, qu'il soit petit ou grand.</li><li>Ton adversaire peut <b>voler</b> tes Gigs en t'attaquant, et toi les siens. Un Gig volé garde son chiffre.</li></ul>"
      },
      ex: { en: "You roll the d8 and get 6: you now have a Gig worth 6. One Gig out of 7.",
            fr: "Tu lances le d8 et tu fais 6 : tu as maintenant un Gig qui vaut 6. Un Gig sur 7." }
    },
    streetcred: {
      icon: "Σ", t: { en: "Street Cred", fr: "La Street Cred" },
      art: function () {
        return '<div class="tu-row">' + dieSvg("d8", 6, "#3fd28c", 48) + "<b class='tu-op'>+</b>" + dieSvg("d4", 3, "#3fd28c", 48) + "<b class='tu-op'>+</b>" + dieSvg("d10", 7, "#3fd28c", 48) + "<b class='tu-op'>=</b><b class='tu-big'>16</b></div>";
      },
      b: {
        en: "<p>Add up the numbers on all your Gigs: that is your <b>Street Cred</b> (your reputation).</p><p>It does <b>not</b> make you win. But some cards say things like \"if you have more Street Cred than your rival...\": then big numbers help.</p>",
        fr: "<p>Additionne les chiffres de tous tes Gigs : c'est ta <b>Street Cred</b> (ta réputation).</p><p>Elle ne te fait <b>pas</b> gagner. Mais certaines cartes disent des choses comme « si tu as plus de Street Cred que ton adversaire... » : là, les gros chiffres aident.</p>"
      }
    },
    sell: {
      icon: "€$", t: { en: "Selling a card", fr: "Vendre une carte" },
      art: function () {
        return '<div class="tu-row"><div class="tu-anat">' + cardPic("mantis_blades", "mid") + '<i class="tu-ring" style="left:13.5%;top:18.5%"></i></div>' + arrow(lang === "fr" ? "vendue" : "sold") +
          '<div class="tu-box">' + back("small") + "<small>EDDIES</small></div><b class='tu-big'>+1 €$</b></div>";
      },
      b: {
        en: "<p>Some cards have a <b>Sell Tag</b>: the little <b>€$</b> under the cost.</p><p>You may <b>sell one card per turn</b>: it goes face down into your <b>EDDIES</b> area and becomes money: <b>+1 €$ every turn</b>, for the rest of the game.</p><p>Selling early = more money later. But a sold card can no longer be played.</p>",
        fr: "<p>Certaines cartes ont un <b>Sell Tag</b> : le petit <b>€$</b> sous le coût.</p><p>Tu peux <b>vendre une carte par tour</b> : elle va face cachée dans ta zone <b>EDDIES</b> et devient de l'argent : <b>+1 €$ à chaque tour</b>, jusqu'à la fin de la partie.</p><p>Vendre tôt = plus d'argent plus tard. Mais une carte vendue ne peut plus être jouée.</p>"
      }
    },
    eddies: {
      icon: "€$", t: { en: "Money (€$)", fr: "L'argent (€$)" },
      art: function () {
        return '<div class="tu-row">' + back("small") + back("small") + back("small") + "<span class='tu-plus'>+</span>" + back("small") + "<b class='tu-op'>=</b><b class='tu-big'>4 €$</b></div>" +
          '<div class="tu-cap">' + (lang === "fr" ? "3 Légendes + 1 Eddie = 4 €$ par tour" : "3 Legends + 1 Eddie = 4 €$ per turn") + "</div>";
      },
      b: {
        en: "<p>Money in this game is called <b>Eddies (€$)</b>. You don't count coins: <b>each ready card pays 1 €$</b>.</p><ul><li>Your <b>3 Legends</b>: 1 €$ each.</li><li>Your <b>sold cards</b> (EDDIES area): 1 €$ each.</li></ul><p>To pay 3 €$, three of them turn sideways. They stand up again at your next turn: you get your money back every turn.</p>",
        fr: "<p>L'argent du jeu s'appelle les <b>Eddies (€$)</b>. Pas de pièces à compter : <b>chaque carte prête paie 1 €$</b>.</p><ul><li>Tes <b>3 Légendes</b> : 1 €$ chacune.</li><li>Tes <b>cartes vendues</b> (zone EDDIES) : 1 €$ chacune.</li></ul><p>Pour payer 3 €$, trois d'entre elles se tournent sur le côté. Elles se redressent à ton tour suivant : tu récupères ton argent à chaque tour.</p>"
      }
    },
    unit: {
      icon: "U", t: { en: "What is a Unit?", fr: "C'est quoi une Unit ?" },
      art: function () {
        return '<div class="tu-row"><div class="tu-anat">' + cardPic("emergency_atlus", "mid") + '<i class="tu-ring" style="left:88.5%;top:91.5%"></i></div>' + arrow(lang === "fr" ? "jouée" : "played") +
          '<div class="tu-box wide"><small>' + (lang === "fr" ? "TERRAIN" : "FIELD") + "</small>" + cardPic("emergency_atlus", "small") + "</div></div>";
      },
      b: {
        en: "<p>A <b>Unit</b> is a <b>fighter</b>: a person, a gang, a vehicle. You pay its cost and it goes to your <b>FIELD</b>, in front of you.</p><p>Units are the cards that <b>attack</b> to steal Gigs, and that <b>fight</b>. The number at the bottom right is its <b>power</b>: the bigger, the stronger.</p>",
        fr: "<p>Une <b>Unit</b>, c'est un <b>combattant</b> : une personne, un gang, un véhicule. Tu paies son coût et elle va sur ton <b>TERRAIN</b>, devant toi.</p><p>Ce sont les Units qui <b>attaquent</b> pour voler des Gigs, et qui <b>se battent</b>. Le chiffre en bas à droite est sa <b>puissance</b> : plus il est grand, plus elle est forte.</p>"
      },
      ex: { en: "Emergency Atlus costs 3 €$ and has 4 power.", fr: "Emergency Atlus coûte 3 €$ et a 4 de puissance." }
    },
    lag: {
      icon: "L", t: { en: "Lag", fr: "Le Lag" },
      art: function () {
        return '<div class="tu-row"><div class="tu-anat">' + cardPic("emergency_atlus") + '<b class="tu-stamp">LAG</b></div><div class="tu-cap left">' +
          (lang === "fr" ? "Ce tour : <b>ne peut pas attaquer</b><br>Tour suivant : <b>prête</b>" : "This turn: <b>cannot attack</b><br>Next turn: <b>ready</b>") + "</div></div>";
      },
      b: {
        en: "<p>A Unit you just played <b>arrives tired</b>: it has <b>Lag</b>. It <b>cannot attack the turn it is played</b>.</p><p>At your next turn the Lag is gone and it can attack. (A few cards with <b>ADRENALINE</b> or <b>GO SOLO</b> ignore this.)</p>",
        fr: "<p>Une Unit que tu viens de jouer <b>arrive fatiguée</b> : elle a du <b>Lag</b>. Elle <b>ne peut pas attaquer le tour où elle est jouée</b>.</p><p>À ton tour suivant le Lag disparaît et elle peut attaquer. (Quelques cartes avec <b>ADRENALINE</b> ou <b>GO SOLO</b> échappent à cette règle.)</p>"
      }
    },
    attack: {
      icon: "➜", t: { en: "Attacking", fr: "Attaquer" },
      art: function () {
        return '<div class="tu-row">' + cardPic("emergency_atlus") + arrow(lang === "fr" ? "attaque" : "attacks") + '<div class="tu-box on">' + dieSvg("d6", 4, "#ff3d4a", 44) + dieSvg("d4", 2, "#ff3d4a", 44) +
          "<small>" + (lang === "fr" ? "SES GIGS" : "THEIR GIGS") + "</small></div></div>";
      },
      b: {
        en: "<p>On your turn, a <b>ready</b> Unit without Lag can attack. Attacking <b>spends</b> it (it turns sideways).</p><p>It attacks one of two things:</p><ul><li>the rival's <b>Gigs</b>: if nothing stops it, <b>you steal Gigs</b>;</li><li>a <b>spent</b> rival Unit: they <b>fight</b>.</li></ul><p>The rival can try to stop the attack with a <b>Blocker</b>.</p>",
        fr: "<p>Pendant ton tour, une Unit <b>prête</b> et sans Lag peut attaquer. Attaquer la <b>dépense</b> (elle se tourne).</p><p>Elle attaque une de ces deux choses :</p><ul><li>les <b>Gigs</b> de l'adversaire : si rien ne l'arrête, <b>tu voles des Gigs</b> ;</li><li>une Unit adverse <b>dépensée</b> : elles <b>se battent</b>.</li></ul><p>L'adversaire peut essayer d'arrêter l'attaque avec un <b>Blocker</b>.</p>"
      }
    },
    blocker: {
      icon: "B", t: { en: "BLOCKER", fr: "BLOCKER (bloqueur)" },
      art: function () {
        return '<div class="tu-row">' + cardPic("emergency_atlus") + arrow("") + '<div class="tu-anat">' + cardPic("corpo_security") + '<b class="tu-stamp blue">BLOCKER</b></div>' +
          '<div class="tu-box">' + dieSvg("d6", 4, "#22d8e2", 40) + "<small>GIGS</small></div></div>";
      },
      b: {
        en: "<p>A Unit with <b>BLOCKER</b> is a bodyguard. When the rival attacks, a ready Blocker can <b>jump in front</b>: the attack now hits the Blocker instead.</p><p>Then the two Units <b>fight</b>, and the attacker <b>steals nothing</b>, even if it wins.</p><p>Most Blockers cannot attack themselves.</p>",
        fr: "<p>Une Unit avec <b>BLOCKER</b> est un garde du corps. Quand l'adversaire attaque, un Blocker prêt peut <b>se mettre devant</b> : l'attaque le frappe lui à la place.</p><p>Les deux Units <b>se battent</b>, et l'attaquant <b>ne vole rien</b>, même s'il gagne.</p><p>La plupart des Blockers ne peuvent pas attaquer eux-mêmes.</p>"
      }
    },
    fight: {
      icon: "VS", t: { en: "Fights", fr: "Les combats" },
      art: function () {
        return '<div class="tu-fight"><div><b>4</b><i style="width:100%"></i><span>Emergency Atlus</span><em class="win">' + (lang === "fr" ? "GAGNE" : "WINS") + "</em></div>" +
          '<div><b>2</b><i class="lose" style="width:50%"></i><span>Corpo Security</span><em class="lose">' + (lang === "fr" ? "DÉTRUITE" : "DEFEATED") + "</em></div></div>";
      },
      b: {
        en: "<p>In a fight, compare the <b>powers</b> (bottom right of each card):</p><ul><li>the <b>bigger power wins</b>; the loser is <b>defeated</b> and goes to the trash;</li><li><b>equal</b> powers: <b>both</b> are defeated;</li><li>a Unit with <b>0 power</b> defeats nobody.</li></ul>",
        fr: "<p>Dans un combat, on compare les <b>puissances</b> (en bas à droite de chaque carte) :</p><ul><li>la <b>plus grande puissance gagne</b> ; le perdant est <b>détruit</b> et part à la défausse ;</li><li>puissances <b>égales</b> : les <b>deux</b> sont détruites ;</li><li>une Unit à <b>0</b> de puissance ne détruit personne.</li></ul>"
      },
      ex: { en: "Emergency Atlus (4) against Corpo Security (2): 4 is bigger, Corpo Security is defeated.", fr: "Emergency Atlus (4) contre Corpo Security (2) : 4 est plus grand, Corpo Security est détruite." }
    },
    react: {
      icon: "!", t: { en: "When you are attacked", fr: "Quand on t'attaque" },
      art: function () {
        var o = lang === "fr" ? ["Bloquer avec un BLOCKER", "Appeler une Légende", "Jouer une carte QUICK", "Laisser passer"] : ["Block with a BLOCKER", "Call a Legend", "Play a QUICK card", "Let it through"];
        return '<div class="tu-steps">' + o.map(function (x, i) { return "<div><i>" + "ABCD"[i] + "</i><span>" + x + "</span></div>"; }).join("") + "</div>";
      },
      b: {
        en: "<p>When your rival attacks you, the game <b>pauses</b> and you get a chance to <b>react</b>. You can:</p><ul><li><b>block</b> with a ready Unit that has BLOCKER;</li><li><b>Call</b> one of your Legends;</li><li>play a card that has <b>QUICK</b> (those can be played during the rival's turn).</li></ul><p>Or simply <b>let it through</b>.</p>",
        fr: "<p>Quand ton adversaire t'attaque, le jeu <b>fait une pause</b> et tu peux <b>réagir</b>. Tu peux :</p><ul><li><b>bloquer</b> avec une Unit prête qui a BLOCKER ;</li><li><b>appeler</b> une de tes Légendes ;</li><li>jouer une carte qui a <b>QUICK</b> (celles-là se jouent pendant le tour adverse).</li></ul><p>Ou simplement <b>laisser passer</b> (Let it through).</p>"
      }
    },
    steal: {
      icon: "⇄", t: { en: "Stealing Gigs", fr: "Voler des Gigs" },
      art: function () {
        var r = lang === "fr" ? [["Puissance 0", "0"], ["1 à 9", "1 Gig"], ["10 à 19", "2 Gigs"], ["20 à 29", "3 Gigs"]] : [["Power 0", "0"], ["1 to 9", "1 Gig"], ["10 to 19", "2 Gigs"], ["20 to 29", "3 Gigs"]];
        return '<table class="tu-table">' + r.map(function (x) { return "<tr><td>" + x[0] + "</td><td>&rarr;</td><td><b>" + x[1] + "</b></td></tr>"; }).join("") + "</table>";
      },
      b: {
        en: "<p>When an attack on Gigs is <b>not blocked</b>, the attacker steals Gigs. How many depends on its <b>power</b>: <b>1 Gig for every 10 power, starting at 1</b> (see the table).</p><p><b>The attacker chooses</b> which Gigs to take, and a stolen Gig <b>keeps its number</b>. It now counts for the thief.</p>",
        fr: "<p>Quand une attaque sur les Gigs <b>n'est pas bloquée</b>, l'attaquant vole des Gigs. Combien ? Ça dépend de sa <b>puissance</b> : <b>1 Gig par tranche de 10, à partir de 1</b> (voir le tableau).</p><p><b>C'est l'attaquant qui choisit</b> les Gigs qu'il prend, et un Gig volé <b>garde son chiffre</b>. Il compte maintenant pour le voleur.</p>"
      },
      ex: { en: "Psycho Squad has 6 power: between 1 and 9, so it steals 1 Gig.", fr: "Psycho Squad a 6 de puissance : entre 1 et 9, donc elle vole 1 Gig." }
    },
    more: {
      icon: "+", t: { en: "The other cards", fr: "Les autres cartes" },
      art: function () { return '<div class="tu-row">' + cardPic("mantis_blades") + cardPic("floor_it") + cardPic("corporate_surveillance") + "</div>"; },
      b: {
        en: "<ul><li><b>GEAR</b> (equipment): you equip it on one of your Units or face-up Legends. It gives power (Mantis Blades: +2).</li><li><b>PROGRAM</b>: you pay it, its effect happens once, then it goes to the trash.</li><li><b>QUICK</b>: a card with this word can be played during your rival's turn, as a surprise.</li></ul><p>Every card explains itself: <b>hover it</b> and read the big view on the right. Words in yellow boxes are rules (BLOCKER, LAG...).</p>",
        fr: "<ul><li><b>GEAR</b> (équipement) : tu l'équipes sur une de tes Units ou une Légende face visible. Ça donne de la puissance (Mantis Blades : +2).</li><li><b>PROGRAM</b> : tu le paies, son effet se produit une fois, puis il part à la défausse.</li><li><b>QUICK</b> : une carte avec ce mot peut se jouer pendant le tour de l'adversaire, par surprise.</li></ul><p>Chaque carte s'explique : <b>passe la souris dessus</b> et lis la grande vue à droite. Les mots dans les cadres jaunes sont des règles (BLOCKER, LAG...).</p>"
      }
    }
  };
  var GLOSSARY = ["goal", "turn", "mat", "card", "fixer", "gig", "streetcred", "ready", "eddies", "sell", "legend", "unit", "lag", "attack", "blocker", "fight", "react", "steal", "more"];

  /* ------------------------------------------------------------------------------------------------ the steps */
  // learn: concept windows that open by themselves; more: chips only. do: the clicks of a move to make.
  var STEPS = {
    language: { t: { en: "Language / Langue", fr: "Langue / Language" } },
    welcome: { learn: ["goal"],
      t: { en: "Welcome to NEON DECK!", fr: "Bienvenue au NEON DECK !" },
      b: { en: "<p>You are going to play a <b>real game</b> against the house, and I will explain <b>everything</b>, one thing at a time. Nothing can go wrong: if you click the wrong thing, I tell you.</p><p>First, the most important thing: <b>how you win</b>. Read the window, then click <b>Got it</b> and <b>Next</b>.</p>",
           fr: "<p>Tu vas jouer une <b>vraie partie</b> contre la maison, et je vais <b>tout</b> t'expliquer, une chose à la fois. Rien ne peut mal tourner : si tu cliques au mauvais endroit, je te le dis.</p><p>D'abord, le plus important : <b>comment on gagne</b>. Lis la fenêtre, puis clique sur <b>J'ai compris</b> et <b>Suivant</b>.</p>" } },
    table: { learn: ["mat"],
      t: { en: "The table in front of you", fr: "La table devant toi" },
      b: { en: "<p>Look at the table in front of you: <b>yellow names float above your mat</b>. Each one is an area where a kind of card goes.</p><p>The house sits <b>opposite</b>, with the same mat. Its cards are the ones at the top of your screen.</p>",
           fr: "<p>Regarde la table devant toi : <b>des noms jaunes flottent au-dessus de ton tapis</b>. Chacun est une zone où va une sorte de carte.</p><p>La maison est assise <b>en face</b>, avec le même tapis. Ses cartes sont celles en haut de ton écran.</p>" } },
    legends: { learn: ["legend"],
      t: { en: "Your 3 Legends", fr: "Tes 3 Légendes" },
      b: { en: "<p>The <b>3 cards that glow</b> in your panel (bottom left, with your name) are your <b>Legends</b>, face down. They are your money, and special characters you can reveal.</p>",
           fr: "<p>Les <b>3 cartes qui brillent</b> dans ton panneau (en bas à gauche, avec ton nom) sont tes <b>Légendes</b>, face cachée. C'est ton argent, et des personnages spéciaux que tu peux révéler.</p>" } },
    hand: { learn: ["card"],
      t: { en: "Your hand", fr: "Ta main" },
      b: { en: "<p>At the bottom of the screen: your <b>hand</b>, 6 cards only you can see. <b>Move the mouse over a card</b>: it shows big on the right.</p><p>Try it now on 2 or 3 cards, then read the window to know what the numbers mean.</p>",
           fr: "<p>En bas de l'écran : ta <b>main</b>, 6 cartes que toi seul vois. <b>Passe la souris sur une carte</b> : elle s'affiche en grand à droite.</p><p>Essaie maintenant sur 2 ou 3 cartes, puis lis la fenêtre pour savoir ce que veulent dire les chiffres.</p>" } },
    d20: { learn: ["turn"],
      t: { en: "Who starts?", fr: "Qui commence ?" },
      b: { en: "<p>Before the game, each player rolled a d20: the house made <b>17</b>, you made <b>9</b>. The house won and <b>plays first</b>.</p><p>To be fair, whoever plays first starts with <b>2 of their Legends already spent</b>: less money on the first turn.</p>",
           fr: "<p>Avant la partie, chaque joueur a lancé un d20 : la maison a fait <b>17</b>, toi <b>9</b>. La maison a gagné et <b>joue en premier</b>.</p><p>Pour que ce soit juste, celui qui commence a déjà <b>2 de ses Légendes dépensées</b> : moins d'argent au premier tour.</p>" } },
    house1: { more: ["gig", "sell", "blocker"],
      t: { en: "Watch the house play", fr: "Regarde la maison jouer" },
      b: { en: "<p>Just watch, the house does a full turn:</p><ol><li>it <b>rolls a die</b>: its first Gig;</li><li>it <b>sells</b> Kiroshi Optics: +1 €$ per turn;</li><li>it <b>plays Corpo Security</b> (2 €$), a Unit with <b>BLOCKER</b>;</li><li>it ends its turn.</li></ol><p>Don't worry about the words: we will see each of them on your turn.</p>",
           fr: "<p>Regarde simplement, la maison joue un tour complet :</p><ol><li>elle <b>lance un dé</b> : son premier Gig ;</li><li>elle <b>vend</b> Kiroshi Optics : +1 €$ par tour ;</li><li>elle <b>joue Corpo Security</b> (2 €$), une Unit avec <b>BLOCKER</b> ;</li><li>elle finit son tour.</li></ol><p>Ne t'inquiète pas pour les mots : on va voir chacun d'eux pendant ton tour.</p>" } },
    draw: { learn: ["ready"],
      t: { en: "Your turn! You drew a card", fr: "À toi ! Tu as pioché une carte" },
      b: { en: "<p>Your turn starts like every turn: your cards <b>stand up</b> (they are ready) and you <b>draw 1 card</b>. Look at your hand: <b>Field Operator</b> just arrived on the right.</p>",
           fr: "<p>Ton tour commence comme tous les tours : tes cartes <b>se redressent</b> (elles sont prêtes) et tu <b>pioches 1 carte</b>. Regarde ta main : <b>Field Operator</b> vient d'arriver à droite.</p>" } },
    roll: { learn: ["fixer"],
      t: { en: "Throw your first die", fr: "Lance ton premier dé" },
      b: { en: "<p>Every turn you throw <b>one die</b> from your fixer. Your dice are shown in the panel on the right.</p>",
           fr: "<p>À chaque tour tu lances <b>un dé</b> de ton fixer. Tes dés sont affichés dans le panneau de droite.</p>" },
      do: { en: ["Look at the panel on the <b>right</b> of the screen: it shows your dice.", "Click <b>any die</b> (not the d20: it is locked, it comes last).", "Watch it land in your <b>GIGS</b> area."],
            fr: ["Regarde le panneau à <b>droite</b> de l'écran : il montre tes dés.", "Clique sur <b>n'importe quel dé</b> (pas le d20 : il est verrouillé, il vient en dernier).", "Regarde-le arriver dans ta zone <b>GIGS</b>."] } },
    gigs: { learn: ["gig", "streetcred"],
      t: { en: "Your first Gig!", fr: "Ton premier Gig !" },
      b: { en: "<p>Your die is now a <b>Gig</b> (it glows on the board). <b>1 out of 7</b>. Its number also counts in your <b>Street Cred</b>.</p>",
           fr: "<p>Ton dé est maintenant un <b>Gig</b> (il brille sur le plateau). <b>1 sur 7</b>. Son chiffre compte aussi dans ta <b>Street Cred</b>.</p>" } },
    sell: { learn: ["sell"],
      t: { en: "Sell a card to earn money", fr: "Vends une carte pour gagner de l'argent" },
      b: { en: "<p>Money is what lets you play cards. Mantis Blades has the little <b>€$</b>: you can sell it.</p>",
           fr: "<p>L'argent permet de jouer des cartes. Mantis Blades a le petit <b>€$</b> : tu peux la vendre.</p>" },
      do: { en: ["In your hand (bottom), click <b>Mantis Blades</b>: the card that glows.", "In the little menu, click <b>Sell for 1 €$</b>."],
            fr: ["Dans ta main (en bas), clique sur <b>Mantis Blades</b> : la carte qui brille.", "Dans le petit menu, clique sur <b>Sell for 1 €$</b> (vendre)."] } },
    money: { learn: ["eddies"],
      t: { en: "Count your money", fr: "Compte ton argent" },
      b: { en: "<p>You now have <b>4 €$</b>: your 3 Legends + the card you just sold. Your money is shown in your panel (it glows).</p><p>You can spend it on cards this turn.</p>",
           fr: "<p>Tu as maintenant <b>4 €$</b> : tes 3 Légendes + la carte que tu viens de vendre. Ton argent est affiché dans ton panneau (il brille).</p><p>Tu peux le dépenser en cartes ce tour-ci.</p>" } },
    play: { learn: ["unit"],
      t: { en: "Play your first Unit", fr: "Joue ta première Unit" },
      b: { en: "<p>Let's get a fighter on the table. <b>Emergency Atlus</b> costs 3 €$: you have 4.</p>",
           fr: "<p>Mettons un combattant sur la table. <b>Emergency Atlus</b> coûte 3 €$ : tu en as 4.</p>" },
      do: { en: ["In your hand, click <b>Emergency Atlus</b> (it glows).", "Click <b>Play &middot; 3 €$</b>.", "Look: it appears on your side of the board, and 3 of your money cards turn sideways."],
            fr: ["Dans ta main, clique sur <b>Emergency Atlus</b> (elle brille).", "Clique sur <b>Play &middot; 3 €$</b> (jouer).", "Regarde : elle apparaît de ton côté du plateau, et 3 de tes cartes d'argent se tournent."] } },
    lag: { learn: ["lag"],
      t: { en: "Why can't it attack?", fr: "Pourquoi elle ne peut pas attaquer ?" },
      b: { en: "<p>Emergency Atlus is on your field, but it just arrived: it has <b>Lag</b>. It will be able to attack <b>next turn</b>.</p>",
           fr: "<p>Emergency Atlus est sur ton terrain, mais elle vient d'arriver : elle a du <b>Lag</b>. Elle pourra attaquer <b>au prochain tour</b>.</p>" } },
    call: { more: ["legend"],
      t: { en: "Call a Legend", fr: "Appelle une Légende" },
      b: { en: "<p>You have <b>1 €$ left</b>: just enough to <b>Call</b> a Legend and see who is hiding there.</p>",
           fr: "<p>Il te reste <b>1 €$</b> : juste assez pour <b>appeler</b> une Légende et voir qui se cache là.</p>" },
      do: { en: ["In your panel (bottom left, with your name), click one of your <b>face-down Legends</b> (they glow).", "Click <b>Call &middot; 1 €$</b>.", "It flips face up: read what it does."],
            fr: ["Dans ton panneau (en bas à gauche, avec ton nom), clique sur une de tes <b>Légendes face cachée</b> (elles brillent).", "Clique sur <b>Call &middot; 1 €$</b> (appeler).", "Elle se retourne : lis ce qu'elle fait."] } },
    choice: {
      t: { en: "The card asks you something", fr: "La carte te pose une question" },
      b: { en: "<p>Its <b>CALL</b> effect needs a choice: the <b>panel on the right</b> shows the options. Click one, then confirm.</p><p>Every time a card needs a decision, it asks you <b>there</b>.</p>",
           fr: "<p>Son effet <b>CALL</b> demande un choix : le <b>panneau de droite</b> montre les options. Clique sur une, puis valide.</p><p>À chaque fois qu'une carte a besoin d'une décision, elle te la demande <b>là</b>.</p>" } },
    end1: { more: ["turn"],
      t: { en: "End your turn", fr: "Termine ton tour" },
      b: { en: "<p>All your money is spent: there is nothing more to do this turn.</p>",
           fr: "<p>Tout ton argent est dépensé : il n'y a plus rien à faire ce tour-ci.</p>" },
      do: { en: ["Click the yellow <b>End turn</b> button in the panel on the right."], fr: ["Clique sur le bouton jaune <b>End turn</b> (fin du tour) dans le panneau de droite."] } },
    house2: { more: ["unit"],
      t: { en: "The house plays again", fr: "La maison rejoue" },
      b: { en: "<p>Watch: the house rolls a second Gig and plays <b>Psycho Squad</b>, a big Unit with <b>6 power</b>.</p><p>It has Lag this turn. But next turn, it can attack you...</p>",
           fr: "<p>Regarde : la maison lance un deuxième Gig et joue <b>Psycho Squad</b>, une grosse Unit avec <b>6 de puissance</b>.</p><p>Elle a du Lag ce tour-ci. Mais au prochain tour, elle pourra t'attaquer...</p>" } },
    roll2: {
      t: { en: "Your turn: throw a die", fr: "Ton tour : lance un dé" },
      b: { en: "<p>Same as before: every turn starts with a die.</p>", fr: "<p>Comme tout à l'heure : chaque tour commence par un dé.</p>" },
      do: { en: ["In the panel on the right, click <b>any die</b> except the d20."], fr: ["Dans le panneau de droite, clique sur <b>n'importe quel dé</b> sauf le d20."] } },
    attack: { learn: ["attack"],
      t: { en: "Your first attack", fr: "Ta première attaque" },
      b: { en: "<p>Emergency Atlus has <b>no Lag any more</b>: it can attack! Let's try to steal a Gig from the house.</p>",
           fr: "<p>Emergency Atlus n'a <b>plus de Lag</b> : elle peut attaquer ! Essayons de voler un Gig à la maison.</p>" },
      do: { en: ["Click <b>Emergency Atlus</b> in <b>your</b> Units (on the left of the screen, just above your panel; it glows).", "Then click the <b>house's Gigs</b> (its dice, top left, they glow too)."],
            fr: ["Clique sur <b>Emergency Atlus</b> dans <b>tes</b> Units (à gauche de l'écran, juste au-dessus de ton panneau ; elle brille).", "Puis clique sur les <b>Gigs de la maison</b> (ses dés, en haut à gauche, ils brillent aussi)."] } },
    block: { learn: ["blocker"],
      t: { en: "Blocked!", fr: "Bloquée !" },
      b: { en: "<p>The house <b>reacts</b>: Corpo Security has <b>BLOCKER</b>, it jumps in front of your attack. Now it is a <b>fight</b> between the two Units. Watch.</p>",
           fr: "<p>La maison <b>réagit</b> : Corpo Security a <b>BLOCKER</b>, elle se met devant ton attaque. C'est maintenant un <b>combat</b> entre les deux Units. Regarde.</p>" } },
    fight: { learn: ["fight"],
      t: { en: "You won the fight", fr: "Tu as gagné le combat" },
      b: { en: "<p><b>4 against 2</b>: Emergency Atlus is stronger, Corpo Security is <b>defeated</b> (it went to the trash). The story of the fight is written in the log (it glows).</p><p>But the attack was blocked, so <b>no Gig was stolen</b> this time. Now the house has no Blocker left!</p>",
           fr: "<p><b>4 contre 2</b> : Emergency Atlus est plus forte, Corpo Security est <b>détruite</b> (elle est partie à la défausse). L'histoire du combat est écrite dans le journal (il brille).</p><p>Mais l'attaque a été bloquée, donc <b>aucun Gig volé</b> cette fois. Maintenant la maison n'a plus de Blocker !</p>" } },
    end2: {
      t: { en: "End your turn", fr: "Termine ton tour" },
      b: { en: "<p>Your Unit attacked, it is spent. Nothing else to do.</p>", fr: "<p>Ton Unit a attaqué, elle est dépensée. Plus rien à faire.</p>" },
      do: { en: ["Click <b>End turn</b> on the right."], fr: ["Clique sur <b>End turn</b> à droite."] } },
    house3: { more: ["attack"],
      t: { en: "The house attacks you!", fr: "La maison t'attaque !" },
      b: { en: "<p>The house rolls a die, then <b>Psycho Squad (6 power) attacks your Gigs</b>.</p>",
           fr: "<p>La maison lance un dé, puis <b>Psycho Squad (6 de puissance) attaque tes Gigs</b>.</p>" } },
    react: { learn: ["react"],
      t: { en: "You may react", fr: "Tu peux réagir" },
      b: { en: "<p>You are attacked: the game waits for you. You have <b>no Blocker</b> and no money left, so this time there is nothing to do.</p>",
           fr: "<p>On t'attaque : le jeu t'attend. Tu n'as <b>pas de Blocker</b> et plus d'argent, donc cette fois il n'y a rien à faire.</p>" },
      do: { en: ["Click <b>Let it through</b> in the panel on the right."], fr: ["Clique sur <b>Let it through</b> (laisser passer) dans le panneau de droite."] } },
    stolen: { learn: ["steal"],
      t: { en: "The house steals a Gig", fr: "La maison te vole un Gig" },
      b: { en: "<p>Psycho Squad has 6 power: it steals <b>1 Gig</b>. The house <b>chooses</b> which one, and it moves to its side. Then it ends its turn.</p><p>Don't worry: you are going to <b>take one back</b>.</p>",
           fr: "<p>Psycho Squad a 6 de puissance : elle vole <b>1 Gig</b>. La maison <b>choisit</b> lequel, et il passe de son côté. Puis elle finit son tour.</p><p>Pas de panique : tu vas <b>en reprendre un</b>.</p>" } },
    roll3: {
      t: { en: "Your turn: throw a die", fr: "Ton tour : lance un dé" },
      b: { en: "<p>You know it now: a die first.</p>", fr: "<p>Tu connais maintenant : d'abord un dé.</p>" },
      do: { en: ["Click <b>any die</b> in the panel on the right."], fr: ["Clique sur <b>n'importe quel dé</b> dans le panneau de droite."] } },
    attack2: { more: ["steal"],
      t: { en: "Take a Gig back", fr: "Reprends un Gig" },
      b: { en: "<p>The house has <b>no Blocker</b> any more. Attack its Gigs: this time nothing can stop you.</p>",
           fr: "<p>La maison n'a <b>plus de Blocker</b>. Attaque ses Gigs : cette fois rien ne peut t'arrêter.</p>" },
      do: { en: ["Click <b>Emergency Atlus</b> in your Units (on the left, just above your panel).", "Click the <b>house's Gigs</b> (top left)."],
            fr: ["Clique sur <b>Emergency Atlus</b> dans tes Units (à gauche, juste au-dessus de ton panneau).", "Clique sur les <b>Gigs de la maison</b> (en haut à gauche)."] } },
    pick: {
      t: { en: "Choose the Gig you steal", fr: "Choisis le Gig que tu voles" },
      b: { en: "<p>The attack went through: you steal <b>1 Gig</b> and <b>you choose</b> which. Take a <b>high number</b>: it raises your Street Cred.</p>",
           fr: "<p>L'attaque est passée : tu voles <b>1 Gig</b> et c'est <b>toi qui choisis</b> lequel. Prends un <b>gros chiffre</b> : ça monte ta Street Cred.</p>" },
      do: { en: ["Click one of the <b>house's Gigs</b> (top left): it gets selected.", "Click <b>Steal</b> in the panel on the right."],
            fr: ["Clique sur un des <b>Gigs de la maison</b> (en haut à gauche) : il est sélectionné.", "Clique sur <b>Steal</b> (voler) dans le panneau de droite."] } },
    done: { learn: ["more"],
      t: { en: "You know how to play!", fr: "Tu sais jouer !" },
      b: { en: "<p>Well done. Remember the loop of every turn: <b>roll a die &rarr; sell one card &rarr; play cards &rarr; attack &rarr; end turn</b>. And the goal: <b>start a turn with 7 Gigs</b>.</p><p>Click <b>Keep playing</b> to finish this game against the house on your own (the coach leaves, the <b>Glossary</b> button stays), or leave the table. To play against a friend: Duel tab of your binder, then challenge them.</p>",
           fr: "<p>Bravo. Retiens la boucle de chaque tour : <b>lancer un dé &rarr; vendre une carte &rarr; jouer des cartes &rarr; attaquer &rarr; finir le tour</b>. Et le but : <b>commencer un tour avec 7 Gigs</b>.</p><p>Clique sur <b>Continuer la partie</b> pour finir ce match contre la maison tout seul (le coach s'en va, le bouton <b>Lexique</b> reste), ou quitte la table. Pour jouer contre un ami : onglet Duel de ton binder, puis défie-le.</p>" } }
  };

  /* ------------------------------------------------------------------------------------------------ concept window */
  // The 3D zone labels (open77_uikit) are drawn above this page: put them away while a window is open.
  var labelsHidden = false;
  function hideLabels(v) {
    if (v === labelsHidden || !X) return;
    labelsHidden = v;
    X.T.emit("tcg:tutorialLabels", { hidden: v });
  }
  function openConcept(id, fromQueue) {
    var c = CONCEPTS[id];
    if (!c) return;
    hideLabels(true);
    seen[id] = true;
    var box = $("tbConcept");
    box.innerHTML = "";
    var card = el("div", "tu-win");
    var head = el("div", "tu-head", '<span class="tu-icon">' + esc(c.icon) + "</span><h2>" + L(c.t) + "</h2>");
    card.appendChild(head);
    var art = el("div", "tu-art", c.art ? c.art() : "");
    card.appendChild(art);
    card.appendChild(el("div", "tu-body", L(c.b)));
    if (c.ex) card.appendChild(el("div", "tu-ex", "<b>" + L(UI.example) + "</b> " + L(c.ex)));
    var row = el("div", "tu-actions");
    var left = queue.length;
    var ok = el("button", "primary", L(UI.gotIt) + (left ? " (" + left + ")" : ""));
    ok.onclick = function () { closeConcept(); };
    var gl = el("button", "ghost", L(UI.glossary));
    gl.onclick = function () { openGlossary(); };
    row.appendChild(gl); row.appendChild(ok);
    card.appendChild(row);
    box.appendChild(card);
    box.classList.remove("hidden");
    card.classList.add("show");
    setTimeout(function () { try { ok.focus(); } catch (e) { /* no focus */ } }, 50);
  }
  function closeConcept() {
    var box = $("tbConcept");
    if (queue.length) return openConcept(queue.shift(), true);
    box.classList.add("hidden");
    box.innerHTML = "";
    hideLabels(false);
  }
  function openGlossary() {
    queue = [];
    hideLabels(true);
    var box = $("tbConcept");
    box.innerHTML = "";
    var card = el("div", "tu-win glossary");
    card.appendChild(el("div", "tu-head", '<span class="tu-icon">?</span><h2>' + L(UI.allConcepts) + "</h2>"));
    var grid = el("div", "tu-gloss");
    GLOSSARY.forEach(function (id) {
      var c = CONCEPTS[id];
      var b = el("button", "tu-gl", '<span class="tu-icon">' + esc(c.icon) + "</span>" + L(c.t));
      b.onclick = function () { openConcept(id); };
      grid.appendChild(b);
    });
    card.appendChild(grid);
    var row = el("div", "tu-actions");
    var close = el("button", "primary", L(UI.close));
    close.onclick = function () { box.classList.add("hidden"); box.innerHTML = ""; hideLabels(false); };
    row.appendChild(close);
    card.appendChild(row);
    box.appendChild(card);
    box.classList.remove("hidden");
  }

  function setLang(v) {
    lang = v === "fr" ? "fr" : "en";
    try { localStorage.setItem(KEY, lang); } catch (e) { /* not kept */ }
    if (X) X.T.emit("tcg:tutorialLang", { lang: lang });
  }

  /* ------------------------------------------------------------------------------------------------ the coach */
  // t: the server's step (index, total, id, next, final, expect, house); returns the coach's content.
  function render(box, t, m, emit) {
    var s = STEPS[t.id] || {};
    if (t.id !== lastStep) {
      if (t.index <= 1) seen = {};
      lastStep = t.id;
      queue = (s.learn || []).filter(function (id) { return !seen[id]; });
      if (queue.length) setTimeout(function () { if (lastStep === t.id && queue.length) openConcept(queue.shift(), true); }, t.house ? 0 : 450);
    }
    box.innerHTML = "";
    var head = el("div", "tc-head", '<span class="tc-step">' + L(UI.tutorial) + " &middot; " + t.index + " / " + t.total + '</span><span class="tc-bar"><i style="width:' +
      Math.round(100 * t.index / t.total) + '%"></i></span>');
    var langs = el("span", "tc-lang");
    ["en", "fr"].forEach(function (v) {
      var b = el("button", v === lang ? "on" : "", v.toUpperCase());
      b.onclick = function () { setLang(v); box.dataset.key = ""; X.rerenderCoach(); };
      langs.appendChild(b);
    });
    head.appendChild(langs);
    box.appendChild(head);

    if (t.id === "language") {
      box.appendChild(el("h3", "", "Language &middot; Langue"));
      box.appendChild(el("p", "", L(UI.pick) + " / " + (lang === "fr" ? UI.pick.en : UI.pick.fr)));
      var pick = el("div", "tc-langpick");
      [["en", "English", "EN"], ["fr", "Français", "FR"]].forEach(function (v) {
        var b = el("button", "tc-langbtn" + (v[0] === lang ? " on" : ""), '<span class="flag">' + v[2] + "</span>" + v[1]);
        b.onclick = function () { setLang(v[0]); emit("tcg:tutorialNext", {}); };
        pick.appendChild(b);
      });
      box.appendChild(pick);
      return;
    }

    box.appendChild(el("h3", "", L(s.t) || esc(t.title)));
    box.appendChild(el("div", "tc-body", L(s.b) || "<p>" + esc(t.text) + "</p>"));
    if (t.expect && s.do) {
      var todo = el("div", "tc-do");
      todo.appendChild(el("div", "tc-do-h", L(UI.doThis)));
      var ol = el("ol");
      (s.do[lang] || s.do.en).forEach(function (x) { ol.appendChild(el("li", "", x)); });
      todo.appendChild(ol);
      box.appendChild(todo);
    }
    var chips = (s.learn || []).concat(s.more || []);
    var row = el("div", "tc-actions");
    if (chips.length) {
      var cl = el("div", "tc-chips", "<span>" + L(UI.learn) + "</span>");
      chips.forEach(function (id) {
        var c = CONCEPTS[id]; if (!c) return;
        var b = el("button", "tc-chip", '<i>' + esc(c.icon) + "</i>" + L(c.t));
        b.onclick = function () { queue = []; openConcept(id); };
        cl.appendChild(b);
      });
      box.appendChild(cl);
    }
    if (t.final) {
      var keep = el("button", "primary", L(UI.keep));
      keep.onclick = function () { emit("tcg:tutorialNext", {}); };
      var bye = el("button", "ghost", L(UI.leaveTable));
      bye.onclick = function () { emit("tcg:leaveMatch", {}); };
      row.appendChild(keep); row.appendChild(bye);
    } else if (t.next) {
      var next = el("button", "primary", L(UI.next) + " &rarr;");
      next.onclick = function () { emit("tcg:tutorialNext", {}); };
      row.appendChild(next);
    } else if (!t.expect) {
      row.appendChild(el("span", "tc-wait", t.house ? L(UI.waitHouse) : L(UI.resolving)));
    }
    var gl = el("button", "tc-gloss", "? " + L(UI.glossary));
    gl.onclick = function () { openGlossary(); };
    row.appendChild(gl);
    if (!t.final) {
      var skip = el("button", "tc-skip", L(UI.leave));
      skip.onclick = function () { emit("tcg:leaveMatch", {}); };
      row.appendChild(skip);
    }
    box.appendChild(row);
  }

  // After the tutorial ("Keep playing") or outside it: only the Glossary button, for a player who forgot a word.
  function renderFree(show) {
    var g = $("tbGlossBtn");
    if (!g) return;
    g.classList.toggle("hidden", !show);
    g.textContent = "? " + L(UI.glossary);
    g.onclick = function () { openGlossary(); };
  }

  function reset() { seen = {}; queue = []; lastStep = null; var b = $("tbConcept"); if (b) { b.classList.add("hidden"); b.innerHTML = ""; } hideLabels(false); }

  function init() {
    X = window.TCGDUEL;
    if (X) X.T.emit("tcg:tutorialLang", { lang: lang });
  }
  window.TCGTUTO = { render: render, renderFree: renderFree, reset: reset, open: openConcept, glossary: openGlossary,
    lang: function () { return lang; }, setLang: setLang, concepts: CONCEPTS, steps: STEPS };
  if (window.TCGDUEL) init(); else document.addEventListener("tcg:duelReady", init);
})();
