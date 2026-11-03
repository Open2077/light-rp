import { Fragment, type ReactNode } from "react";
import { Keycap } from "@/design/components";
import { parseInline, type GuideInline } from "./model";

/* The guide's inline markup (`code`, **bold**, {key:name} as the player's own key),
   shared by the FAQ panel and the dialogue. */
export function Rich({ text, keys }: { text: string; keys: Record<string, string> }) {
  return <>{renderInline(parseInline(text), keys)}</>;
}

function renderInline(parts: GuideInline[], keys: Record<string, string>): ReactNode[] {
  return parts.map((p, i) => p.kind === "text" ? <Fragment key={i}>{p.text}</Fragment>
    : p.kind === "code" ? <code key={i} className="guide-code">{p.text}</code>
    : p.kind === "bold" ? <strong key={i}>{renderInline(p.parts, keys)}</strong>
    : <Keycap key={i} size="sm" className="guide-key">{keys[p.name] ?? p.name.toUpperCase()}</Keycap>);
}
