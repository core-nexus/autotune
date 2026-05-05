import { describe, expect, it } from 'vitest'
import { hmacSha256Hex, verifySentryWebhook, timingSafeEqualHex } from '../src/signature.js'

const SECRET = 'top-secret'
const BODY = '{"hello":"world"}'

describe('hmacSha256Hex', () => {
  it('produces a stable hex digest', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    expect(sig).toMatch(/^[0-9a-f]{64}$/)
    // Deterministic
    expect(await hmacSha256Hex(SECRET, BODY)).toBe(sig)
    // Changes with body
    expect(await hmacSha256Hex(SECRET, BODY + ' ')).not.toBe(sig)
    // Changes with key
    expect(await hmacSha256Hex(SECRET + '!', BODY)).not.toBe(sig)
  })
})

describe('timingSafeEqualHex', () => {
  it('returns true for equal strings', () => {
    expect(timingSafeEqualHex('abc', 'abc')).toBe(true)
  })
  it('returns false for different lengths', () => {
    expect(timingSafeEqualHex('abc', 'abcd')).toBe(false)
  })
  it('returns false for single-char mismatch', () => {
    expect(timingSafeEqualHex('abc', 'abd')).toBe(false)
  })
})

describe('verifySentryWebhook', () => {
  const nowMs = 1_700_000_000_000
  const timestampSeconds = String(nowMs / 1000)

  it('accepts a correctly signed, fresh request', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: sig,
      timestampHeader: timestampSeconds,
      now: nowMs,
    })
    expect(res.ok).toBe(true)
  })

  it('rejects when the body is tampered with', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY + '!', // tampered
      signatureHeader: sig,
      timestampHeader: timestampSeconds,
      now: nowMs,
    })
    expect(res.ok).toBe(false)
    if (!res.ok) expect(res.reason).toBe('bad_signature')
  })

  it('rejects when the secret is wrong', async () => {
    const sig = await hmacSha256Hex('wrong-secret', BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: sig,
      timestampHeader: timestampSeconds,
      now: nowMs,
    })
    expect(res.ok).toBe(false)
  })

  it('rejects a stale timestamp', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: sig,
      timestampHeader: String(nowMs / 1000 - 600), // 10 min ago
      now: nowMs,
    })
    expect(res.ok).toBe(false)
    if (!res.ok) expect(res.reason).toBe('stale_timestamp')
  })

  it('rejects a missing signature header', async () => {
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: null,
      timestampHeader: timestampSeconds,
      now: nowMs,
    })
    expect(res.ok).toBe(false)
    if (!res.ok) expect(res.reason).toBe('missing_signature')
  })

  it('rejects a missing timestamp header', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: sig,
      timestampHeader: null,
      now: nowMs,
    })
    expect(res.ok).toBe(false)
    if (!res.ok) expect(res.reason).toBe('missing_timestamp')
  })

  it('accepts ms-precision timestamps as well as seconds', async () => {
    const sig = await hmacSha256Hex(SECRET, BODY)
    const res = await verifySentryWebhook({
      secret: SECRET,
      rawBody: BODY,
      signatureHeader: sig,
      timestampHeader: String(nowMs),
      now: nowMs,
    })
    expect(res.ok).toBe(true)
  })
})
