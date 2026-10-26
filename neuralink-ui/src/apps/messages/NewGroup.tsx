/* New group: title + 2..15 contacts or numbers -> groups.create -> thread. */
import { useState } from "react";
import { Type, Users } from "lucide-react";
import { Window } from "@/components/Window";
import { ContactPicker } from "@/components/ContactPicker";
import { Btn, Field } from "@/components/ui";
import { actOrThrow, openThread } from "@/store/actions";
import { GROUP_MAX_OTHERS, GROUP_MIN_OTHERS } from "@/bridge/protocol";
import { errorText } from "@/bridge/errors";
import { RequestError } from "@/bridge/open77";
import { play } from "@/fx/sound";

export function NewGroup({ canBack }: { canBack: boolean }) {
  const [title, setTitle] = useState("");
  const [numbers, setNumbers] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const titleOk = title.trim().length >= 1 && title.trim().length <= 32;
  const countOk = numbers.length >= GROUP_MIN_OTHERS && numbers.length <= GROUP_MAX_OTHERS;

  const create = async () => {
    if (!titleOk || !countOk || busy) { play("error"); return; }
    setBusy(true); setErr(null);
    try {
      const r = await actOrThrow("groups.create", { title: title.trim(), numbers });
      openThread(r.threadId, "reset");
    } catch (e) {
      play("error");
      setErr(errorText(e instanceof RequestError ? e.slug : "unknown"));
      setBusy(false);
    }
  };

  const need = GROUP_MIN_OTHERS - numbers.length;
  return (
    <Window
      icon={<Users size={22} />}
      title="New group"
      subtitle={`${numbers.length} selected · ${GROUP_MIN_OTHERS} to ${GROUP_MAX_OTHERS} members`}
      tag="NL//03-GRP"
      canBack={canBack}
      footer={
        <div className="form__bar">
          <span className="form__hint">{!titleOk ? "Give the group a name." : need > 0 ? `Add ${need} more member${need > 1 ? "s" : ""}.` : "Ready to link."}</span>
          <Btn tone="sel" icon={<Users size={17} />} onClick={create} disabled={!titleOk || !countOk || busy}>{busy ? "Creating…" : "Create group"}</Btn>
        </div>
      }
    >
      <div className="form">
        <Field label="Group name" icon={<Type size={16} />} placeholder="Afterlife Crew" value={title} maxLength={32} counter onChange={(e) => setTitle(e.target.value)} />
        {err && <div className="form__error">{err}</div>}
        <ContactPicker mode="multi" selected={numbers} onChange={setNumbers} max={GROUP_MAX_OTHERS} />
      </div>
    </Window>
  );
}
