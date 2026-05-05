import type { Trigger } from './types.js'

export type SeenRecord = {
  dispatchId: string
  dispatchedAt: string
  trigger: Trigger
}

export type KVLike = {
  get(key: string): Promise<string | null>
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>
}

export function dedupKey(projectSlug: string, shortId: string): string {
  return `seen:${projectSlug}:${shortId}`
}

export async function checkSeen(
  kv: KVLike | KVNamespace | undefined,
  projectSlug: string,
  shortId: string,
): Promise<SeenRecord | null> {
  if (!kv) return null
  try {
    const raw = await (kv as KVLike).get(dedupKey(projectSlug, shortId))
    if (!raw) return null
    return JSON.parse(raw) as SeenRecord
  } catch {
    return null
  }
}

export async function markSeen(
  kv: KVLike | KVNamespace | undefined,
  projectSlug: string,
  shortId: string,
  record: SeenRecord,
): Promise<void> {
  if (!kv) return
  try {
    await (kv as KVLike).put(dedupKey(projectSlug, shortId), JSON.stringify(record), {
      expirationTtl: 86400,
    })
  } catch {
    // Swallow: Sentry's alert action interval is the authoritative dedup.
  }
}
