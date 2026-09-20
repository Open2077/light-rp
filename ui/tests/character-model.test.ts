import { test } from "node:test";
import assert from "node:assert/strict";
import { identityFields, initialPage, validateIdentity } from "../src/features/character/model.ts";
import type { CharacterState } from "../src/bridge/protocol.ts";

const character = { currentYear: 2077, minAge: 18, maxAge: 90, nameMinLength: 2, nameMaxLength: 24, nameAllowAccents: true, step: "identity" } as CharacterState;
const fields = { firstName: "Alex", lastName: "Morgan" };
test("identity accepts roleplay names and optional fields, using server limits", () => {
  assert.deepEqual(validateIdentity(fields, character), {});
  assert.deepEqual(validateIdentity({ firstName: "Élodie", lastName: "O'Neil-Smith" }, character), {});
  for (const name of ["A", "---9", "night_wolf", "🙂", "a".repeat(25)]) assert(validateIdentity({ ...fields, firstName: name }, character).firstName);
  assert(validateIdentity({ ...fields, firstName: "Élodie" }, { ...character, nameAllowAccents: false }).firstName);
  assert(validateIdentity(fields, { ...character, nameMinLength: 5 }).firstName);
});
test("birth date validates real calendar dates and the Night City age range", () => {
  for (const birthDate of ["2052-02-29", "2059-12-31", "1987-01-01", ""]) assert.deepEqual(validateIdentity({ ...fields, birthDate }, character), {});
  for (const birthDate of ["2053-02-29", "2050-04-31", "2050-13-01", "2050-01-00", "2060-01-01", "1986-01-01", "20-01-01"]) assert(validateIdentity({ ...fields, birthDate }, character).birthDate, birthDate);
  assert(validateIdentity({ ...fields, birthDate: "2058-01-01" }, { ...character, minAge: 21 }).birthDate);
});
test("resume follows authoritative workflow; drafts have no invented identity", () => {
  assert.equal(initialPage(character), "identity");
  assert.equal(initialPage({ ...character, step: "appearance" }), "appearance");
  assert.equal(initialPage({ ...character, step: "confirm" }), "review");
  assert.deepEqual(identityFields(character), { firstName: "", lastName: "", birthDate: "", origin: "", story: "" });
});
