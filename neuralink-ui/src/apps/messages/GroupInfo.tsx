/* Group info sheet: members (owner crown, online dot), rename, add member,
   remove member (owner only), leave, group call. */
import { useEffect, useState } from "react";
import { Check, LogOut, Pencil, Phone, UserMinus, UserPlus, Users, X } from "lucide-react";
import { useStore } from "@/store/store";
import { Window } from "@/components/Window";
import { ContactPicker } from "@/components/ContactPicker";
import { Avatar, Btn, Field, IconBtn, SectionTitle } from "@/components/ui";
import { act, actOrThrow, groupCall } from "@/store/actions";
import { GROUP_MAX_OTHERS } from "@/bridge/protocol";
import { errorText } from "@/bridge/errors";
import { RequestError } from "@/bridge/open77";
import { play } from "@/fx/sound";

export function GroupInfo({ threadId, canBack }: { threadId: number; canBack: boolean }) {
  const summary = useStore((s) => s.state?.threads.find((t) => t.id === threadId) ?? null);
  const cacheMembers = useStore((s) => s.threadCache[threadId]?.members);
  const inCall = useStore((s) => !!s.state?.call);
  const [renaming, setRenaming] = useState(false);
  const [title, setTitle] = useState(summary?.title ?? "");
  const [adding, setAdding] = useState(false);
  const [confirmLeave, setConfirmLeave] = useState(false);
  const [confirmRemove, setConfirmRemove] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => { if (!renaming) setTitle(summary?.title ?? ""); }, [summary?.title, renaming]);

  if (!summary) {
    return <Window icon={<Users size={22} />} title="Group" canBack={canBack}><div className="form"><div className="form__error">This group is no longer available.</div></div></Window>;
  }
  const members = [...(summary.members.length ? summary.members : cacheMembers ?? [])].sort((a, b) => Number(b.owner) - Number(a.owner) || Number(b.isMe) - Number(a.isMe) || Number(b.online) - Number(a.online) || a.name.localeCompare(b.name));
  const isOwner = summary.isOwner;
  const full = members.length - 1 >= GROUP_MAX_OTHERS;

  const fail = (e: unknown) => { play("error"); setErr(errorText(e instanceof RequestError ? e.slug : "unknown")); };

  const rename = async () => {
    const t = title.trim();
    if (!t || t === summary.title) { setRenaming(false); return; }
    try { await actOrThrow("groups.rename", { threadId, title: t }); play("select"); setRenaming(false); setErr(null); } catch (e) { fail(e); }
  };
  const add = async (number: string) => {
    try { await actOrThrow("groups.add", { threadId, number }); play("select"); setAdding(false); setErr(null); } catch (e) { fail(e); }
  };
  const remove = async (number: string) => {
    setConfirmRemove(null);
    try { await actOrThrow("groups.remove", { threadId, number }); play("back"); setErr(null); } catch (e) { fail(e); }
  };
  const leave = async () => {
    const r = await act("groups.leave", { threadId });
    if (r) {
      play("back");
      useStore.getState().resetView({ app: "messages", screen: "list" });
    }
  };

  return (
    <Window
      icon={<Users size={22} />}
      title="Group info"
      subtitle={`${members.length} members${isOwner ? " · you own this group" : ""}`}
      tag={`GRP-${String(threadId).padStart(4, "0")}`}
      canBack={canBack}
    >
      <div className="ginfo nl-scroll">
        <div className="ginfo__hero">
          <Avatar name={summary.title} seed={`g${summary.id}`} size={84} group ring="sel" />
          {renaming ? (
            <div className="ginfo__rename">
              <Field value={title} maxLength={32} counter onChange={(e) => setTitle(e.target.value)} onKeyDown={(e) => { if (e.key === "Enter") { e.preventDefault(); void rename(); } }} />
              <IconBtn label="Save name" tone="sel" onClick={rename}><Check size={18} /></IconBtn>
              <IconBtn label="Cancel" onClick={() => setRenaming(false)}><X size={18} /></IconBtn>
            </div>
          ) : (
            <div className="ginfo__title">
              <span>{summary.title}</span>
              <IconBtn label="Rename group" onClick={() => setRenaming(true)}><Pencil size={16} /></IconBtn>
            </div>
          )}
          <div className="ginfo__actions">
            <Btn tone="ok" icon={<Phone size={17} />} disabled={inCall} onClick={() => void groupCall(threadId)}>Group call</Btn>
            <Btn tone="ghost" icon={<UserPlus size={17} />} disabled={full} onClick={() => setAdding((v) => !v)}>{adding ? "Close" : "Add member"}</Btn>
          </div>
        </div>
        {err && <div className="form__error">{err}</div>}

        {adding && (
          <div className="ginfo__add">
            <SectionTitle>Add a member</SectionTitle>
            <ContactPicker mode="single" exclude={members.map((m) => m.number)} onPick={add} pickLabel="Add" />
          </div>
        )}

        <SectionTitle aside={<span className="mono ginfo__online">{members.filter((m) => m.online).length} online</span>}>Members</SectionTitle>
        <div className="ginfo__members">
          {members.map((m, i) => (
            <div key={m.number} className="mrow" style={{ ["--i" as string]: Math.min(i, 14) }}>
              <Avatar name={m.name} seed={m.number} size={40} online={m.online} owner={m.owner} />
              <span className="mrow__main">
                <span className="mrow__name">{m.name}{m.isMe && <span className="mrow__me label">You</span>}</span>
                <span className="mrow__num mono">{m.number}{m.owner ? " · owner" : ""}</span>
              </span>
              {isOwner && !m.isMe && (
                confirmRemove === m.number ? (
                  <span className="mrow__confirm">
                    <Btn small tone="danger" onClick={() => remove(m.number)}>Remove</Btn>
                    <Btn small tone="ghost" onClick={() => setConfirmRemove(null)}>Keep</Btn>
                  </span>
                ) : (
                  <IconBtn label={`Remove ${m.name}`} tone="danger" onClick={() => setConfirmRemove(m.number)}><UserMinus size={17} /></IconBtn>
                )
              )}
            </div>
          ))}
        </div>

        <div className="ginfo__leave">
          {confirmLeave ? (
            <>
              <span>Leave “{summary.title}”? You will stop receiving its messages.</span>
              <Btn tone="danger" icon={<LogOut size={16} />} onClick={leave}>Leave group</Btn>
              <Btn tone="ghost" onClick={() => setConfirmLeave(false)}>Cancel</Btn>
            </>
          ) : (
            <Btn tone="danger" icon={<LogOut size={16} />} onClick={() => setConfirmLeave(true)}>Leave group</Btn>
          )}
        </div>
      </div>
    </Window>
  );
}
