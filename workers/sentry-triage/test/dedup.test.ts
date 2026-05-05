import { describe, expect, it } from 'vitest'
import { checkSeen, markSeen, dedupKey } from '../src/dedup.js'

class FakeKV {
  store = new Map<string, string>()
  async get(key: string): Promise<string | null> {
    return this.store.get(key) ?? null
  }
  async put(key: string, value: string, _opts?: unknown): Promise<void> {
    this.store.set(key, value)
  }
}

describe('dedup', () => {
  it('round-trips a seen record', async () => {
    const kv = new FakeKV()
    const record = {
      dispatchId: 'd-1',
      dispatchedAt: '2025-04-22T12:00:00Z',
      trigger: 'created' as const,
    }
    await markSeen(kv, 'web', 'WEB-1', record)
    const seen = await checkSeen(kv, 'web', 'WEB-1')
    expect(seen).toEqual(record)
  })

  it('returns null when not present', async () => {
    const kv = new FakeKV()
    expect(await checkSeen(kv, 'web', 'WEB-9')).toBeNull()
  })

  it('returns null when kv is undefined (bindless local dev)', async () => {
    expect(await checkSeen(undefined, 'web', 'WEB-1')).toBeNull()
    await markSeen(undefined, 'web', 'WEB-1', {
      dispatchId: 'd',
      dispatchedAt: 't',
      trigger: 'created',
    })
  })

  it('builds a deterministic key', () => {
    expect(dedupKey('web', 'WEB-1')).toBe('seen:web:WEB-1')
  })
})
