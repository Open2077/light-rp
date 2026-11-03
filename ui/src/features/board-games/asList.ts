/** A list from Lua: an empty Lua table arrives as `{}`, not `[]`, and a sparse
    one as an object with numeric keys. Always read Lua lists through this
    before .map/.filter. */
export function asList<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[];
  if (!value || typeof value !== "object") return [];
  const record = value as Record<string, T>;
  return Object.keys(record).sort((a, b) => Number(a) - Number(b)).map(key => record[key] as T);
}
