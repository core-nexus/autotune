import type { Normalized, ProjectConfig } from './types.js'

export type FilterInput = {
  normalized: Normalized
  projectConfig: ProjectConfig | undefined
  allowWarningsGlobal: boolean
}

export type FilterResult =
  | { pass: true }
  | { pass: false; reason: string }

export function filter(input: FilterInput): FilterResult {
  const { normalized: n, projectConfig, allowWarningsGlobal } = input

  if (!projectConfig) {
    return { pass: false, reason: 'unknown_project' }
  }

  if (n.trigger === 'other') {
    return { pass: false, reason: 'trigger_other' }
  }

  const allowWarnings = projectConfig.allowWarnings === true || allowWarningsGlobal === true
  if (n.level !== 'fatal' && n.level !== 'error') {
    if (!(n.level === 'warning' && allowWarnings)) {
      return { pass: false, reason: `level_${n.level}_not_allowed` }
    }
  }

  const minCount = projectConfig.minEventCount ?? 1
  const count = n.count ?? 1
  if (count < minCount) {
    return { pass: false, reason: `below_min_event_count` }
  }

  return { pass: true }
}
