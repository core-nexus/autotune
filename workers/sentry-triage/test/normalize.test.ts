import { describe, expect, it } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { normalize } from '../src/normalize.js'

const here = dirname(fileURLToPath(import.meta.url))
const fx = (name: string): unknown =>
  JSON.parse(readFileSync(join(here, 'fixtures', name), 'utf8'))

const DISPATCH_ID = 'dispatch-0000'

describe('normalize event_alert', () => {
  it('produces the expected normalized shape', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
      redactPii: true,
    })
    expect(result.kind).toBe('normalized')
    if (result.kind !== 'normalized') return
    const n = result.data
    expect(n.projectSlug).toBe('web')
    expect(n.orgSlug).toBe('acme')
    expect(n.shortId).toBe('WEB-4F2')
    expect(n.title).toContain('TypeError')
    expect(n.level).toBe('error')
    expect(n.platform).toBe('javascript')
    expect(n.environment).toBe('production')
    expect(n.release).toBe('web@1.2.3')
    expect(n.trigger).toBe('event_alert')
    expect(n.triggeredRule).toBe('High Priority Errors')
    expect(n.dispatchId).toBe(DISPATCH_ID)
    expect(n.latestEventId).toBe('abc123abc123abc123abc123abc12345')
    expect(n.sentryIssueUrl).toMatch(/sentry\.io/)
    expect(n.sentryEventUrl).toMatch(/abc123/)
    expect(n.sentryApiEventUrl).toMatch(/^https:\/\/sentry\.io\/api\/0\/projects\/acme\/web\/events\//)
  })

  it('extracts the exception type and value', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    expect(result.data.exception).toEqual({
      type: 'TypeError',
      value: "Cannot read properties of undefined (reading 'foo')",
    })
  })

  it('prefers in_app frames and reverses order so newest is first', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    const frames = result.data.topFrames
    // Two in-app frames come first.
    expect(frames[0]?.inApp).toBe(true)
    expect(frames[1]?.inApp).toBe(true)
    // src/index.ts should be first after reversal (it was last in source list).
    expect(frames[0]?.filename).toBe('src/index.ts')
    expect(frames[1]?.filename).toBe('src/foo.ts')
    // Non-in-app fills after.
    expect(frames[2]?.inApp).toBe(false)
    expect(frames[2]?.filename).toBe('node_modules/framework/runtime.js')
  })

  it('extracts breadcrumbs with ISO timestamps', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    const bc = result.data.breadcrumbs
    expect(bc).toHaveLength(3)
    expect(bc[0]?.category).toBe('navigation')
    expect(bc[0]?.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/)
  })

  it('whitelists tags and drops PII when redactPii is true', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
      redactPii: true,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    expect(result.data.tags.environment).toBe('production')
    expect(result.data.tags.release).toBe('web@1.2.3')
    expect(result.data.tags['browser.name']).toBe('Chrome')
    expect(result.data.tags['user.email']).toBeUndefined()
    expect(result.data.tags['internal.secret_tag']).toBeUndefined()
  })

  it('keeps user.email when redactPii is false', () => {
    const result = normalize('event_alert', fx('event_alert.json'), {
      dispatchId: DISPATCH_ID,
      redactPii: false,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    expect(result.data.tags['user.email']).toBe('alice@example.com')
  })
})

describe('normalize issue', () => {
  it('maps action=created to trigger=created', () => {
    const result = normalize('issue', fx('issue_created.json'), {
      dispatchId: DISPATCH_ID,
    })
    expect(result.kind).toBe('normalized')
    if (result.kind !== 'normalized') return
    expect(result.data.trigger).toBe('created')
    expect(result.data.projectSlug).toBe('web')
    expect(result.data.orgSlug).toBe('acme')
    expect(result.data.shortId).toBe('WEB-4F2')
    expect(result.data.issueId).toBe('1234567890')
    expect(result.data.count).toBe(3)
    expect(result.data.userCount).toBe(1)
    expect(result.data.firstSeen).toBe('2025-04-22T12:00:00Z')
    expect(result.data.topFrames).toEqual([])
    expect(result.data.breadcrumbs).toEqual([])
  })

  it('maps action=unresolved to trigger=regressed', () => {
    const result = normalize('issue', fx('issue_unresolved.json'), {
      dispatchId: DISPATCH_ID,
    })
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    expect(result.data.trigger).toBe('regressed')
  })

  it('returns skip when the resource is unknown', () => {
    const result = normalize('unknown', {}, { dispatchId: DISPATCH_ID })
    expect(result).toEqual({ kind: 'skip', reason: 'unsupported_resource' })
  })

  it('returns skip when the payload is missing data', () => {
    const result = normalize('issue', { action: 'created' }, { dispatchId: DISPATCH_ID })
    expect(result.kind).toBe('skip')
  })

  it('maps assigned/archived actions to trigger=other', () => {
    const result = normalize(
      'issue',
      {
        action: 'assigned',
        data: {
          issue: {
            id: '1',
            shortId: 'X-1',
            title: 't',
            level: 'error',
            platform: 'node',
            project: { slug: 'web' },
            organization: { slug: 'acme' },
          },
        },
      },
      { dispatchId: DISPATCH_ID },
    )
    if (result.kind !== 'normalized') throw new Error('expected normalized')
    expect(result.data.trigger).toBe('other')
  })
})
