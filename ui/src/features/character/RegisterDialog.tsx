import { useEffect, useState } from "react";
import { useStore } from "@/state/store";
import { emit, sendAction } from "@/bridge/open77";
import { Input, Modal } from "@/design/components";

/* The dialog needs the keyboard: it asks the client for focus while mounted and
   releases it when it goes (registered, or the menu took over). */
function useDialogFocus(active: boolean) {
  useEffect(() => {
    if (!active) return;
    emit("lightrp:ui:focus", { active: true });
    return () => emit("lightrp:ui:focus", { active: false });
  }, [active]);
}

/* First arrival: the character has no name yet. A prompt modal in the design
   system's register, over the world, until the server confirms a registration
   (the state patch flips `registered`, which unmounts this). */
export function RegisterDialog() {
  const character = useStore((s) => s.state.character);
  const connected = useStore((s) => s.connected);
  const menuOpen = useStore((s) => s.menuOpen);
  const [first, setFirst] = useState("");
  const [last, setLast] = useState("");
  const [sent, setSent] = useState(false);
  const visible = connected && !character.registered && !menuOpen;
  useDialogFocus(visible);

  if (!visible) return null;
  const valid = first.trim().length >= 2 && last.trim().length >= 2;
  const submit = () => {
    if (!valid) return;
    setSent(true);
    sendAction({ type: "register", firstName: first.trim(), lastName: last.trim() });
    setTimeout(() => setSent(false), 3000);
  };

  return (
    <Modal kind="prompt" title="Nouveau personnage" tag="IDENTITÉ" size="lg" scrim="none"
      subtitle="OPEN//77 // OFFICIAL ROLEPLAY"
      footerNote="ESC POUR PLUS TARD · /REGISTER DANS LE CHAT"
      actions={[{ label: sent ? "Envoi…" : "Enregistrer", variant: "primary", icon: "badge-check", disabled: !valid || sent, onClick: submit }]}>
      <p style={{ margin: 0 }}>
        Choisissez le nom que les autres joueurs liront. Le chat normal parle en jeu sous ce nom ; le compte reste privé.
      </p>
      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--sp-5)" }}>
        <Input label="PRÉNOM" icon="user" autoFocus value={first} onChange={(e) => setFirst(e.target.value)} placeholder="Prénom" maxLength={24}
          onKeyDown={(e) => { if (e.key === "Enter") submit(); }} />
        <Input label="NOM" icon="user" value={last} onChange={(e) => setLast(e.target.value)} placeholder="Nom" maxLength={24}
          onKeyDown={(e) => { if (e.key === "Enter") submit(); }} />
      </div>
    </Modal>
  );
}
