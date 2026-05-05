import type { Normalized } from './types.js'

// GitHub repository_dispatch client_payload must be under 10 KB. The
// dispatcher wraps the normalized object into a stringified `data` field,
// which inflates bytes via JSON escaping (~5–10% on typical payloads). We
// target 8500 bytes on the pre-escape object to leave headroom.
export const MAX_CLIENT_PAYLOAD_BYTES = 8500

const CORE_TAG_WHITELIST = [
  'environment',
  'release',
  'transaction',
  'url',
  'runtime',
  'runtime.name',
  'browser',
  'browser.name',
  'os',
  'os.name',
  'level',
  'handled',
  'mechanism',
]

function byteLength(obj: unknown): number {
  return new TextEncoder().encode(JSON.stringify(obj)).length
}

function stripContextLines(n: Normalized): Normalized {
  return {
    ...n,
    topFrames: n.topFrames.map((f) => ({ ...f, contextLine: null })),
  }
}

function restrictTags(n: Normalized, keys: string[]): Normalized {
  const keep: Record<string, string> = {}
  for (const k of keys) {
    const v = n.tags[k]
    if (typeof v === 'string') keep[k] = v
  }
  return { ...n, tags: keep }
}

// Progressively shrink until under budget. Order:
//   1. Drop breadcrumbs.
//   2. Reduce topFrames to 3.
//   3. Whitelist tags to a small core set.
//   4. Strip contextLine on frames.
// Never drop URLs or IDs.
export function fitClientPayload(n: Normalized): Normalized {
  if (byteLength(n) <= MAX_CLIENT_PAYLOAD_BYTES) return n

  let out: Normalized = { ...n, breadcrumbs: [] }
  if (byteLength(out) <= MAX_CLIENT_PAYLOAD_BYTES) return out

  out = { ...out, topFrames: out.topFrames.slice(0, 3) }
  if (byteLength(out) <= MAX_CLIENT_PAYLOAD_BYTES) return out

  out = restrictTags(out, CORE_TAG_WHITELIST)
  if (byteLength(out) <= MAX_CLIENT_PAYLOAD_BYTES) return out

  out = stripContextLines(out)
  if (byteLength(out) <= MAX_CLIENT_PAYLOAD_BYTES) return out

  // Last resort: truncate title/culprit.
  const truncate = (s: string | null, max: number): string | null =>
    s === null ? null : s.length > max ? s.slice(0, max) : s
  out = {
    ...out,
    title: truncate(out.title, 500) ?? out.title,
    culprit: truncate(out.culprit, 500),
    exception: out.exception
      ? {
          type: truncate(out.exception.type, 200) ?? '',
          value: truncate(out.exception.value, 500) ?? '',
        }
      : null,
  }
  return out
}
