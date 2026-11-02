/* Paths and sizes of the generated media (public/media, see scripts/build-assets.py). */
import type { Body } from "./data";

export interface VideoInfo { width: number; height: number; frames: number; fps: number; box: [number, number, number, number] }
export interface StillBox { left: number; top: number; width: number; height: number }
export interface Manifest { videos?: Record<string, VideoInfo>; stills?: Record<string, StillBox>; icons?: string[] }

export const bodyVideo = (body: Body) => `./media/video/${body}_body.webm`;
export const sectionVideo = (body: Body, section: string) => `./media/video/${body}_${section}.webm`;
export const stillImage = (body: Body, section: string) => `./media/still/${body}_${section}.webp`;
// An icon's file is named by a short hash of its name (FNV-1a 32, 8 hex digits, the
// same as scripts/build-assets.py): the cyberware names are long, and the player's
// cache path (game folder + set digest + resource) must stay under Windows' 260
// characters; "cw_integumentary_neuroactivearmor_capacitors.webp" did not.
export const iconFile = (icon: string) => {
  let hash = 0x811c9dc5;
  for (let i = 0; i < icon.length; i++) hash = Math.imul(hash ^ icon.charCodeAt(i), 0x01000193) >>> 0;
  return hash.toString(16).padStart(8, "0");
};
export const iconImage = (icon: string) => `./media/icon/${iconFile(icon)}.webp`;
export const uiImage = (name: string) => `./media/ui/${name}.webp`;

let cached: Manifest | null = null;
export async function loadManifest(): Promise<Manifest> {
  if (cached) return cached;
  try {
    const response = await fetch("./media/manifest.json");
    cached = (await response.json()) as Manifest;
  } catch {
    cached = {};
  }
  return cached;
}
