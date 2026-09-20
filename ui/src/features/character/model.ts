import type { CharacterState, IdentityFields } from "../../bridge/protocol";

export type WizardPage = "identity" | "background" | "appearance" | "review";
export const STEPS: { id: WizardPage; label: string; detail: string }[] = [
  { id: "identity", label: "Identity", detail: "A name of your own" },
  { id: "background", label: "Background", detail: "Where your story begins" },
  { id: "appearance", label: "Appearance", detail: "Make it yours" },
  { id: "review", label: "Ready to go", detail: "Your first steps in the city" },
];
export const initialPage = (c: CharacterState): WizardPage => c.step === "identity" ? "identity" : c.step === "appearance" ? "appearance" : "review";
export const identityFields = (c: CharacterState): IdentityFields => ({ firstName: c.firstName ?? "", lastName: c.lastName ?? "", birthDate: c.birthDate ?? "", origin: c.origin ?? "", story: c.story ?? "" });
export function validateIdentity(fields: IdentityFields, c: CharacterState): Record<string, string> {
  const errors: Record<string, string> = {};
  const min = c.nameMinLength ?? 2, max = c.nameMaxLength ?? 24;
  const letters = c.nameAllowAccents === false ? /^[A-Za-z '-]+$/ : /^[A-Za-z\u00c0-\u024f '-]+$/;
  for (const key of ["firstName", "lastName"] as const) {
    const name = fields[key].trim();
    if ([...name].length < min || [...name].length > max) errors[key] = `Use ${min}–${max} characters.`;
    else if (!letters.test(name)) errors[key] = "Use letters, spaces, hyphens or apostrophes.";
  }
  if (fields.birthDate) {
    const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(fields.birthDate);
    const y = Number(match?.[1]), m = Number(match?.[2]), d = Number(match?.[3]);
    const days = new Date(Date.UTC(y, m, 0)).getUTCDate();
    if (!match || m < 1 || m > 12 || d < 1 || d > days) errors.birthDate = "Enter a real date as YYYY-MM-DD.";
    else if (c.currentYear - y < c.minAge || c.currentYear - y > (c.maxAge ?? 90)) errors.birthDate = `Your character must be ${c.minAge}–${c.maxAge ?? 90} in ${c.currentYear}.`;
  }
  return errors;
}
export const ORIGIN_NOTES: Record<string, string> = {
  night_city: "You know these streets. Now make a name on them.",
  badlands: "Open roads, close ties. A new stop on your journey.",
  ncus: "A different corner of the country. A fresh start here.",
  europe: "An ocean behind you. A whole city ahead.",
  asia: "New streets. Familiar ambition.",
  latam: "Bring your roots. Write your next chapter.",
};
