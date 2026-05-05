import { describe, expect, it } from 'vitest'
import { fitClientPayload, MAX_CLIENT_PAYLOAD_BYTES } from '../src/payload.js'
import type { Normalized } from '../src/types.js'

function makeNormalized(overrides: Partial<Normalized> = {}): Normalized {
  return {
    projectSlug: 'web',
    orgSlug: 'acme',
    shortId: 'WEB-1',
    issueId: '1',
    title: 't',
    culprit: null,
    level: 'error',
    platform: 'javascript',
    environment: null,
    release: null,
    firstSeen: null,
    lastSeen: null,
    count: 1,
    userCount: null,
    issueType: null,
    issueCategory: null,
    sentryIssueUrl: 'https://sentry.io/',
    sentryEventUrl: null,
    sentryApiEventUrl: null,
    latestEventId: null,
    triggeredRule: null,
    trigger: 'created',
    exception: null,
    topFrames: [],
    breadcrumbs: [],
    tags: {},
    dispatchId: 'd',
    ...overrides,
  }
}

const size = (o: unknown) => new TextEncoder().encode(JSON.stringify(o)).length

describe('fitClientPayload', () => {
  it('returns the input unchanged when already small', () => {
    const n = makeNormalized()
    expect(fitClientPayload(n)).toEqual(n)
  })

  it('drops breadcrumbs first when over-budget', () => {
    const bigCrumb = {
      category: 'x',
      level: 'info',
      message: 'a'.repeat(200),
      timestamp: '2025-01-01T00:00:00Z',
    }
    const n = makeNormalized({
      breadcrumbs: Array.from({ length: 50 }, () => ({ ...bigCrumb })),
    })
    expect(size(n)).toBeGreaterThan(MAX_CLIENT_PAYLOAD_BYTES)
    const out = fitClientPayload(n)
    expect(out.breadcrumbs).toEqual([])
    expect(size(out)).toBeLessThanOrEqual(MAX_CLIENT_PAYLOAD_BYTES)
  })

  it('always preserves URLs and IDs even after aggressive shrink', () => {
    const bigFrame = {
      filename: 'src/x.ts',
      function: 'f',
      lineNo: 1,
      colNo: 1,
      inApp: true,
      contextLine: 'a'.repeat(200),
    }
    const bigTags: Record<string, string> = {}
    for (let i = 0; i < 100; i++) bigTags[`tag${i}`] = 'a'.repeat(200)
    const n = makeNormalized({
      sentryIssueUrl: 'https://sentry.io/keep-me/',
      shortId: 'WEB-KEEP',
      issueId: 'KEEP-123',
      topFrames: Array.from({ length: 20 }, () => ({ ...bigFrame })),
      tags: bigTags,
      breadcrumbs: Array.from({ length: 50 }, () => ({
        category: 'x',
        level: 'info',
        message: 'y'.repeat(200),
        timestamp: '2025-01-01T00:00:00Z',
      })),
    })
    const out = fitClientPayload(n)
    expect(out.sentryIssueUrl).toBe('https://sentry.io/keep-me/')
    expect(out.shortId).toBe('WEB-KEEP')
    expect(out.issueId).toBe('KEEP-123')
    expect(size(out)).toBeLessThanOrEqual(MAX_CLIENT_PAYLOAD_BYTES)
  })
})
