/* Edit my Screamsheet profile: handle, display name, bio, with a live preview
   of the cover. Server slugs (handle_taken, invalid_handle) show inline. */
import { useEffect, useState, type KeyboardEvent } from "react";
import { AtSign, Save, UserPen, UserRound } from "lucide-react";
import { getStore, useStore } from "@/store/store";
import { BIO_MAX, HANDLE_RE, SOCIAL_NAME_MAX } from "@/bridge/protocol";
import { errorText } from "@/bridge/errors";
import { RequestError } from "@/bridge/open77";
import { Window } from "@/components/Window";
import { Area, Avatar, Btn, Field, Loader } from "@/components/ui";
import { act, actOrThrow } from "@/store/actions";
import { play } from "@/fx/sound";
import { ProfileCover } from "./ProfileView";

export function ProfileEdit({ canBack }: { canBack: boolean }) {
  const mine = useStore((s) => s.state?.social?.handle ?? "");
  const profile = useStore((s) => (mine ? s.profiles[mine] : undefined));
  const [handle, setHandle] = useState(profile?.handle ?? mine);
  const [name, setName] = useState(profile?.name ?? "");
  const [bio, setBio] = useState(profile?.bio ?? "");
  const [ready, setReady] = useState(!!profile);
  const [handleErr, setHandleErr] = useState<string | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (ready) return;
    void act("social.me", {}).then((r) => {
      if (!r) return;
      getStore().setProfile(r.profile);
      getStore().setSocialUnread(r.unread);
      setHandle(r.profile.handle); setName(r.profile.name); setBio(r.profile.bio);
      setReady(true);
    });
  }, [ready]);

  const handleOk = HANDLE_RE.test(handle);
  const nameOk = name.trim().length >= 1 && name.trim().length <= SOCIAL_NAME_MAX;
  const bioOk = bio.length <= BIO_MAX;

  const save = async () => {
    if (!profile) return;
    if (!handleOk) { setHandleErr(errorText("invalid_handle")); play("error"); return; }
    if (!nameOk) { setErr(errorText("invalid_name")); play("error"); return; }
    if (!bioOk) return;
    const args: { handle?: string; name?: string; bio?: string } = {};
    if (handle !== profile.handle) args.handle = handle;
    if (name.trim() !== profile.name) args.name = name.trim();
    if (bio.trim() !== profile.bio) args.bio = bio.trim();
    if (Object.keys(args).length === 0) { play("back"); getStore().back(); return; }
    setBusy(true); setErr(null); setHandleErr(null);
    try {
      const r = await actOrThrow("social.update", args);
      const st = getStore();
      st.setSocialHandle(r.profile.handle);
      st.setProfile(r.profile);
      play("select");
      if (!getStore().back()) getStore().resetView(null);
    } catch (e) {
      play("error");
      const slug = e instanceof RequestError ? e.slug : "unknown";
      if (slug === "handle_taken" || slug === "invalid_handle") setHandleErr(errorText(slug));
      else setErr(errorText(slug));
      setBusy(false);
    }
  };
  const enter = (e: KeyboardEvent) => { if (e.key === "Enter") { e.preventDefault(); void save(); } };

  return (
    <Window
      icon={<UserPen size={22} />}
      title="Edit profile"
      subtitle={`@${handle || mine}`}
      tag="NL//06-EDT"
      canBack={canBack}
      bodyClass="sedit"
      footer={
        <div className="form__bar">
          <span className="form__hint">Your handle is how the city tags you.</span>
          <Btn tone="sel" icon={<Save size={17} />} onClick={() => void save()} disabled={busy || !ready}>{busy ? "Saving…" : "Save"}</Btn>
        </div>
      }
    >
      {!ready || !profile ? <Loader text="Pulling your file" /> : (
        <div className="form sedit__form nl-scroll">
          <div className="sedit__preview">
            <ProfileCover seed={profile.seed} handle={handle || profile.handle} />
            <span className="sedit__av"><Avatar name={name || "?"} seed={profile.seed} size={76} ring="sel" /></span>
          </div>
          <Field label="Handle" icon={<AtSign size={16} />} placeholder="judy_a" value={handle} maxLength={16} counter
            error={handleErr ?? (handle.length > 0 && !handleOk ? errorText("invalid_handle") : null)}
            onChange={(e) => { setHandle(e.target.value.toLowerCase().replace(/[^a-z0-9_]/g, "")); setHandleErr(null); }}
            onKeyDown={enter} />
          <Field label="Display name" icon={<UserRound size={16} />} placeholder="Judy Alvarez" value={name} maxLength={SOCIAL_NAME_MAX} counter
            onChange={(e) => { setName(e.target.value); setErr(null); }}
            onKeyDown={enter} />
          <label className="field sedit__bio">
            <span className="field__label label">Bio</span>
            <Area value={bio} maxLength={BIO_MAX} rows={3} placeholder="Braindance editor. Lizzie's regular. Don't ask about the Mox." onChange={(e) => setBio(e.target.value)} />
            <span className={`sedit__count mono ${bio.length >= BIO_MAX ? "is-max" : bio.length > BIO_MAX - 20 ? "is-warn" : ""}`}>{bio.length}/{BIO_MAX}</span>
          </label>
          {err && <div className="form__error">{err}</div>}
        </div>
      )}
    </Window>
  );
}
