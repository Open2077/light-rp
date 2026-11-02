(function() {
  "use strict";
  /* The fitting room page. State lives in WardrobeModel (model.js): a baseline
     (the last committed look) and a draft. Every edit is previewed on the
     character at once (wardrobe:preview) and only a save commits it.

     Events to Lua: wardrobe:ready, :preview, :save, :close, :favorite, :orbit
     {degrees}, :focus {zone}, :zoom {delta}, :appearance {mode}, :activity,
     :takeAway {mode, name, pieces, look}. From Lua: wardrobe:open, :favorites,
     :catalogue, :closed, :status, :previewResult, :saveFailed, :committed,
     :takeAwayResult, :probe. */
  const M=WardrobeModel, $=id=>document.getElementById(id), emit=(name,value={})=>Open77.emit(name,value);
  const BATCH=60;
  // Page errors reach the client log (the game's browser has no console to read).
  window.addEventListener("error",e=>{try{emit("wardrobe:pageError",{message:String(e.message || e.error || "error").slice(0,300),line:e.lineno || 0});}catch(_){}});
  window.addEventListener("unhandledrejection",e=>{try{emit("wardrobe:pageError",{message:String(e.reason && (e.reason.stack || e.reason.message) || e.reason).slice(0,300),line:0});}catch(_){}});
  let baseline, draft, confirmed, initialLook, catalogue=[], lookup={}, mode="equipment", outfit=0, slot="Head", yaw=180;
  let busy=false, previewPending=false, trying=null, pendingConfirm=null, favoritesOnly=false, favoritesReady=false, favorites=new Set();
  let shown=0, entries=[], zone="full", takeAway=false, takeMode="pieces", takeLook=null;

  // Each category: its rail icon and the camera framing that shows it best.
  const ZONES={Head:"head",Face:"head",InnerChest:"torso",OuterChest:"torso",Legs:"legs",Feet:"feet",Outfit:"full"};
  const ZONE_LABELS={full:"FULL LOOK",head:"HEAD",torso:"TORSO",legs:"LEGS",feet:"FEET"};
  const ICONS={
    Head:'<path d="M4 15h16"/><path d="M6 15a6 6 0 0 1 12 0"/><path d="M12 9V7"/><path d="M3 15c0 2 2 3 9 3s9-1 9-3"/>',
    Face:'<circle cx="7" cy="13" r="3.5"/><circle cx="17" cy="13" r="3.5"/><path d="M10.5 13h3"/><path d="M3.5 12 5 8"/><path d="M20.5 12 19 8"/>',
    InnerChest:'<path d="M8 3 4 6l2 4 2-1v12h8V9l2 1 2-4-4-3c0 2-2 3-4 3s-4-1-4-3Z"/>',
    OuterChest:'<path d="M8 3 3 7l2 5 2-1v10h10V11l2 1 2-5-5-4"/><path d="M8 3l4 6 4-6"/><path d="M12 9v12"/>',
    Legs:'<path d="M7 3h10l1 18h-4l-2-11-2 11H6Z"/><path d="M7 7h10"/>',
    Feet:'<path d="M4 16V8h5v4l9 2c2 .5 3 1.5 3 3v1H4Z"/><path d="M4 18h17"/>',
    Outfit:'<path d="M9 3h6l1 4-2 2v4h3l1 8H6l1-8h3V9L8 7Z"/>'
  };
  const svg=path=>`<svg viewBox="0 0 24 24" aria-hidden="true">${path}</svg>`;

  // Vanilla inventory icons cut from the game's item atlases (icons/<m|f>/<short-hash>.webp,
  // see icons/manifest.json). `family` picks the body the icon was rendered on.
  let family="m", icons={};
  // icons/manifest.js (a script: the game's browser refuses fetch() on its own scheme).
  icons=window.WardrobeIcons || {};
  const report=(where,e)=>{try{emit("wardrobe:pageError",{message:where+": "+String(e && (e.stack || e.message) || e).slice(0,400),line:0});}catch(_){}};
  // Bridge handlers report their own failures: the bridge swallows exceptions.
  const on=(name,fn)=>Open77.on(name,value=>{try{fn(value);}catch(e){report(name,e);}});
  function iconFor(record){if(!record)return "";const entry=icons[record] || icons[canonical(record)] || {};return entry[family] || entry[family==="m"?"f":"m"] || "";}
  function art(record,className){
    const box=document.createElement("span");box.className=className;const src=iconFor(record);
    if(!src){box.classList.add("none");return box;}
    const img=document.createElement("img");img.src=src;img.alt="";img.loading="lazy";img.draggable=false;img.decoding="async";
    img.onerror=()=>{img.remove();box.classList.add("none");};box.append(img);return box;
  }

  const errors={save_timeout:"The server has not confirmed the save. You can retry; your draft is still here.",presentation_revision_conflict:"Your saved wardrobe changed elsewhere. The latest saved look has been restored. Please try your changes again.",revision_conflict:"Your saved wardrobe changed elsewhere. The latest saved look has been restored.",presentation_database_error:"Your look could not be saved. Your previous saved wardrobe is safe.",incompatible_body_family:"This item does not fit your current body type.",restricted_record:"This clothing item is not available on this server.",item_unavailable:"This clothing item is unavailable. Your last preview has been restored.",presentation_character_changed:"Your character changed. Close the wardrobe and open it again."};
  function reason(text) { return errors[text] || "Could not apply this change ("+String(text || "unknown error").replace(/_/g," ")+")."; }
  let toastTimer;
  function toast(text,kind="") {
    const t=$("toast");t.textContent=text;t.className="toast show "+kind;
    clearTimeout(toastTimer);toastTimer=setTimeout(()=>t.classList.remove("show"),kind==="error"?5200:2600);
  }
  function message(text,kind="") { $("status").textContent=text; $("status").className="status "+kind; if(kind)toast(text,kind); }

  function visualValue(value) { return value && (lookup[String(value).toLowerCase()] || {}).nonvisual === true ? false : value; }
  function catalogTitle(item) { return item.label || M.title(item.record); }
  function itemName(value) { value=visualValue(value);return value ? catalogTitle(lookup[String(value).toLowerCase()] || {record:value}) : "Nothing"; }
  function canonical(value) { return value ? ((lookup[String(value).toLowerCase()] || {}).record || value) : value; }
  function currentSlots() { return mode==="equipment"?draft.equipment:draft.wardrobe.outfits[outfit]; }
  // What the character shows: the active outfit over the worn clothes.
  function visibleLook(state) {
    const look={},active=state.wardrobe.active,over=active===false?null:state.wardrobe.outfits[active] || {};
    for(const s of M.slots){const v=over && Object.hasOwn(over,s)?over[s]:state.equipment[s];look[s]=visualValue(v) || false;}
    return look;
  }
  function editSlot(value) {
    currentSlots()[slot]=value;
    if(mode==="outfits") draft.wardrobe.active=outfit;
    else {
      // Editing worn clothing must show the selected garment, not an overlay
      // or a full-body suit covering it. These remain unsaved draft changes.
      draft.wardrobe.active=false;
      if(slot!=="Outfit") draft.equipment.Outfit=false;
    }
  }
  function dirty() { return baseline && M.dirty(baseline,draft); }
  function changeCount() {
    if(!baseline)return 0;const p=M.patch(baseline,draft);
    return Object.keys(p.equipment).length+Object.keys(p.wardrobe.outfits).length+Object.keys(p.wardrobe.names).length+(Object.hasOwn(p.wardrobe,"active")?1:0);
  }
  function updateControls() {
    const changed=dirty(),n=changeCount();
    $("saved-state").textContent=busy?"SAVING":changed?"UNSAVED":"SAVED";
    $("saved-state").className="badge"+(changed?" dirty":"");
    $("save").disabled=busy || previewPending || !changed;
    $("save").classList.toggle("ready",changed && !busy && !previewPending);
    $("save").firstElementChild.textContent=busy?"Saving…":changed?`Save look · ${n}`:"Save look";
    document.querySelectorAll(".card,.slot-actions button,.outfit-actions button,#rename,#disable-overlay,.look__row .x").forEach(el=>el.disabled=busy || previewPending);
  }
  function preview(change, text) {
    if(busy || previewPending) return false;
    confirmed=M.clone(draft);
    change();
    previewPending=true;
    emit("wardrobe:preview",{equipment:draft.equipment,wardrobe:draft.wardrobe});
    render();
    message(text || "Trying it on. Save your look to keep it.");
    return true;
  }
  function confirmAction(title,text,action,label="Discard") {
    $("confirm-title").textContent=title;$("confirm-text").textContent=text;
    $("confirm-yes").textContent=label;$("confirm").hidden=false;pendingConfirm=action;$("confirm-no").focus();
  }
  function requestClose() {
    if(!$("takeaway").hidden){skipTakeAway();return;}
    if(busy) { confirmAction("Save still pending","The server may still complete your save after closing. Close the fitting room?",()=>emit("wardrobe:close"),"Close"); return; }
    if(dirty()) confirmAction("Discard changes?","Your preview will be removed and your last saved look restored.",()=>emit("wardrobe:close"));
    else emit("wardrobe:close");
  }

  // ---------- Camera ----------
  function setZone(next,manual) {
    if(!next || next===zone && !manual)return;
    zone=next;emit("wardrobe:focus",{zone});
    document.querySelectorAll("#zones button").forEach(b=>b.classList.toggle("selected",b.dataset.zone===zone));
    const label=$("zone-label");label.textContent=ZONE_LABELS[zone];label.classList.remove("swap");void label.offsetWidth;label.classList.add("swap");
  }
  function rotate(degrees){yaw=((degrees+180)%360+360)%360-180;emit("wardrobe:orbit",{degrees:Math.round(yaw)});}
  $("zones").onclick=e=>{const b=e.target.closest("button[data-zone]");if(b)setZone(b.dataset.zone,true);};
  $("front").onclick=()=>rotate(180);$("back").onclick=()=>rotate(0);$("rotate-left").onclick=()=>rotate(yaw-45);$("rotate-right").onclick=()=>rotate(yaw+45);
  (function dragToTurn(){
    const stage=$("stage");let drag=null,lastSent=0;
    stage.addEventListener("pointerdown",e=>{
      if(e.button!==0 || e.target.closest(".stage__dock,.toast"))return;
      drag={x:e.clientX,yaw};stage.classList.add("dragging");stage.setPointerCapture?.(e.pointerId);
    });
    stage.addEventListener("pointermove",e=>{
      if(!drag)return;yaw=drag.yaw+(e.clientX-drag.x)*.45;
      const now=performance.now();if(now-lastSent>40){lastSent=now;rotate(yaw);}
    });
    const end=()=>{if(!drag)return;drag=null;stage.classList.remove("dragging");rotate(yaw);};
    stage.addEventListener("pointerup",end);stage.addEventListener("pointercancel",end);stage.addEventListener("lostpointercapture",end);
    stage.addEventListener("wheel",e=>{e.preventDefault();emit("wardrobe:zoom",{delta:Math.sign(e.deltaY)});},{passive:false});
  })();

  // ---------- Catalogue ----------
  function cardFor(item,index) {
    const row=document.createElement("div");row.className="item";row.setAttribute("role","listitem");row.style.setProperty("--i",String(Math.min(index%BATCH,14)));
    const selected=canonical(currentSlots()[slot])===item.record;
    row.classList.toggle("selected",selected);row.classList.toggle("trying",trying===item.record);
    const choose=document.createElement("button");choose.className="card";choose.dataset.record=item.record;choose.setAttribute("aria-pressed",String(selected));
    choose.title=catalogTitle(item);
    const name=document.createElement("span");name.className="card__name";name.textContent=catalogTitle(item);
    const tag=document.createElement("span");tag.className="card__tag";tag.textContent=mode==="outfits"?"IN OUTFIT":"WEARING";
    choose.append(art(item.record,"art"),name,tag);
    choose.onclick=()=>{if(canonical(currentSlots()[slot])===item.record)return;trying=item.record;if(!preview(()=>editSlot(item.record),"Trying on "+catalogTitle(item)+"."))trying=null;};
    const favorite=document.createElement("button");favorite.className="favorite";const on=favorites.has(item.record);favorite.classList.toggle("on",on);favorite.textContent=on?"★":"☆";
    favorite.setAttribute("aria-label",(on?"Remove favorite ":"Favorite ")+catalogTitle(item));
    favorite.disabled=!favoritesReady;
    favorite.onclick=e=>{e.stopPropagation();favoritesReady=false;favorite.classList.add("pop");document.querySelectorAll(".favorite").forEach(b=>b.disabled=true);emit("wardrobe:favorite",{record:item.record,enabled:!favorites.has(item.record)});};
    row.append(choose,favorite);return row;
  }
  function appendBatch() {
    const grid=$("catalogue"),next=entries.slice(shown,shown+BATCH);
    next.forEach((item,i)=>grid.append(cardFor(item,shown+i)));shown+=next.length;
    updateControls();
  }
  function renderItems() {
    const q=$("search").value.trim().toLowerCase();
    entries=catalogue.filter(item=>item.slot===slot && (!favoritesOnly || favorites.has(item.record)) && (!q || (catalogTitle(item)+" "+item.record).toLowerCase().includes(q)));
    const grid=$("catalogue"),scroll=grid.scrollTop,keep=Math.max(BATCH,shown);grid.replaceChildren();shown=0;
    if(!catalogue.length){for(let i=0;i<9;i++){const s=document.createElement("div");s.className="skeleton";grid.append(s);}$("count").textContent="LOADING";return;}
    if(!entries.length){const empty=document.createElement("p");empty.className="grid-empty";empty.textContent=favoritesOnly?"No favorites here yet. Star clothing to keep it close.":"Nothing matches. Try another search or category.";grid.append(empty);}
    while(shown<entries.length && shown<keep)appendBatch();
    grid.scrollTop=scroll;
    $("count").textContent=`${entries.length} ITEM${entries.length===1?"":"S"}`;
  }
  $("catalogue").addEventListener("scroll",()=>{const g=$("catalogue");if(shown<entries.length && g.scrollTop+g.clientHeight>g.scrollHeight-400)appendBatch();},{passive:true});

  // ---------- Rail, current slot, look, outfits ----------
  function renderRail() {
    const nav=$("slots");nav.replaceChildren();
    const look=visibleLook(draft),base=visibleLook(baseline);
    M.slots.forEach(name=>{
      const b=document.createElement("button");b.innerHTML=svg(ICONS[name])+`<span class="rail__label">${M.labels[name]}</span><i class="rail__worn" aria-hidden="true"></i>`;
      const value=mode==="outfits"?visualValue(currentSlots()[name]):look[name];
      b.classList.toggle("selected",name===slot);b.classList.toggle("worn",!!value);b.classList.toggle("changed",mode==="equipment" && !M.equal(look[name],base[name]));
      b.setAttribute("aria-pressed",String(name===slot));b.setAttribute("aria-label",M.labels[name]+(value?" · "+itemName(value):""));
      b.onclick=()=>selectSlot(name);nav.append(b);
    });
  }
  function selectSlot(name) {
    if(name!==slot){slot=name;$("catalogue").scrollTop=0;shown=0;}
    setZone(ZONES[slot]);render();
  }
  function renderCurrent() {
    $("slot-title").textContent=M.labels[slot];
    const raw=currentSlots()[slot],value=visualValue(raw);
    $("slot-label").textContent=mode==="outfits"?"IN THIS OUTFIT":"WEARING";
    $("selected-art").replaceChildren(art(value || "","art"));$("selected-art").className="thumb"+(value?"":" empty");
    $("selected-name").textContent=mode==="outfits" && raw===undefined?"Your clothes · "+itemName(draft.equipment[slot]):mode==="outfits" && raw===false?"Hidden in this outfit":itemName(value);
    $("inherit").hidden=mode!=="outfits";$("remove").textContent=mode==="outfits"?"Hide":"Remove";
    $("remove").disabled=busy || previewPending || (mode==="equipment" && !value);
  }
  function renderLook() {
    $("look-panel").hidden=false;
    $("look-title").textContent=mode==="outfits"?"IN THIS OUTFIT":"WHAT YOU WEAR";
    const list=$("look-list");list.replaceChildren();
    const look=visibleLook(draft),base=visibleLook(baseline);
    M.slots.forEach((name,i)=>{
      const raw=mode==="outfits"?currentSlots()[name]:look[name],value=visualValue(raw);
      const li=document.createElement("li");li.className="look__row";li.style.setProperty("--i",String(i));
      li.classList.toggle("selected",name===slot);li.classList.toggle("bare",!value);
      li.classList.toggle("changed",mode==="equipment" && !M.equal(look[name],base[name]));
      const text=document.createElement("div");text.innerHTML=`<small>${M.labels[name].toUpperCase()}</small>`;
      const strong=document.createElement("strong");
      strong.textContent=mode==="outfits" && raw===undefined?"Your clothes":mode==="outfits" && raw===false?"Hidden":value?itemName(value):"Nothing";
      text.append(strong);
      const x=document.createElement("button");x.className="x";x.setAttribute("aria-label","Remove "+M.labels[name]);x.innerHTML=svg('<path d="M6 6l12 12M18 6 6 18"/>');
      x.hidden=!value;x.onclick=e=>{e.stopPropagation();slot=name;preview(()=>editSlot(false),M.labels[name]+" removed.");};
      li.append(art(value || "","thumb"+(value?"":" empty")),text,x);
      li.onclick=()=>selectSlot(name);list.append(li);
    });
  }
  function collage(slots,className) {
    const box=document.createElement("span");box.className=className;
    const pieces=["Head","OuterChest","InnerChest","Outfit","Legs","Feet","Face"].map(s=>visualValue(slots[s])).filter(Boolean).slice(0,4);
    if(!pieces.length){box.classList.add("empty");box.textContent="EMPTY";return box;}
    pieces.forEach(r=>{const s=document.createElement("span");const src=iconFor(r);if(src){const img=document.createElement("img");img.src=src;img.alt="";img.loading="lazy";img.onerror=()=>img.remove();s.append(img);}box.append(s);});
    return box;
  }
  function renderOutfits() {
    $("outfit-tools").hidden=mode!=="outfits";if(mode!=="outfits")return;
    $("look-panel").hidden=true;
    const grid=$("outfits");grid.replaceChildren();
    for(let i=0;i<7;i++){
      const b=document.createElement("button");b.className="outfit";b.style.setProperty("--i",String(i));
      b.classList.toggle("selected",i===outfit);b.classList.toggle("active",draft.wardrobe.active===i);
      const name=document.createElement("span");name.className="outfit__name";name.innerHTML=`<b>${String(i+1).padStart(2,"0")}</b>`;
      const em=document.createElement("em");em.textContent=draft.wardrobe.names[i];name.append(em);
      b.append(collage(draft.wardrobe.outfits[i] || {},"outfit__art"),name);b.setAttribute("aria-label",draft.wardrobe.names[i]);
      b.onclick=()=>{outfit=i;render();};grid.append(b);
    }
    $("outfit-name").value=draft.wardrobe.names[outfit];
    $("wear").textContent=draft.wardrobe.active===outfit?"Outfit worn":"Wear outfit";
    $("semantics").textContent="Pick clothing on the left to edit this outfit. Hide shows nothing in a slot; Show worn lets your clothes show through.";
  }
  function render() {
    if(!draft)return;
    for(const name of ["equipment","outfits"]){const tab=$(name+"-tab");tab.classList.toggle("selected",mode===name);tab.setAttribute("aria-selected",String(mode===name));}
    const active=draft.wardrobe.active;$("overlay-banner").hidden=active===false || mode==="outfits";
    $("overlay-text").textContent=active===false?"":"Wearing the outfit “"+draft.wardrobe.names[active]+"”.";
    renderRail();renderCurrent();renderLook();renderOutfits();renderItems();updateControls();
  }

  // ---------- Controls ----------
  for(const name of ["equipment","outfits"]) $(name+"-tab").onclick=()=>{if(mode===name)return;mode=name;shown=0;render();};
  $("search").oninput=()=>{shown=0;renderItems();};
  function setFilter(fav){favoritesOnly=fav;$("filter").classList.toggle("selected",fav);$("filter").setAttribute("aria-pressed",String(fav));$("filter-all").classList.toggle("selected",!fav);$("filter-all").setAttribute("aria-pressed",String(!fav));shown=0;renderItems();}
  $("filter").onclick=()=>setFilter(true);$("filter-all").onclick=()=>setFilter(false);
  $("remove").onclick=()=>preview(()=>editSlot(false),mode==="outfits"?M.labels[slot]+" hidden in this outfit.":M.labels[slot]+" removed.");
  $("inherit").onclick=()=>preview(()=>{delete currentSlots()[slot];draft.wardrobe.active=outfit;},"This outfit now shows your own "+M.labels[slot].toLowerCase()+".");
  $("wear").onclick=()=>preview(()=>{draft.wardrobe.active=outfit;},"Wearing “"+draft.wardrobe.names[outfit]+"”.");
  $("disable-overlay").onclick=()=>preview(()=>{draft.wardrobe.active=false;},"Showing your clothes.");
  $("capture").onclick=()=>preview(()=>{const items={};for(const s of M.slots)items[s]=visualValue(draft.equipment[s]) || false;draft.wardrobe.outfits[outfit]=items;draft.wardrobe.active=outfit;},"What you wear is now in this outfit. Save your look to keep it.");
  $("delete").onclick=()=>confirmAction("Reset this outfit?","This clears its clothing and name. Your own clothes stay in place.",()=>preview(()=>{draft.wardrobe.outfits[outfit]={};draft.wardrobe.names[outfit]=`Outfit ${outfit+1}`;if(draft.wardrobe.active===outfit)draft.wardrobe.active=false;}),"Reset outfit");
  $("rename").onclick=()=>{const name=$("outfit-name").value.trim();if(!name || [...name].length>48 || /[\x00-\x1f\x7f]/.test(name)){message("Use an outfit name between 1 and 48 characters.","error");return;}draft.wardrobe.names[outfit]=name;render();message("Name updated. Save your look to keep it.");};
  $("outfit-name").onkeydown=e=>{if(e.key==="Enter"){e.preventDefault();$("rename").click();}};
  $("save").onclick=()=>{if(busy || previewPending || !dirty())return;busy=true;takeLook=visibleLook(draft);updateControls();message("Saving your look…");emit("wardrobe:save",M.patch(baseline,draft));};
  $("close").onclick=requestClose;$("cancel").onclick=()=>{if(!dirty()){emit("wardrobe:close");return;}confirmAction("Discard changes?","Your preview will be removed and your last saved look restored.",()=>emit("wardrobe:close"));};
  $("confirm-no").onclick=()=>{$("confirm").hidden=true;pendingConfirm=null;$("save").focus();};
  $("confirm-yes").onclick=()=>{const action=pendingConfirm;$("confirm").hidden=true;pendingConfirm=null;if(action)action();};
  for(const name of ["appearance","barber"]) $(name).onclick=()=>{if(busy)return;const action=()=>emit("wardrobe:appearance",{mode:name});if(dirty())confirmAction("Discard changes?","Opening the appearance editor restores your saved clothing and discards this preview.",action);else action();};

  // ---------- Take it with you ----------
  // Pieces: what this visit added to the look. Outfit: the whole look.
  function lookPieces(look,onlyNew) {
    const list=[];
    for(const s of M.slots){const r=look[s];if(!r || (onlyNew && initialLook && M.equal(initialLook[s],r)))continue;list.push({slot:s,record:canonical(r),label:itemName(r),icon:iconFor(r)});}
    return list;
  }
  function fillArt(box,pieces){box.replaceChildren();pieces.slice(0,4).forEach(p=>{const s=document.createElement("span");if(p.icon){const img=document.createElement("img");img.src=p.icon;img.alt="";s.append(img);}box.append(s);});}
  function setTakeMode(next){takeMode=next;for(const [id,m] of [["take-pieces","pieces"],["take-outfit","outfit"]]){$(id).classList.toggle("selected",m===next);$(id).setAttribute("aria-checked",String(m===next));}$("take-name-row").hidden=next!=="outfit";}
  function offerTakeAway() {
    const look=takeLook || visibleLook(baseline),pieces=lookPieces(look,true),all=lookPieces(look,false);
    if(!takeAway || !all.length)return false;
    fillArt($("take-pieces-art"),pieces.length?pieces:all);fillArt($("take-outfit-art"),all);
    $("take-pieces").disabled=!pieces.length;
    $("take-pieces-text").textContent=pieces.length?`${pieces.length} new piece${pieces.length===1?"":"s"}, one item each.`:"Nothing new this visit.";
    const active=baseline.wardrobe.active;$("take-name").value=active===false?"My look":baseline.wardrobe.names[active];
    setTakeMode(pieces.length?"pieces":"outfit");$("takeaway").hidden=false;$("take-confirm").disabled=false;$("take-confirm").focus();
    return true;
  }
  function skipTakeAway(){$("takeaway").hidden=true;takeLook=null;message("Your look is saved.","success");}
  $("take-pieces").onclick=()=>setTakeMode("pieces");$("take-outfit").onclick=()=>setTakeMode("outfit");
  $("take-skip").onclick=skipTakeAway;
  $("take-confirm").onclick=()=>{
    const look=takeLook || visibleLook(baseline),name=$("take-name").value.trim().slice(0,40) || "My look";
    $("take-confirm").disabled=true;
    emit("wardrobe:takeAway",{mode:takeMode,name,pieces:lookPieces(look,takeMode==="pieces"),look:lookPieces(look,false)});
  };

  // ---------- Activity, keyboard ----------
  let lastActivitySent=-Infinity;
  function activity(){
    if($("room").hidden)return;
    const now=performance.now();
    if(now-lastActivitySent<2000)return;
    lastActivitySent=now;emit("wardrobe:activity");
  }
  for(const name of ["keydown","pointerdown","input","wheel"])
    document.addEventListener(name,activity,{capture:true,passive:true});
  document.addEventListener("keydown",e=>{
    if($("room").hidden)return;
    if(e.key==="Escape"){e.preventDefault();if(!$("confirm").hidden)$("confirm-no").click();else requestClose();}
    if(e.key==="Tab"){const root=!$("confirm").hidden?$("confirm"):!$("takeaway").hidden?$("takeaway"):$("room");const focusable=[...root.querySelectorAll("button:not(:disabled),input,select")].filter(el=>el.offsetParent!==null);const first=focusable[0],last=focusable[focusable.length-1];if(e.shiftKey && document.activeElement===first){e.preventDefault();last?.focus();}else if(!e.shiftKey && document.activeElement===last){e.preventDefault();first?.focus();}}
  });

  // ---------- Bridge ----------
  on("wardrobe:open",value=>{
    baseline=M.normalize(value);draft=M.clone(baseline);catalogue=(value.catalogue || []).filter(item=>item.nonvisual !== true);lookup={};
    (value.catalogue || []).forEach(item=>{lookup[item.record.toLowerCase()]=item;if(item.tweakDbId)lookup[item.tweakDbId.toLowerCase()]=item;});
    busy=false;previewPending=false;trying=null;favoritesReady=false;favorites=new Set();confirmed=null;mode="equipment";outfit=draft.wardrobe.active===false?0:draft.wardrobe.active;slot="Head";yaw=180;zone="";shown=0;
    takeAway=value.takeAway===true;takeLook=null;initialLook=visibleLook(baseline);
    $("search").value="";favoritesOnly=false;setFilter(false);$("room").hidden=false;$("confirm").hidden=true;$("takeaway").hidden=true;
    family=String(value.family || "").toLowerCase().startsWith("f")?"f":"m";
    $("family").textContent=(value.family || "").toUpperCase()+" · "+(value.persistence==="ready"?"CHARACTER WARDROBE":"SESSION WARDROBE");
    $("camera-controls").hidden=!value.orbitAvailable;$("zones").hidden=!value.framingAvailable;
    setZone(ZONES[slot]);render();($("slots").querySelector(".selected")||$("slots")).focus();message("Loading the clothing catalogue…");
  });
  on("wardrobe:favorites",value=>{
    if(!draft)return;
    favorites=new Set(Array.isArray(value.items)?value.items:[]);favoritesReady=value.available===true;
    renderItems();
    if(value.error)message(value.error==="favorite_limit"?"You can save up to 256 favorites.":"Favorites could not be saved on this device. Try again after reconnecting.","error");
  });
  on("wardrobe:catalogue",value=>{
    if(!draft)return;
    const first=catalogue.length===0;
    // An empty Lua table arrives as {} (the last batch can be empty).
    const items=Array.isArray(value.items)?value.items:Object.values(value.items || {});
    for(const item of items){if(!item || typeof item.record!=="string")continue;if(item.nonvisual !== true)catalogue.push(item);lookup[item.record.toLowerCase()]=item;if(item.tweakDbId)lookup[item.tweakDbId.toLowerCase()]=item;}
    if(value.complete){catalogue.sort((a,b)=>catalogTitle(a).localeCompare(catalogTitle(b)));initialLook=visibleLook(baseline);render();if(!dirty())message("Select clothing to try it on. Save your look when it is ready.");}
    else if(first)render();
  });
  on("wardrobe:closed",()=>{$("room").hidden=true;$("confirm").hidden=true;$("takeaway").hidden=true;baseline=null;draft=null;busy=false;previewPending=false;});
  on("wardrobe:status",value=>message(value.message,value.kind));
  on("wardrobe:previewResult",value=>{
    if(!draft)return;previewPending=false;trying=null;
    if(!value.ok && confirmed){draft=confirmed;message(reason(value.reason),"error");}
    confirmed=null;$("current").classList.remove("flash");void $("current").offsetWidth;$("current").classList.add("flash");render();
  });
  on("wardrobe:saveFailed",value=>{busy=false;takeLook=null;updateControls();message(reason(value.reason),"error");});
  on("wardrobe:committed",value=>{
    if(!draft)return;busy=false;baseline=M.normalize(value.state);draft=M.clone(baseline);render();
    if(!value.ok){takeLook=null;message(reason(value.reason),"error");return;}
    if(!offerTakeAway())message("Your look is saved.","success");
  });
  on("wardrobe:takeAwayResult",value=>{
    $("takeaway").hidden=true;takeLook=null;
    if(value.ok){initialLook=visibleLook(baseline);message(value.text || "Added to your bag.","success");}
    else message(value.text || "These clothes could not be added to your bag.","error");
  });
  on("wardrobe:framing",value=>{if(value && value.available===false){$("zones").hidden=true;if(zone!=="full"){zone="full";$("zone-label").textContent=ZONE_LABELS.full;}}});
  on("wardrobe:probe",()=>emit("wardrobe:ready"));
  Open77.ready();
  emit("wardrobe:ready");
})();
