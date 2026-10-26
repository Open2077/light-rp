/* New message: pick a contact or type a number -> threads.direct -> thread. */
import { useState } from "react";
import { MessageSquarePlus } from "lucide-react";
import { Window } from "@/components/Window";
import { ContactPicker } from "@/components/ContactPicker";
import { actOrThrow, openThread } from "@/store/actions";
import { errorText } from "@/bridge/errors";
import { RequestError } from "@/bridge/open77";
import { play } from "@/fx/sound";

export function NewMessage({ canBack }: { canBack: boolean }) {
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const pick = async (number: string) => {
    if (busy) return;
    setBusy(true); setErr(null);
    try {
      const r = await actOrThrow("threads.direct", { number });
      openThread(r.threadId, "reset");
    } catch (e) {
      play("error");
      setErr(errorText(e instanceof RequestError ? e.slug : "unknown"));
      setBusy(false);
    }
  };
  return (
    <Window icon={<MessageSquarePlus size={22} />} title="New message" subtitle="Choose who to reach" tag="NL//03-NEW" canBack={canBack}>
      <div className="form">
        {err && <div className="form__error">{err}</div>}
        <ContactPicker mode="single" onPick={pick} pickLabel="Message" />
      </div>
    </Window>
  );
}
