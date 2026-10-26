/* Hosts the window on top of the stack (or the call takeover) with an enter
   animation whose direction follows the navigation (deeper / back). */
import { useStore, type View } from "@/store/store";
import { StatusApp } from "@/apps/status/StatusApp";
import { PhoneApp } from "@/apps/phone/PhoneApp";
import { ThreadList } from "@/apps/messages/ThreadList";
import { ThreadView } from "@/apps/messages/ThreadView";
import { NewMessage } from "@/apps/messages/NewMessage";
import { NewGroup } from "@/apps/messages/NewGroup";
import { GroupInfo } from "@/apps/messages/GroupInfo";
import { ContactsApp } from "@/apps/contacts/ContactsApp";
import { ContactEdit } from "@/apps/contacts/ContactEdit";
import { SettingsApp } from "@/apps/settings/SettingsApp";
import { FeedView } from "@/apps/social/FeedView";
import { ScreamThread } from "@/apps/social/ScreamThread";
import { ComposeView } from "@/apps/social/Compose";
import { ProfileView } from "@/apps/social/ProfileView";
import { ProfileEdit } from "@/apps/social/ProfileEdit";
import { PingsView } from "@/apps/social/PingsView";
import { NetHeat } from "@/apps/social/NetHeat";
import { CallScreen } from "@/call/CallScreen";
import { IncomingCall } from "@/call/IncomingCall";

function viewKey(v: View): string {
  switch (v.app) {
    case "phone": return "phone"; // tabs switch inside the window
    case "settings": return "settings";
    case "messages": return `messages:${v.screen}:${"threadId" in v ? v.threadId : ""}`;
    case "contacts": return v.screen === "edit" ? `contacts:edit:${v.id ?? "new"}` : "contacts:list";
    case "social":
      switch (v.screen) {
        case "feed": return "social:feed"; // modes switch inside the window
        case "tag": return `social:tag:${v.tag}`;
        case "thread": return `social:thread:${v.postId}`;
        case "compose": return `social:compose:${v.replyTo ?? ""}:${v.quoteOf ?? ""}`;
        case "profile": return `social:profile:${v.handle}`;
        default: return `social:${v.screen}`;
      }
    default: return v.app;
  }
}

function render(v: View, canBack: boolean) {
  switch (v.app) {
    case "status": return <StatusApp canBack={canBack} />;
    case "phone": return <PhoneApp tab={v.tab} canBack={canBack} />;
    case "messages":
      switch (v.screen) {
        case "list": return <ThreadList canBack={canBack} />;
        case "thread": return <ThreadView threadId={v.threadId} canBack={canBack} />;
        case "new": return <NewMessage canBack={canBack} />;
        case "group-new": return <NewGroup canBack={canBack} />;
        case "group-info": return <GroupInfo threadId={v.threadId} canBack={canBack} />;
      }
      return null;
    case "contacts":
      return v.screen === "edit" ? <ContactEdit id={v.id} number={v.number} canBack={canBack} /> : <ContactsApp filter={v.filter} canBack={canBack} />;
    case "settings": return <SettingsApp section={v.section} canBack={canBack} />;
    case "social":
      switch (v.screen) {
        case "feed": return <FeedView mode={v.mode} canBack={canBack} />;
        case "tag": return <FeedView tag={v.tag} canBack={canBack} />;
        case "thread": return <ScreamThread postId={v.postId} canBack={canBack} />;
        case "compose": return <ComposeView replyTo={v.replyTo} quoteOf={v.quoteOf} canBack={canBack} />;
        case "profile": return <ProfileView handle={v.handle} canBack={canBack} />;
        case "edit": return <ProfileEdit canBack={canBack} />;
        case "pings": return <PingsView canBack={canBack} />;
        case "heat": return <NetHeat search={!!v.search} canBack={canBack} />;
      }
      return null;
  }
}

export function WindowHost() {
  const stack = useStore((s) => s.stack);
  const callView = useStore((s) => s.callView);
  const call = useStore((s) => s.state?.call ?? null);
  const dir = useStore((s) => s.navDir);

  if (call && callView) {
    return (
      <div className="tilt tilt--call" key={`call-${call.id}-${call.phase === "incoming" ? "in" : "on"}`}>
        <div className="win-enter nl-hit">{call.phase === "incoming" ? <IncomingCall call={call} /> : <CallScreen call={call} />}</div>
      </div>
    );
  }

  const top = stack[stack.length - 1];
  if (!top) return null;
  return (
    <div className="tilt tilt--window">
      <div className={`win-enter win-enter--${dir} nl-hit`} key={viewKey(top)}>
        {render(top, stack.length > 1)}
      </div>
    </div>
  );
}
