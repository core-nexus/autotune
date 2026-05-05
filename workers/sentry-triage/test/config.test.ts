import { describe, expect, it } from 'vitest'
import { parseProjectMap, isTruthy, ConfigError } from '../src/config.js'

describe('parseProjectMap', () => {
  it('parses a valid map with defaults', () => {
    const map = parseProjectMap(
      JSON.stringify({
        web: { repo: 'acme/web', eventType: 'sentry-triage' },
        api: { repo: 'acme/api' },
      }),
    )
    expect(map.web).toEqual({ repo: 'acme/web', eventType: 'sentry-triage' })
    expect(map.api).toEqual({ repo: 'acme/api', eventType: 'sentry-triage' })
  })

  it('preserves minEventCount and allowWarnings', () => {
    const map = parseProjectMap(
      JSON.stringify({
        web: {
          repo: 'acme/web',
          eventType: 'sentry-triage',
          minEventCount: 5,
          allowWarnings: true,
        },
      }),
    )
    expect(map.web?.minEventCount).toBe(5)
    expect(map.web?.allowWarnings).toBe(true)
  })

  it('throws when missing', () => {
    expect(() => parseProjectMap(undefined)).toThrow(ConfigError)
    expect(() => parseProjectMap('')).toThrow(ConfigError)
  })

  it('throws on invalid JSON', () => {
    expect(() => parseProjectMap('{not json')).toThrow(ConfigError)
  })

  it('throws on non-object roots', () => {
    expect(() => parseProjectMap('[]')).toThrow(ConfigError)
    expect(() => parseProjectMap('"str"')).toThrow(ConfigError)
  })

  it('throws on bad repo shape', () => {
    expect(() => parseProjectMap(JSON.stringify({ web: { repo: 'bad' } }))).toThrow(ConfigError)
    expect(() => parseProjectMap(JSON.stringify({ web: { repo: 'a/b/c' } }))).toThrow(ConfigError)
  })

  it('throws on bad minEventCount', () => {
    expect(() =>
      parseProjectMap(JSON.stringify({ web: { repo: 'a/b', minEventCount: -1 } })),
    ).toThrow(ConfigError)
    expect(() =>
      parseProjectMap(JSON.stringify({ web: { repo: 'a/b', minEventCount: 'five' } })),
    ).toThrow(ConfigError)
  })
})

describe('isTruthy', () => {
  it('respects the fallback when unset', () => {
    expect(isTruthy(undefined, true)).toBe(true)
    expect(isTruthy(undefined, false)).toBe(false)
    expect(isTruthy('', true)).toBe(true)
  })
  it('recognizes common truthy strings', () => {
    expect(isTruthy('true', false)).toBe(true)
    expect(isTruthy('TRUE', false)).toBe(true)
    expect(isTruthy('1', false)).toBe(true)
    expect(isTruthy('yes', false)).toBe(true)
  })
  it('treats anything else as false', () => {
    expect(isTruthy('false', true)).toBe(false)
    expect(isTruthy('0', true)).toBe(false)
    expect(isTruthy('nope', true)).toBe(false)
  })
})
