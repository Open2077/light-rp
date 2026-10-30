/* Paths and sizes of the generated media (public/media, see scripts/build-assets.py). */
import type { Body } from "./data";

export interface VideoInfo { width: number; height: number; frames: number; fps: number; box: [number, number, number, number] }
export interface StillBox { left: number; top: number; width: number; height: number }
export interface Manifest { videos?: Record<string, VideoInfo>; stills?: Record<string, StillBox>; icons?: string[] }

export const bodyVideo = (body: Body) => `./media/video/${body}_body.webm`;
export const sectionVideo = (body: Body, section: string) => `./media/video/${body}_${section}.webm`;
export const stillImage = (body: Body, section: string) => `./media/still/${body}_${section}.webp`;
export const iconImage = (icon: string) => `./media/icon/${icon}.webp`;
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
