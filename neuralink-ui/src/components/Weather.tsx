import { Cloud, CloudFog, CloudLightning, CloudRain, CloudSun, Moon, Sun, Wind } from "lucide-react";

/** Night City weather strings ("Light rain", "ToxicRain", "Fog", ...) to an icon. */
export function WeatherIcon({ weather, size = 22 }: { weather?: string; size?: number }) {
  const w = (weather ?? "").toLowerCase();
  const p = { size, strokeWidth: 1.9 };
  if (/storm|thunder|lightning/.test(w)) return <CloudLightning {...p} />;
  if (/rain|drizzle|shower/.test(w)) return <CloudRain {...p} />;
  if (/fog|mist|haze|smog|pollution/.test(w)) return <CloudFog {...p} />;
  if (/sand|dust|wind/.test(w)) return <Wind {...p} />;
  if (/overcast|cloud/.test(w)) return /partly|few/.test(w) ? <CloudSun {...p} /> : <Cloud {...p} />;
  if (/night|moon/.test(w)) return <Moon {...p} />;
  return <Sun {...p} />;
}
