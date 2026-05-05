import type { ProjectConfig, ProjectMap } from './types.js'

export class ConfigError extends Error {}

export function parseProjectMap(raw: string | undefined): ProjectMap {
  if (!raw || raw.trim() === '') {
    throw new ConfigError('PROJECT_MAP is required')
  }
  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (err) {
    throw new ConfigError(`PROJECT_MAP is not valid JSON: ${(err as Error).message}`)
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    throw new ConfigError('PROJECT_MAP must be a JSON object')
  }
  const out: ProjectMap = {}
  for (const [slug, value] of Object.entries(parsed as Record<string, unknown>)) {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      throw new ConfigError(`PROJECT_MAP["${slug}"] must be an object`)
    }
    const cfg = value as Record<string, unknown>
    if (typeof cfg.repo !== 'string' || !/^[^/\s]+\/[^/\s]+$/.test(cfg.repo)) {
      throw new ConfigError(`PROJECT_MAP["${slug}"].repo must be "owner/repo"`)
    }
    const eventType =
      typeof cfg.eventType === 'string' && cfg.eventType.length > 0
        ? cfg.eventType
        : 'sentry-triage'
    const entry: ProjectConfig = {
      repo: cfg.repo,
      eventType,
    }
    if (cfg.minEventCount !== undefined) {
      if (typeof cfg.minEventCount !== 'number' || cfg.minEventCount < 0) {
        throw new ConfigError(`PROJECT_MAP["${slug}"].minEventCount must be a non-negative number`)
      }
      entry.minEventCount = cfg.minEventCount
    }
    if (cfg.allowWarnings !== undefined) {
      if (typeof cfg.allowWarnings !== 'boolean') {
        throw new ConfigError(`PROJECT_MAP["${slug}"].allowWarnings must be boolean`)
      }
      entry.allowWarnings = cfg.allowWarnings
    }
    out[slug] = entry
  }
  return out
}

export function isTruthy(v: string | undefined, fallback: boolean): boolean {
  if (v === undefined || v === '') return fallback
  return v.toLowerCase() === 'true' || v === '1' || v.toLowerCase() === 'yes'
}
