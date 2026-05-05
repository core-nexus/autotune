const encoder = new TextEncoder()

function toHex(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf)
  let out = ''
  for (let i = 0; i < bytes.length; i++) {
    out += bytes[i]!.toString(16).padStart(2, '0')
  }
  return out
}

export async function hmacSha256Hex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  )
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(body))
  return toHex(sig)
}

// Constant-time equality for two hex strings. Returns false on length mismatch.
export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  }
  return diff === 0
}

export type VerifyInput = {
  secret: string
  rawBody: string
  signatureHeader: string | null
  timestampHeader: string | null
  now: number // ms since epoch
  toleranceSeconds?: number // default 300
}

export type VerifyResult =
  | { ok: true }
  | { ok: false; reason: 'missing_signature' | 'missing_timestamp' | 'timestamp_not_number' | 'stale_timestamp' | 'bad_signature' }

// Sentry sends Sentry-Hook-Timestamp as seconds-since-epoch (number as string).
// Some Sentry deployments have historically sent ms; accept both by detecting magnitude.
function parseTimestampToMs(raw: string): number | null {
  const n = Number(raw)
  if (!Number.isFinite(n)) return null
  // If it looks like seconds (< ~10^12), upscale.
  return n < 1e12 ? n * 1000 : n
}

export async function verifySentryWebhook(input: VerifyInput): Promise<VerifyResult> {
  if (!input.signatureHeader) return { ok: false, reason: 'missing_signature' }
  if (!input.timestampHeader) return { ok: false, reason: 'missing_timestamp' }
  const tsMs = parseTimestampToMs(input.timestampHeader)
  if (tsMs === null) return { ok: false, reason: 'timestamp_not_number' }
  const tolMs = (input.toleranceSeconds ?? 300) * 1000
  if (Math.abs(input.now - tsMs) > tolMs) {
    return { ok: false, reason: 'stale_timestamp' }
  }
  const expected = await hmacSha256Hex(input.secret, input.rawBody)
  if (!timingSafeEqualHex(expected, input.signatureHeader.trim())) {
    return { ok: false, reason: 'bad_signature' }
  }
  return { ok: true }
}
