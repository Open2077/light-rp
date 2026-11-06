/* The course music, played by the page itself (the WebUI host hands the page's PCM to the
   game's audio, its volume honoured). Starts when a run starts (the countdown), loops while
   the player stays on the course (restarts included), fades out when the run ends. 5 %
   unless the server says otherwise (server config `music`). */

let audio: HTMLAudioElement | null = null;
let fade: number | undefined;
let target = 0.05;

function ramp(to: number, ms: number, done?: () => void) {
  if (!audio) return;
  window.clearInterval(fade);
  const from = audio.volume, steps = Math.max(1, Math.round(ms / 50));
  let i = 0;
  fade = window.setInterval(() => {
    i += 1;
    if (!audio) { window.clearInterval(fade); return; }
    audio.volume = Math.min(1, Math.max(0, from + (to - from) * (i / steps)));
    if (i >= steps) { window.clearInterval(fade); done?.(); }
  }, 50);
}

export function startMusic(file = "audio/parkour-rooftop-momentum.webm", volume = 0.05) {
  target = Math.min(1, Math.max(0, volume));
  const src = new URL(file.replace(/^\.?\//, ""), document.baseURI).href;
  if (audio && audio.src === src && !audio.paused) { ramp(target, 600); return; }
  stopMusic(0);
  audio = new Audio(src);
  audio.loop = true;
  audio.preload = "auto";
  audio.volume = 0;
  void audio.play().then(() => ramp(target, 1500)).catch((e) => console.warn("[parkour] music refused:", e));
}

export function stopMusic(ms = 1200) {
  const current = audio;
  if (!current) return;
  if (ms <= 0) { window.clearInterval(fade); current.pause(); audio = null; return; }
  ramp(0, ms, () => { current.pause(); if (audio === current) audio = null; });
}

export function musicPlaying() { return !!audio && !audio.paused; }
