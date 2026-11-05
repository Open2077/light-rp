/* Cyberpunk TCG, the deck builder's guide (English / French, same language as the tutorial: web/tutorial.js).
   Nine pages, each pointing at the part of the Decks tab it explains (it glows), with a picture and an example:
   what a deck is, the deck box, the 3 Legends, colours and RAM, adding cards, counts and copies, the problem list,
   a good first deck, save and use. Opens by itself the first time the Decks tab is shown; the "Deck guide" button
   in the tab opens it again. The panel sits on the side away from what it points at. */
(function () {
  "use strict";
  var $ = function (id) { return document.getElementById(id); };
  var SEEN = "op77_tcg_deckguide_seen";
  var page = 0, open = false;

  function lang() { return window.TCGTUTO ? window.TCGTUTO.lang() : "en"; }
  function L(o) { return o ? (o[lang()] || o.en) : ""; }
  function el(tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  function img(slug) { return window.TCGDUEL && window.TCGDUEL.cardImg ? window.TCGDUEL.cardImg(slug) : "img/backside.webp"; }
  function card(slug, cls) { return '<img class="tu-card ' + (cls || "") + '" alt="" src="' + img(slug) + '">'; }
  function back(cls) { return '<img class="tu-card ' + (cls || "") + '" alt="" src="img/backside.webp">'; }
  function fr() { return lang() === "fr"; }

  var COLOURS = { Red: "#ff3d4a", Green: "#3fd28c", Blue: "#2fa4ff", Yellow: "#fcee09" };
  function ramBars(values) {
    var names = fr() ? { Red: "Rouge", Green: "Vert", Blue: "Bleu", Yellow: "Jaune" } : { Red: "Red", Green: "Green", Blue: "Blue", Yellow: "Yellow" };
    return '<div class="dg-ram">' + Object.keys(COLOURS).map(function (c) {
      var v = values[c] || 0, cells = "";
      for (var i = 0; i < 6; i++) cells += '<i class="' + (i < v ? "on" : "") + '"></i>';
      return '<div style="--c:' + COLOURS[c] + '"><span>' + names[c] + "</span><b>" + v + "</b><em>" + cells + "</em></div>";
    }).join("") + "</div>";
  }

  var PAGES = [
    { target: null,
      t: { en: "What is a deck?", fr: "C'est quoi un deck ?" },
      art: function () {
        return '<div class="tu-row">' + card("dexter_deshawn_off_the_grid", "small") + card("saburo_arasaka_stubborn_patriarch", "small") + card("muamar_reyes_el_capitan", "small") +
          '<b class="tu-op">+</b><div class="dg-stack">' + back("small") + back("small") + back("small") + "<b>40-50</b></div></div>" +
          '<div class="tu-cap">' + (fr() ? "3 Légendes + une pioche de 40 à 50 cartes" : "3 Legends + a deck of 40 to 50 cards") + "</div>";
      },
      b: { en: "<p>A deck is what you bring to a duel. It always has <b>2 parts</b>:</p><ul><li><b>3 Legends</b>: they sit face down next to you and give you money and colours;</li><li>a <b>deck of 40 to 50 cards</b> (Units, Gear, Programs) that you draw from.</li></ul><p>This guide walks through the screen, one part at a time. Each page makes the part it talks about <b>glow</b>.</p>",
           fr: "<p>Un deck, c'est ce que tu apportes en duel. Il a toujours <b>2 parties</b> :</p><ul><li><b>3 Légendes</b> : posées face cachée à côté de toi, elles te donnent de l'argent et des couleurs ;</li><li>une <b>pioche de 40 à 50 cartes</b> (Units, Gear, Programs) dans laquelle tu pioches.</li></ul><p>Ce guide te fait visiter l'écran, une partie à la fois. Chaque page fait <b>briller</b> la partie dont elle parle.</p>" } },
    { target: ".dk-list",
      t: { en: "Your deck box", fr: "Ta boîte à decks" },
      b: { en: "<p>On the left: your <b>decks</b> (up to 12). Click one to edit it, or <b>New deck</b> to start from nothing.</p><p>Below, <b>Lent by the shop</b>: ready-made <b>starter decks</b>. You can duel with them right away, even with no cards of your own, or <b>copy one</b> and change it. That is the easiest way to start.</p>",
           fr: "<p>À gauche : tes <b>decks</b> (jusqu'à 12). Clique sur un deck pour le modifier, ou sur <b>New deck</b> pour partir de zéro.</p><p>En dessous, <b>Lent by the shop</b> : des <b>decks de départ</b> tout prêts. Tu peux jouer avec tout de suite, même sans aucune carte à toi, ou en <b>copier un</b> et le modifier. C'est le plus simple pour commencer.</p>" } },
    { target: "#dkLegends",
      t: { en: "Step 1: pick 3 Legends", fr: "Étape 1 : choisis 3 Légendes" },
      art: function () { return '<div class="tu-row">' + card("dexter_deshawn_off_the_grid") + card("muamar_reyes_el_capitan") + card("wakako_okada_peace_and_harmony") + "</div>"; },
      b: { en: "<p>The 3 slots at the top are for your <b>Legends</b>. Click a Legend in the card list to put it in a slot; click a slot to take it out.</p><ul><li>exactly <b>3</b>, all with <b>different names</b>;</li><li>you must <b>own</b> them;</li><li>choose them <b>first</b>: their colours decide which cards you can play (next page).</li></ul>",
           fr: "<p>Les 3 cases en haut sont pour tes <b>Légendes</b>. Clique sur une Légende dans la liste de cartes pour la mettre dans une case ; clique sur une case pour la retirer.</p><ul><li>exactement <b>3</b>, avec des <b>noms différents</b> ;</li><li>tu dois les <b>posséder</b> ;</li><li>choisis-les <b>en premier</b> : leurs couleurs décident des cartes que tu peux jouer (page suivante).</li></ul>" } },
    { target: "#dkRam",
      t: { en: "Step 2: colours and RAM", fr: "Étape 2 : couleurs et RAM" },
      art: function () {
        return '<div class="tu-row"><div class="tu-anat">' + card("dexter_deshawn_off_the_grid", "mid") + '<i class="tu-ring" style="left:88.5%;top:11%"></i></div>' +
          ramBars({ Red: 3, Blue: 1 }) + "</div>";
      },
      b: { en: "<p>Every card has a <b>colour</b> (Red, Green, Blue, Yellow) and a <b>RAM</b> number: the little box at the <b>top right</b> of the card.</p><ul><li>A <b>Legend's RAM</b> is what it <b>gives</b> you in its colour. Your RAM in a colour = the RAM of all your Legends of that colour added up.</li><li>A <b>card's RAM</b> is what it <b>needs</b>: you can only put a card in the deck if its RAM is <b>at most your RAM in its colour</b>.</li></ul><p>The bars (they glow) show your RAM per colour.</p>",
           fr: "<p>Chaque carte a une <b>couleur</b> (Rouge, Vert, Bleu, Jaune) et un nombre de <b>RAM</b> : la petite case en <b>haut à droite</b> de la carte.</p><ul><li>La <b>RAM d'une Légende</b>, c'est ce qu'elle te <b>donne</b> dans sa couleur. Ta RAM dans une couleur = la RAM de toutes tes Légendes de cette couleur additionnées.</li><li>La <b>RAM d'une carte</b>, c'est ce qu'elle <b>demande</b> : tu ne peux la mettre dans le deck que si sa RAM est <b>au plus ta RAM dans sa couleur</b>.</li></ul><p>Les barres (elles brillent) montrent ta RAM par couleur.</p>" },
      ex: { en: "Legends: Dexter (Red, RAM 2) + another Red with RAM 1 + a Blue with RAM 1. You have Red 3, Blue 1. You can play Red cards up to RAM 3 and Blue cards with RAM 1, but no Green or Yellow card.",
            fr: "Légendes : Dexter (Rouge, RAM 2) + une autre Rouge avec RAM 1 + une Bleue avec RAM 1. Tu as Rouge 3, Bleu 1. Tu peux jouer des cartes Rouges jusqu'à RAM 3 et des Bleues à RAM 1, mais aucune carte Verte ni Jaune." } },
    { target: ".dk-pool",
      t: { en: "Step 3: add cards", fr: "Étape 3 : ajoute des cartes" },
      b: { en: "<p>The big grid is <b>your collection</b>. <b>Click a card</b> to add one copy to the deck.</p><ul><li>the chips filter by <b>type</b> (Unit, Gear...) and <b>colour</b>; the search box finds a name, a tag or a word of its text;</li><li><b>Owned only</b>: you build with the copies you own (any finish counts). Untick it to see what exists;</li><li>a card your RAM can't pay for shows it at once.</li></ul>",
           fr: "<p>La grande grille, c'est <b>ta collection</b>. <b>Clique sur une carte</b> pour en ajouter un exemplaire au deck.</p><ul><li>les pastilles filtrent par <b>type</b> (Unit, Gear...) et par <b>couleur</b> ; la recherche trouve un nom, un tag ou un mot du texte ;</li><li><b>Owned only</b> : tu construis avec les exemplaires que tu possèdes (toutes finitions confondues). Décoche pour voir ce qui existe ;</li><li>une carte que ta RAM ne peut pas payer le montre tout de suite.</li></ul>" } },
    { target: ".dk-count",
      t: { en: "Step 4: the count and the copies", fr: "Étape 4 : le compte et les exemplaires" },
      art: function () { return '<div class="tu-row"><div class="dg-count"><b>40</b><span>min</span></div><div class="dg-count ok"><b>45</b><span>' + (fr() ? "idéal" : "sweet spot") + '</span></div><div class="dg-count"><b>50</b><span>max</span></div><b class="tu-op">&middot;</b><div class="dg-copies">' + card("emergency_atlus", "small") + card("emergency_atlus", "small") + card("emergency_atlus", "small") + "<b>3 max</b></div></div>"; },
      b: { en: "<p>The counter (it glows) shows how many cards are in your deck: you need <b>40 to 50</b> (Legends don't count).</p><p>At most <b>3 copies</b> of the same card. The list on the right is your deck: <b>click a card there to take one copy out</b>.</p>",
           fr: "<p>Le compteur (il brille) montre combien de cartes sont dans ton deck : il en faut <b>40 à 50</b> (les Légendes ne comptent pas).</p><p>Au maximum <b>3 exemplaires</b> de la même carte. La liste de droite, c'est ton deck : <b>clique sur une carte pour en retirer un exemplaire</b>.</p>" } },
    { target: "#dkErrors",
      t: { en: "The list of problems", fr: "La liste des problèmes" },
      b: { en: "<p>Under the counter, a <b>red list</b> says exactly what is still wrong (\"Pick 3 Legends\", \"36 cards: at least 40\", \"X needs 3 Red RAM; your Legends give 2\"...). Fix them one by one until it is empty.</p><p>You can <b>save an unfinished deck</b> anytime (a draft). Only a deck with <b>no problem left</b> can be used in a duel.</p>",
           fr: "<p>Sous le compteur, une <b>liste rouge</b> dit exactement ce qui ne va pas encore (« Pick 3 Legends », « 36 cards: at least 40 », « X needs 3 Red RAM; your Legends give 2 »...). Corrige-les un par un jusqu'à ce qu'elle soit vide.</p><p>Tu peux <b>sauvegarder un deck pas fini</b> quand tu veux (un brouillon). Seul un deck <b>sans aucun problème</b> peut servir en duel.</p>" } },
    { target: null,
      t: { en: "A good first deck", fr: "Un bon premier deck" },
      art: function () {
        var h = [6, 9, 8, 5, 3], labels = ["1", "2", "3", "4", "5+"];
        return '<div class="dg-curve">' + h.map(function (v, i) { return '<div><i style="height:' + (v * 9) + 'px"></i><span>' + labels[i] + "</span></div>"; }).join("") + "</div>" +
          '<div class="tu-cap">' + (fr() ? "beaucoup de cartes pas chères, peu de chères (coût en €$)" : "many cheap cards, few expensive ones (cost in €$)") + "</div>";
      },
      b: { en: "<ul><li><b>1 or 2 colours</b>: your RAM goes further.</li><li><b>Lots of cheap Units</b> (cost 1 to 3): you can play them early and attack sooner.</li><li>A few <b>BLOCKERS</b> to protect your Gigs, and a few strong Units to steal.</li><li>Cards with a <b>Sell Tag (€$)</b> are also money: sell the ones you can't use yet.</li><li><b>45 cards</b> is a good size. Not sure? Copy a starter deck and swap a few cards.</li></ul>",
           fr: "<ul><li><b>1 ou 2 couleurs</b> : ta RAM va plus loin.</li><li><b>Beaucoup d'Units pas chères</b> (coût 1 à 3) : tu les poses tôt et tu attaques plus vite.</li><li>Quelques <b>BLOCKERS</b> pour protéger tes Gigs, et quelques Units fortes pour voler.</li><li>Les cartes avec un <b>Sell Tag (€$)</b> sont aussi de l'argent : vends celles que tu ne peux pas encore jouer.</li><li><b>45 cartes</b>, c'est une bonne taille. Pas sûr ? Copie un deck de départ et change quelques cartes.</li></ul>" } },
    { target: ".dk-head",
      t: { en: "Step 5: save and use it", fr: "Étape 5 : sauvegarde et utilise-le" },
      b: { en: "<ol><li>Give your deck a <b>name</b> (the box at the top).</li><li>Click <b>Save</b>.</li><li>Click <b>Use for duels</b>: this is the deck you will bring to the table.</li></ol><p>Then the <b>Duel</b> tab: challenge a player near you, or play the <b>tutorial</b> against the house to practise. Good luck, choom!</p>",
           fr: "<ol><li>Donne un <b>nom</b> à ton deck (la case en haut).</li><li>Clique sur <b>Save</b> (sauvegarder).</li><li>Clique sur <b>Use for duels</b> (utiliser en duel) : c'est le deck que tu apporteras à la table.</li></ol><p>Ensuite, l'onglet <b>Duel</b> : défie un joueur près de toi, ou joue le <b>tutoriel</b> contre la maison pour t'entraîner. Bonne chance, choom !</p>" } }
  ];

  function clearFocus() { Array.prototype.forEach.call(document.querySelectorAll(".dg-focus"), function (n) { n.classList.remove("dg-focus"); }); }

  function render() {
    var box = $("deckGuide");
    if (!box) { box = el("div", "dg-panel hidden"); box.id = "deckGuide"; document.getElementById("app").appendChild(box); }
    clearFocus();
    if (!open) { box.classList.add("hidden"); return; }
    var p = PAGES[page], target = p.target ? document.querySelector(p.target) : null;
    if (target) target.classList.add("dg-focus");
    // The panel on the side away from what it points at.
    var left = false;
    if (target) { var r = target.getBoundingClientRect(); left = r.left + r.width / 2 > window.innerWidth / 2; }
    box.classList.toggle("left", left);
    box.innerHTML = "";
    var head = el("div", "tc-head", '<span class="tc-step">' + (fr() ? "GUIDE DU DECK" : "DECK GUIDE") + " &middot; " + (page + 1) + " / " + PAGES.length +
      '</span><span class="tc-bar"><i style="width:' + Math.round(100 * (page + 1) / PAGES.length) + '%"></i></span>');
    var langs = el("span", "tc-lang");
    ["en", "fr"].forEach(function (v) {
      var b = el("button", v === lang() ? "on" : "", v.toUpperCase());
      b.onclick = function () { if (window.TCGTUTO && window.TCGTUTO.setLang) window.TCGTUTO.setLang(v); render(); };
      langs.appendChild(b);
    });
    head.appendChild(langs);
    box.appendChild(head);
    box.appendChild(el("h3", "", L(p.t)));
    if (p.art) box.appendChild(el("div", "tu-art", p.art()));
    box.appendChild(el("div", "tu-body", L(p.b)));
    if (p.ex) box.appendChild(el("div", "tu-ex", "<b>" + (fr() ? "Exemple" : "Example") + "</b> " + L(p.ex)));
    var row = el("div", "tu-actions");
    var close = el("button", "tc-skip", fr() ? "Fermer le guide" : "Close the guide");
    close.onclick = function () { hide(); };
    row.appendChild(close);
    if (page > 0) { var prev = el("button", "ghost", "&larr; " + (fr() ? "Précédent" : "Back")); prev.onclick = function () { page--; render(); }; row.appendChild(prev); }
    var last = page === PAGES.length - 1;
    var next = el("button", "primary", last ? (fr() ? "C'est parti !" : "Let's build!") : (fr() ? "Suivant" : "Next") + " &rarr;");
    next.onclick = function () { if (last) hide(); else { page++; render(); } };
    row.appendChild(next);
    box.appendChild(row);
    box.classList.remove("hidden");
    box.classList.remove("show"); void box.offsetWidth; box.classList.add("show");
  }
  function show(at) { open = true; page = at || 0; try { localStorage.setItem(SEEN, "1"); } catch (e) { /* not kept */ } render(); }
  function hide() { open = false; render(); }
  function firstTime() { try { return localStorage.getItem(SEEN) !== "1"; } catch (e) { return false; } }

  window.TCGDECKGUIDE = { show: show, hide: hide, isOpen: function () { return open; }, firstTime: firstTime, pages: PAGES };
  document.addEventListener("keydown", function (e) {
    if (!open) return;
    if (e.key === "Escape") { hide(); e.stopPropagation(); e.preventDefault(); }
    else if (e.key === "ArrowRight" && page < PAGES.length - 1) { page++; render(); }
    else if (e.key === "ArrowLeft" && page > 0) { page--; render(); }
  }, true);
  window.addEventListener("resize", function () { if (open) render(); });
})();
