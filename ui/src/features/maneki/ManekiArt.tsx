import { useId } from "react";

/* The lucky cat, drawn (the game's figure is a 16 cm mesh with no portrait): a white
   Maneki-neko with its raised paw, red collar, gold bell and koban coin. `locked` is
   the same silhouette, dark, with a question mark: a cat not found yet tells nothing. */
export function ManekiArt({ locked = false, size = 96, className }: { locked?: boolean; size?: number; className?: string }) {
  const uid = useId().replace(/:/g, "");
  const g = (n: string) => `url(#mk-${n}-${uid})`;
  if (locked) {
    return <svg className={className} viewBox="0 0 120 140" width={size} height={size * 140 / 120} aria-hidden="true">
      <ellipse cx="60" cy="133" rx="36" ry="5" fill="#000" opacity=".35" />
      <g fill="#1b1f27" stroke="#343a46" strokeWidth="2" strokeLinejoin="round">
        <path d="M84 80C96 70 101 52 99 37c-1-8-9-10-13-4-2 12-6 24-14 34z" />
        <path d="M26 130c-8-26-2-48 12-58h44c14 10 20 32 12 58z" />
        <path d="M31 42 28 12l22 17zM85 42l3-30-22 17z" />
        <ellipse cx="58" cy="52" rx="31" ry="26" />
        <circle cx="93" cy="32" r="9" />
      </g>
      <text x="58" y="104" textAnchor="middle" fontFamily="var(--font-mono, monospace)" fontWeight="700" fontSize="34" fill="#4a5262">?</text>
    </svg>;
  }
  return <svg className={className} viewBox="0 0 120 140" width={size} height={size * 140 / 120} aria-hidden="true">
    <defs>
      <linearGradient id={`mk-fur-${uid}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FFFDF8" /><stop offset="1" stopColor="#E9DFCB" /></linearGradient>
      <linearGradient id={`mk-gold-${uid}`} x1="0" y1="0" x2="1" y2="1"><stop offset="0" stopColor="#FFE680" /><stop offset=".55" stopColor="#F2B705" /><stop offset="1" stopColor="#A86F00" /></linearGradient>
      <radialGradient id={`mk-glow-${uid}`} cx=".5" cy=".55" r=".55"><stop offset="0" stopColor="#FFCC00" stopOpacity=".35" /><stop offset="1" stopColor="#FFCC00" stopOpacity="0" /></radialGradient>
    </defs>
    <ellipse cx="60" cy="74" rx="58" ry="66" fill={g("glow")} />
    <ellipse cx="60" cy="133" rx="36" ry="5" fill="#000" opacity=".35" />
    {/* raised paw */}
    <path d="M84 80C96 70 101 52 99 37c-1-8-9-10-13-4-2 12-6 24-14 34z" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" />
    <circle cx="93" cy="32" r="9" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" />
    <path d="M89 29a2 2 0 1 0 0 .1M93 26a2 2 0 1 0 0 .1M97 29a2 2 0 1 0 0 .1" stroke="#F49AAE" strokeWidth="3.2" strokeLinecap="round" />
    {/* body */}
    <path d="M26 130c-8-26-2-48 12-58h44c14 10 20 32 12 58z" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" />
    <path d="M70 92c10 4 16 16 16 30" stroke="#E6A33E" strokeWidth="5" strokeLinecap="round" fill="none" opacity=".55" />
    {/* koban coin and the paw that holds it */}
    <ellipse cx="50" cy="108" rx="14" ry="19" fill={g("gold")} stroke="#8A5A00" strokeWidth="1.5" />
    <ellipse cx="50" cy="108" rx="10" ry="15" fill="none" stroke="#8A5A00" strokeWidth="1" opacity=".7" />
    <path d="M45 100h10M50 97v22M45 110h10M46 116h8" stroke="#8A5A00" strokeWidth="1.6" strokeLinecap="round" />
    <ellipse cx="37" cy="100" rx="9" ry="7.5" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" />
    {/* ears and head */}
    <path d="M31 42 28 12l22 17zM85 42l3-30-22 17z" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" strokeLinejoin="round" />
    <path d="M33 34 31.5 19 43 28zM83 34l1.5-15L73 28z" fill="#F49AAE" />
    <ellipse cx="58" cy="52" rx="31" ry="26" fill={g("fur")} stroke="#B9A985" strokeWidth="1.5" />
    <path d="M40 30q4-5 8 0M66 28q4-5 8 0" stroke="#E6A33E" strokeWidth="3" strokeLinecap="round" fill="none" opacity=".7" />
    {/* face */}
    <path d="M43 52q5-6 10 0M63 52q5-6 10 0" stroke="#2A2118" strokeWidth="2.4" strokeLinecap="round" fill="none" />
    <circle cx="40" cy="61" r="4.5" fill="#F49AAE" opacity=".55" /><circle cx="76" cy="61" r="4.5" fill="#F49AAE" opacity=".55" />
    <path d="M55.5 58.5h5l-2.5 3z" fill="#E0607A" />
    <path d="M58 61.5q-3 4-6 1M58 61.5q3 4 6 1" stroke="#2A2118" strokeWidth="1.4" strokeLinecap="round" fill="none" />
    <path d="M30 56l10 2M30 62l10-1M86 56l-10 2M86 62l-10-1" stroke="#7D6E57" strokeWidth="1" strokeLinecap="round" />
    {/* collar and bell */}
    <path d="M33 74q25 11 50 0l1 7q-26 11-52 0z" fill="#D7263D" stroke="#8E1222" strokeWidth="1" />
    <circle cx="58" cy="86" r="6.5" fill={g("gold")} stroke="#8A5A00" strokeWidth="1.3" />
    <path d="M52.5 85h11M58 87v4" stroke="#8A5A00" strokeWidth="1.2" strokeLinecap="round" />
  </svg>;
}
