/* Mock-only control strip (browser dev). Hidden with ?dev=0. */
import { useState } from "react";
import { mockApi } from "./mock";
import { useStore } from "@/store/store";

export default function MockPanel() {
  const [hidden, setHidden] = useState(false);
  const phase = useStore((s) => s.phase);
  const m = mockApi();
  if (!m) return null;
  if (hidden) return <button type="button" className="mockpanel mockpanel--min" onClick={() => setHidden(false)}>mock</button>;
  const open = phase === "open" || phase === "opening";
  return (
    <div className="mockpanel">
      <b>mock</b>
      <button type="button" onClick={() => (open ? m.close() : m.open())}>{open ? "close" : "open"}</button>
      <button type="button" onClick={() => m.incoming()}>incoming</button>
      <button type="button" onClick={() => m.incomingGroup()}>group in</button>
      <button type="button" onClick={() => m.hangup()}>drop call</button>
      <button type="button" onClick={() => m.message(1)}>msg 1:1</button>
      <button type="button" onClick={() => m.message(2)}>msg group</button>
      <button type="button" onClick={() => m.scream()}>scream</button>
      <button type="button" onClick={() => m.ping()}>ping</button>
      <button type="button" onClick={() => m.toast("info")}>toast</button>
      <button type="button" onClick={() => m.toast("error")}>error</button>
      <button type="button" onClick={() => setHidden(true)}>×</button>
    </div>
  );
}
