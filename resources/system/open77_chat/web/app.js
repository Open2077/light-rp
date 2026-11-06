(() => {
  "use strict";

  const MAX_MESSAGES = 48;
  const MAX_MESSAGE_LENGTH = 4096;
  // Closed, the whole chat hides this long after the last activity (a message's
  // `duration` can keep it longer), and this long after it is closed.
  const IDLE_MS = 10000;
  const IDLE_AFTER_CLOSE_MS = 6000;
  // More lines than this in one frame (history replay, a burst) arrive without animation.
  const BURST_ANIMATED = 3;
  const KNOWN_KINDS = new Set([
    "message", "system", "announce", "warning", "error", "action", "join", "leave"
  ]);
  // Design system palette (tokens.css). A channel tag is drawn only when the
  // sender named one: roleplay speech carries the character's name, nothing else.
  const CHANNELS = {
    global: { label: "Global", color: "#FFCC00" },
    local: { label: "Local", color: "#8A8F9C" },
    squad: { label: "Squad", color: "#35D07F" },
    whisper: { label: "Whisper", color: "#7FA7B8" },
    ooc: { label: "OOC", color: "#8A8F9C" },
    admin: { label: "Admin", color: "#FF2E3C" }
  };
  const ACCENT = "#FFCC00";

  const root = document.getElementById("chat");
  const messages = document.getElementById("messages");       // the scroller (fixed height)
  const messageList = document.getElementById("messageList"); // the lines, pinned to its bottom
  const emptyState = document.getElementById("emptyState");
  const composer = document.getElementById("composer");
  const input = document.getElementById("input");
  const characterCount = document.getElementById("characterCount");
  const sendButton = document.getElementById("sendButton");
  const footer = root.querySelector(".chat__foot");

  const suggestionsNode = document.getElementById("suggestions");
  const suggestionList = document.getElementById("suggestionList");

  const scrollLatest = document.getElementById("scrollLatest");
  const unreadCount = document.getElementById("unreadCount");

  const suggestions = new Map();
  const templates = new Map();
  const history = [];
  let historyIndex = 0;
  let open = false;
  let visibleSuggestions = [];
  let selectedSuggestion = 0;
  let unreadMessages = 0;
  // Follow the newest line: always when closed, when open until the reader scrolls up.
  let following = true;
  let idleTimer = 0;
  let idleDeadline = 0;
  let arrivalsThisFrame = 0;
  let arrivalsReset = 0;

  const bounded = (value, max = MAX_MESSAGE_LENGTH) => String(value ?? "").slice(0, max);
  const safeToken = (value, fallback) => {
    const token = bounded(value, 24).toLowerCase().replace(/[^a-z0-9_-]/g, "");
    return token || fallback;
  };
  const rgb = (value, fallback = ACCENT) => {
    if (!Array.isArray(value) || value.length < 3) return fallback;
    const component = index => Math.max(0, Math.min(255, Math.round(Number(value[index]) || 0)));
    return `rgb(${component(0)}, ${component(1)}, ${component(2)})`;
  };
  const timeNow = () => new Intl.DateTimeFormat("en-GB", {
    hour: "2-digit", minute: "2-digit", hour12: false
  }).format(new Date());
  const isAtBottom = (slack = 24) => messages.scrollHeight - messages.scrollTop - messages.clientHeight < slack;
  const element = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };

  // ---------- pinning: the newest line is always fully in view ----------
  function pinToBottom() {
    messages.scrollTop = messages.scrollHeight;
  }
  // The list grows (new rows, their height animation, wrapping) without a scroll event:
  // keep the bottom edge in view on every size change while following.
  new ResizeObserver(() => {
    if (!open || following) pinToBottom();
  }).observe(messageList);
  new ResizeObserver(() => {
    if (!open || following) pinToBottom();
  }).observe(messages);

  // ---------- auto-hide ----------
  function setIdle(value) {
    root.classList.toggle("is-idle", value);
  }
  function wake(delay) {
    setIdle(messageList.children.length === 0);
    if (open) return;
    idleDeadline = Math.max(idleDeadline, Date.now() + delay);
    clearTimeout(idleTimer);
    idleTimer = setTimeout(() => {
      idleTimer = 0;
      if (!open) setIdle(true);
    }, Math.max(0, idleDeadline - Date.now()));
  }

  function updateEmptyState() {
    const empty = messageList.children.length === 0;
    root.classList.toggle("is-empty", empty);
    emptyState.setAttribute("aria-hidden", String(!empty));
    if (empty && !open) setIdle(true);
  }

  function updateComposerState() {
    const length = input.value.length;
    characterCount.textContent = `${length}/256`;
    characterCount.classList.toggle("is-long", length >= 160);
    characterCount.classList.toggle("near-limit", length >= 232);
    sendButton.disabled = input.value.trim().length === 0;
  }

  function updateUnread(value) {
    unreadMessages = Math.max(0, value);
    unreadCount.textContent = String(unreadMessages);
    const show = open && unreadMessages > 0;
    if (show && scrollLatest.hidden) {
      scrollLatest.hidden = false;
    } else if (!show) {
      scrollLatest.hidden = true;
    }
  }

  function scrollToLatest(behavior = "auto") {
    following = true;
    if (behavior === "smooth") messages.scrollTo({ top: messages.scrollHeight, behavior });
    else pinToBottom();
    updateUnread(0);
  }

  // ---------- messages ----------
  function normalizeKind(raw) {
    const source = safeToken(raw.kind || raw.type, "message");
    if (source === "player" || source === "default") return "message";
    if (source === "announcement") return "announce";
    return KNOWN_KINDS.has(source) ? source : "message";
  }

  function normalizeMessage(raw = {}) {
    const args = Array.isArray(raw.args) ? raw.args : [];
    const author = bounded(raw.author ?? (args.length > 1 ? args[0] : ""), 96);
    let text = bounded(
      raw.text ?? raw.message ?? (args.length > 1 ? args.slice(1).join(" ") : args[0]),
      MAX_MESSAGE_LENGTH
    );
    if (raw.templateId && templates.has(String(raw.templateId))) {
      text = templates.get(String(raw.templateId)).replace(/\{(\d+)\}/g,
        (_, index) => bounded(args[Number(index)] ?? "", 1024));
    }

    let kind = normalizeKind(raw);
    // Roleplay emotes arrive as plain lines whose author starts with "* " (/me, /do, /try).
    if (kind === "message" && /^\*\s+\S/.test(author)) kind = "emote";
    const explicitChannel = Object.prototype.hasOwnProperty.call(CHANNELS, raw.channel);
    const channel = explicitChannel ? raw.channel : (kind === "warning" ? "admin" : "global");
    const channelColor = CHANNELS[channel].color;
    return {
      ...raw,
      author,
      text,
      kind,
      channel,
      explicitChannel,
      channelColor,
      color: rgb(raw.color, channelColor),
      playerId: bounded(raw.playerId, 20),
      role: safeToken(raw.role, ""),
      time: bounded(raw.time || timeNow(), 16),
      segments: Array.isArray(raw.segments) ? raw.segments : [],
      mention: raw.mention === true || raw.mentioned === true,
      title: bounded(raw.title, 96)
    };
  }

  function appendText(row, message) {
    const text = element("span", "message-text");
    if (message.segments.length) {
      for (const source of message.segments.slice(0, 32)) {
        const segment = element("span", `message-segment${source && source.bold ? " bold" : ""}`,
          bounded(source && source.text, 1024));
        if (source && source.color) segment.style.color = rgb(source.color);
        text.append(segment);
      }
    } else {
      text.textContent = message.text;
    }
    row.append(text);
  }

  const appendTime = (row, message) => row.append(element("time", "message-time", message.time));

  function buildBody(body, message) {
    if (message.kind === "announce") {
      const heading = element("div", "message-announcement-heading");
      heading.append(element("i"), element("span", "", message.title || "Server announcement"));
      appendTime(heading, message);
      body.append(heading);
      appendText(body, message);
      return;
    }

    appendTime(body, message);

    if (message.kind === "system" || message.kind === "error" || message.kind === "warning") {
      const label = message.author || (message.kind === "error" ? "Error" : message.kind === "warning" ? "Warning" : "System");
      body.append(element("span", "message-tag", label));
      appendText(body, message);
      return;
    }

    if (message.kind === "join" || message.kind === "leave") {
      const state = element("span", "presence-state");
      state.setAttribute("aria-hidden", "true");
      const presence = element("span", "presence-text");
      presence.append(element("b", "", message.author || "Player"),
        ` ${message.kind === "join" ? "connected" : "disconnected"}${message.text ? ` · ${message.text}` : ""}`);
      body.append(state, presence);
      return;
    }

    if (message.kind === "action" || message.kind === "emote") {
      const name = message.kind === "emote" ? message.author.replace(/^\*\s+/, "") : (message.author || "Player");
      const action = element("span", "action-text");
      action.append("* ", element("span", "action-name", name), ` ${message.text}`);
      body.append(action);
      return;
    }

    if (message.explicitChannel) {
      body.append(element("span", "message-channel", CHANNELS[message.channel].label.toUpperCase()));
    }
    if (/^\d+$/.test(message.playerId)) {
      body.append(element("span", "message-player-id", `#${message.playerId}`));
    }
    if (message.mention) body.append(element("span", "message-ping", "@"));
    if (message.author) {
      const author = element("span", `message-author${message.role ? ` role-${message.role}` : ""}`, message.author);
      if (message.role) author.append(element("small", "", message.role));
      body.append(author);
    }
    appendText(body, message);
  }

  function buildMessageRow(message) {
    const row = element("article", `message message-${message.kind}`);
    if (message.mention) row.classList.add("is-mention");
    row.style.setProperty("--message-color", message.color);
    row.style.setProperty("--channel-color", message.channelColor);
    const body = element("div", "message__body");
    buildBody(body, message);
    row.append(body);
    return row;
  }

  // The row's height opens from 0 so the lines above slide up instead of jumping;
  // its body animates in through CSS (.is-new). A burst arrives without animation.
  function animateArrival(row) {
    if (!arrivalsReset) {
      arrivalsReset = requestAnimationFrame(() => { arrivalsThisFrame = 0; arrivalsReset = 0; });
    }
    arrivalsThisFrame += 1;
    if (arrivalsThisFrame > BURST_ANIMATED || document.hidden) return;
    row.classList.add("is-new");
    const height = row.offsetHeight;
    if (height > 0 && typeof row.animate === "function") {
      row.style.overflow = "hidden";
      const growth = row.animate([{ height: "0px", opacity: 0 }, { height: `${height}px`, opacity: 1 }],
        { duration: 200, easing: "cubic-bezier(.2, .8, .2, 1)" });
      growth.onfinish = growth.oncancel = () => { row.style.overflow = ""; };
    }
    setTimeout(() => row.classList.remove("is-new"), 1700);
  }

  function addMessage(raw) {
    const message = normalizeMessage(raw);
    if (!message.text && !message.segments.length) return;

    // Open: follow only when the reader is (still) at the bottom. Measured now, not only
    // from scroll events, which arrive a frame late.
    const follow = !open || (following && isAtBottom(40));
    if (!follow) following = false;
    const row = buildMessageRow(message);
    messageList.append(row);
    while (messageList.children.length > MAX_MESSAGES) messageList.firstElementChild.remove();

    updateEmptyState();
    if (follow) pinToBottom();
    else updateUnread(unreadMessages + 1);
    animateArrival(row);
    if (follow) pinToBottom();
    wake(Math.max(IDLE_MS, Number(message.duration) || 0));
  }

  // ---------- command index ----------
  function renderSuggestions() {
    suggestionList.replaceChildren();
    const query = input.value.trim().toLowerCase();
    if (!query.startsWith("/")) {
      visibleSuggestions = [];
      selectedSuggestion = 0;
      suggestionsNode.classList.remove("has-items");
      root.classList.remove("has-suggestions");
      return;
    }

    const commandQuery = query.split(/\s+/)[0];
    visibleSuggestions = [...suggestions.values()]
      .filter(item => item.command.toLowerCase().startsWith(commandQuery))
      .sort((left, right) => left.command.length - right.command.length || left.command.localeCompare(right.command))
      .slice(0, 7);
    selectedSuggestion = Math.max(0, Math.min(selectedSuggestion, visibleSuggestions.length - 1));

    visibleSuggestions.forEach((item, index) => {
      const row = element("div", `suggestion${index === selectedSuggestion ? " selected" : ""}`);
      row.setAttribute("role", "option");
      row.setAttribute("aria-selected", String(index === selectedSuggestion));
      row.append(element("span", "suggestion-index", String(index + 1).padStart(2, "0")));

      const syntax = element("span", "suggestion-syntax");
      syntax.append(element("strong", "suggestion-command", item.command));
      // An empty Lua table arrives as {} (a JSON object), not []: only a real array lists parameters.
      for (const parameter of (Array.isArray(item.parameters) ? item.parameters : []).slice(0, 8)) {
        const name = bounded(parameter && parameter.name || parameter, 40);
        const node = element("span", "suggestion-params", parameter && parameter.optional ? `[${name}]` : `<${name}>`);
        if (parameter && parameter.help) node.title = bounded(parameter.help, 240);
        syntax.append(node);
      }
      row.append(syntax, element("span", "suggestion-help", bounded(item.help, 240)));
      row.addEventListener("pointerdown", event => {
        event.preventDefault();
        selectedSuggestion = index;
        completeSuggestion();
      });
      suggestionList.append(row);
    });
    const hasItems = visibleSuggestions.length > 0;
    suggestionsNode.classList.toggle("has-items", hasItems);
    root.classList.toggle("has-suggestions", hasItems);
  }

  function completeSuggestion() {
    const item = visibleSuggestions[selectedSuggestion];
    if (!item) return false;
    const match = input.value.match(/^\s*\/\S*(.*)$/s);
    const suffix = match ? match[1] : "";
    input.value = item.command + (suffix.trim() ? suffix : " ");
    input.setSelectionRange(input.value.length, input.value.length);
    selectedSuggestion = 0;
    updateComposerState();
    renderSuggestions();
    input.focus();
    return true;
  }

  // ---------- open / close ----------
  function setOpen(value) {
    open = Boolean(value);
    root.classList.toggle("open", open);
    composer.setAttribute("aria-hidden", String(!open));
    footer.setAttribute("aria-hidden", String(!open));
    following = true;

    if (open) {
      clearTimeout(idleTimer);
      idleTimer = 0;
      idleDeadline = 0;
      setIdle(false);
      input.focus();
      updateEmptyState();
      pinToBottom();
      requestAnimationFrame(() => {
        pinToBottom();
        input.focus();
        window.Open77.emit("chat:requestSuggestions", {});
      });
    } else {
      input.blur();
      input.value = "";
      selectedSuggestion = 0;
      updateUnread(0);
      updateComposerState();
      renderSuggestions();
      // Closed, the log has no scrolling: always pinned to the newest line.
      pinToBottom();
      updateEmptyState();
      wake(IDLE_AFTER_CLOSE_MS);
    }
  }

  function submit() {
    const text = input.value.trim();
    if (!text) {
      window.Open77.emit("chat:close", {});
      return;
    }
    history.push(text);
    if (history.length > 50) history.shift();
    historyIndex = history.length;
    root.classList.remove("transmitting");
    void root.offsetWidth;
    root.classList.add("transmitting");
    window.Open77.emit("chat:submit", { text });
  }

  input.addEventListener("input", () => {
    selectedSuggestion = 0;
    updateComposerState();
    renderSuggestions();
  });
  input.addEventListener("focus", () => root.classList.add("input-focused"));
  input.addEventListener("blur", () => root.classList.remove("input-focused"));

  document.addEventListener("keydown", () => {
    if (open && document.activeElement !== input) input.focus();
  }, true);

  input.addEventListener("keydown", event => {
    if (event.isComposing) return;
    if (event.key === "Escape") {
      event.preventDefault();
      window.Open77.emit("chat:close", {});
    } else if (event.key === "Enter") {
      event.preventDefault();
      submit();
    } else if (event.key === "Tab" && visibleSuggestions.length) {
      event.preventDefault();
      completeSuggestion();
    } else if (event.key === "ArrowUp" && visibleSuggestions.length) {
      event.preventDefault();
      selectedSuggestion = (selectedSuggestion - 1 + visibleSuggestions.length) % visibleSuggestions.length;
      renderSuggestions();
    } else if (event.key === "ArrowDown" && visibleSuggestions.length) {
      event.preventDefault();
      selectedSuggestion = (selectedSuggestion + 1) % visibleSuggestions.length;
      renderSuggestions();
    } else if (event.key === "ArrowUp" && history.length) {
      event.preventDefault();
      historyIndex = Math.max(0, historyIndex - 1);
      input.value = history[historyIndex] || "";
      updateComposerState();
      renderSuggestions();
    } else if (event.key === "ArrowDown" && history.length) {
      event.preventDefault();
      historyIndex = Math.min(history.length, historyIndex + 1);
      input.value = history[historyIndex] || "";
      updateComposerState();
      renderSuggestions();
    } else if ((event.key === "PageUp" || event.key === "PageDown") && open) {
      event.preventDefault();
      if (event.key === "PageUp") following = false;
      messages.scrollBy({ top: (event.key === "PageUp" ? -1 : 1) * messages.clientHeight * 0.8 });
    }
  });

  sendButton.addEventListener("click", submit);
  scrollLatest.addEventListener("click", () => scrollToLatest("smooth"));
  // Reading back up stops following at once (the scroll event comes a frame later).
  messages.addEventListener("wheel", event => {
    if (open && event.deltaY < 0) following = false;
  }, { passive: true });
  messages.addEventListener("scroll", () => {
    if (!open) return;
    following = isAtBottom();
    if (following) updateUnread(0);
  }, { passive: true });

  Open77.on("chat:open", () => setOpen(true));
  Open77.on("chat:close", () => setOpen(false));
  Open77.on("chat:state", state => {
    const enabled = !state || state.enabled !== false;
    root.classList.toggle("disabled", !enabled);
    if (!enabled) setOpen(false);
  });
  Open77.on("chat:addMessage", addMessage);
  Open77.on("chat:clear", () => {
    messageList.replaceChildren();
    updateUnread(0);
    updateEmptyState();
  });
  Open77.on("chat:clearSuggestions", () => {
    suggestions.clear();
    selectedSuggestion = 0;
    renderSuggestions();
  });
  Open77.on("chat:addTemplate", payload => {
    if (payload && payload.id) templates.set(String(payload.id), bounded(payload.template));
  });
  const addSuggestion = item => {
    if (!item || !item.command) return;
    const command = String(item.command).startsWith("/") ? String(item.command) : `/${item.command}`;
    suggestions.set(command.toLowerCase(), { ...item, command });
  };
  Open77.on("chat:addSuggestion", payload => {
    addSuggestion(payload);
    renderSuggestions();
  });
  Open77.on("chat:addSuggestions", payload => {
    // An empty Lua list arrives as {}: only a real array is walked.
    const list = payload && Array.isArray(payload.suggestions) ? payload.suggestions : [];
    for (const item of list) addSuggestion(item);
    renderSuggestions();
  });
  Open77.on("chat:removeSuggestion", payload => {
    const command = String(payload && payload.command || "");
    suggestions.delete((command.startsWith("/") ? command : `/${command}`).toLowerCase());
    renderSuggestions();
  });

  updateComposerState();
  updateEmptyState();
  Open77.ready();
  Open77.emit("chat:ready", {});
})();
