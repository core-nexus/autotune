import type { Breadcrumb, Frame, Level, Normalized, Trigger } from './types.js'

const TAG_WHITELIST = new Set([
  'browser',
  'browser.name',
  'os',
  'os.name',
  'runtime',
  'runtime.name',
  'url',
  'transaction',
  'environment',
  'release',
  'user.id',
  'user.email',
  'level',
  'handled',
  'mechanism',
  'server_name',
])

const PII_TAG_KEYS = new Set(['user.email', 'user.ip_address'])

const VALID_LEVELS: ReadonlySet<Level> = new Set<Level>([
  'fatal',
  'error',
  'warning',
  'info',
  'debug',
])

export type NormalizeOptions = {
  dispatchId: string
  redactPii?: boolean
}

export class NormalizeError extends Error {}

function asString(v: unknown): string | null {
  return typeof v === 'string' && v.length > 0 ? v : null
}

function asNumber(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v
  if (typeof v === 'string') {
    const n = Number(v)
    return Number.isFinite(n) ? n : null
  }
  return null
}

function asLevel(v: unknown): Level {
  if (typeof v === 'string' && VALID_LEVELS.has(v as Level)) return v as Level
  return 'error'
}

function truncate(s: string | null, n: number): string | null {
  if (s === null) return null
  return s.length > n ? s.slice(0, n) : s
}

type RawFrame = {
  filename?: unknown
  abs_path?: unknown
  function?: unknown
  lineno?: unknown
  colno?: unknown
  in_app?: unknown
  context_line?: unknown
}

function normalizeFrames(rawFrames: RawFrame[] | undefined): Frame[] {
  if (!Array.isArray(rawFrames) || rawFrames.length === 0) return []
  // Sentry orders frames from oldest → newest. We want the most recent first.
  const reversed = [...rawFrames].reverse()
  const mapFrame = (f: RawFrame): Frame => ({
    filename: asString(f.filename) ?? asString(f.abs_path),
    function: asString(f.function),
    lineNo: asNumber(f.lineno),
    colNo: asNumber(f.colno),
    inApp: f.in_app === true,
    contextLine: truncate(asString(f.context_line), 200),
  })
  const mapped = reversed.map(mapFrame)
  const inApp = mapped.filter((f) => f.inApp)
  if (inApp.length >= 10) return inApp.slice(0, 10)
  const rest = mapped.filter((f) => !f.inApp)
  return [...inApp, ...rest].slice(0, 10)
}

function extractFrames(event: Record<string, unknown> | null): Frame[] {
  if (!event) return []
  const exception = (event.exception ?? null) as Record<string, unknown> | null
  const values = (exception?.values ?? null) as Array<Record<string, unknown>> | null
  if (!values || values.length === 0) return []
  // Sentry convention: the last entry in values is the innermost exception.
  const last = values[values.length - 1]!
  const stacktrace = (last.stacktrace ?? null) as Record<string, unknown> | null
  const frames = (stacktrace?.frames ?? null) as RawFrame[] | null
  return normalizeFrames(frames ?? undefined)
}

function extractException(
  event: Record<string, unknown> | null,
): { type: string; value: string } | null {
  if (!event) return null
  const exception = (event.exception ?? null) as Record<string, unknown> | null
  const values = (exception?.values ?? null) as Array<Record<string, unknown>> | null
  if (!values || values.length === 0) return null
  const last = values[values.length - 1]!
  const type = asString(last.type)
  const value = asString(last.value)
  if (type === null && value === null) return null
  return { type: type ?? '', value: value ?? '' }
}

function extractBreadcrumbs(event: Record<string, unknown> | null): Breadcrumb[] {
  if (!event) return []
  const bc = (event.breadcrumbs ?? null) as Record<string, unknown> | Array<unknown> | null
  let values: Array<Record<string, unknown>> | null = null
  if (Array.isArray(bc)) {
    values = bc as Array<Record<string, unknown>>
  } else if (bc && typeof bc === 'object') {
    const v = (bc as Record<string, unknown>).values
    if (Array.isArray(v)) values = v as Array<Record<string, unknown>>
  }
  if (!values || values.length === 0) return []
  const last10 = values.slice(-10)
  return last10.map((b) => ({
    category: asString(b.category),
    level: asString(b.level),
    message: truncate(asString(b.message), 200),
    timestamp: (() => {
      if (typeof b.timestamp === 'number' && Number.isFinite(b.timestamp)) {
        return new Date(b.timestamp * 1000).toISOString()
      }
      return asString(b.timestamp)
    })(),
  }))
}

function extractTags(
  event: Record<string, unknown> | null,
  issue: Record<string, unknown> | null,
  redactPii: boolean,
): Record<string, string> {
  const out: Record<string, string> = {}
  const rawTags: unknown = event?.tags ?? issue?.tags ?? null
  if (Array.isArray(rawTags)) {
    for (const pair of rawTags) {
      if (Array.isArray(pair) && pair.length >= 2) {
        const k = pair[0]
        const v = pair[1]
        if (typeof k === 'string' && typeof v === 'string') {
          if (!TAG_WHITELIST.has(k)) continue
          if (redactPii && PII_TAG_KEYS.has(k)) continue
          out[k] = v
        }
      }
    }
  } else if (rawTags && typeof rawTags === 'object') {
    for (const [k, v] of Object.entries(rawTags as Record<string, unknown>)) {
      if (typeof v !== 'string') continue
      if (!TAG_WHITELIST.has(k)) continue
      if (redactPii && PII_TAG_KEYS.has(k)) continue
      out[k] = v
    }
  }
  return out
}

// Best-effort: derive {org, project} slugs from a Sentry URL like
// "https://<org>.sentry.io/organizations/<org>/issues/<id>/..."
// or "https://sentry.io/organizations/<org>/projects/<project>/..."
function slugsFromUrl(url: string | null): { orgSlug: string | null; projectSlug: string | null } {
  if (!url) return { orgSlug: null, projectSlug: null }
  try {
    const u = new URL(url)
    const parts = u.pathname.split('/').filter(Boolean)
    let orgSlug: string | null = null
    let projectSlug: string | null = null
    const orgIdx = parts.indexOf('organizations')
    if (orgIdx >= 0 && parts[orgIdx + 1]) orgSlug = parts[orgIdx + 1]!
    const projIdx = parts.indexOf('projects')
    if (projIdx >= 0 && parts[projIdx + 1]) {
      // API URL shape is /api/0/projects/{org}/{project}/..., so the slug
      // right after "projects" is the org and the one after is the project.
      // Web URL shape is /organizations/{org}/projects/{project}/..., so the
      // slug after "projects" is the project directly.
      const isApiUrl = parts[0] === 'api'
      if (isApiUrl) {
        if (!orgSlug) orgSlug = parts[projIdx + 1]!
        if (parts[projIdx + 2]) projectSlug = parts[projIdx + 2]!
      } else {
        projectSlug = parts[projIdx + 1]!
      }
    }
    // Fallback: subdomain like "<org>.sentry.io"
    if (!orgSlug) {
      const host = u.hostname
      if (host.endsWith('.sentry.io')) {
        const sub = host.slice(0, -'.sentry.io'.length)
        if (sub && sub !== 'www') orgSlug = sub
      }
    }
    return { orgSlug, projectSlug }
  } catch {
    return { orgSlug: null, projectSlug: null }
  }
}

function mapIssueAction(action: string | null): Trigger {
  switch (action) {
    case 'created':
      return 'created'
    case 'unresolved':
      return 'regressed'
    case 'escalating':
      return 'escalated'
    default:
      return 'other'
  }
}

export type NormalizeResult =
  | { kind: 'normalized'; data: Normalized }
  | { kind: 'skip'; reason: string }

export function normalize(
  resource: string,
  payload: unknown,
  opts: NormalizeOptions,
): NormalizeResult {
  if (resource !== 'event_alert' && resource !== 'issue') {
    return { kind: 'skip', reason: 'unsupported_resource' }
  }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    return { kind: 'skip', reason: 'payload_not_object' }
  }
  const root = payload as Record<string, unknown>
  const action = asString(root.action)
  const data = (root.data ?? null) as Record<string, unknown> | null
  if (!data) return { kind: 'skip', reason: 'missing_data' }

  const redactPii = opts.redactPii !== false

  if (resource === 'event_alert') {
    const event = (data.event ?? null) as Record<string, unknown> | null
    if (!event) return { kind: 'skip', reason: 'missing_event' }
    const issueUrl = asString(event.issue_url) ?? asString(event.web_url) ?? asString(event.url)
    const eventUrl = asString(event.web_url)
    const apiUrl = asString(event.url)
    const urlCandidates = [issueUrl, eventUrl, apiUrl]
    let orgFromUrl: string | null = null
    let projectFromUrl: string | null = null
    for (const candidate of urlCandidates) {
      const parsed = slugsFromUrl(candidate)
      orgFromUrl ??= parsed.orgSlug
      projectFromUrl ??= parsed.projectSlug
      if (orgFromUrl && projectFromUrl) break
    }
    const project = (event.project ?? null) as Record<string, unknown> | null
    const orgSlug =
      asString(root.actor ? (root.actor as Record<string, unknown>).organization_slug : null) ??
      asString(project?.organization_slug) ??
      orgFromUrl
    const projectSlug = asString(event.project_slug) ?? asString(project?.slug) ?? projectFromUrl
    if (!orgSlug || !projectSlug) {
      return { kind: 'skip', reason: 'missing_slugs' }
    }
    const shortId = asString(event.issue_id) ? asString(event.issue_id)! : asString(event.event_id)!
    const issueIdRaw =
      asString(event.issue_id) ??
      asString(event.groupID) ??
      asString((event.metadata as Record<string, unknown> | null)?.issue_id) ??
      ''
    const issueId = issueIdRaw
    const latestEventId = asString(event.event_id)
    const sentryIssueUrl =
      issueUrl ??
      `https://${orgSlug}.sentry.io/issues/${issueId || shortId}/`
    const sentryEventUrl =
      eventUrl ??
      (latestEventId
        ? `https://${orgSlug}.sentry.io/issues/${issueId || shortId}/events/${latestEventId}/`
        : null)
    const sentryApiEventUrl =
      latestEventId && projectSlug
        ? `https://sentry.io/api/0/projects/${orgSlug}/${projectSlug}/events/${latestEventId}/`
        : null
    const normalized: Normalized = {
      projectSlug,
      orgSlug,
      shortId: asString(event.issue_id) ?? shortId,
      issueId: issueId || shortId,
      title: asString(event.title) ?? asString(event.message) ?? '(no title)',
      culprit: asString(event.culprit),
      level: asLevel(event.level),
      platform: asString(event.platform) ?? 'unknown',
      environment: asString(event.environment),
      release: asString(event.release),
      firstSeen: null,
      lastSeen: asString(event.datetime) ?? asString(event.received),
      count: null,
      userCount: null,
      issueType: asString(event.type),
      issueCategory: null,
      sentryIssueUrl,
      sentryEventUrl,
      sentryApiEventUrl,
      latestEventId,
      triggeredRule: asString(data.triggered_rule),
      trigger: 'event_alert',
      exception: extractException(event),
      topFrames: extractFrames(event),
      breadcrumbs: extractBreadcrumbs(event),
      tags: extractTags(event, null, redactPii),
      dispatchId: opts.dispatchId,
    }
    return { kind: 'normalized', data: normalized }
  }

  if (resource === 'issue') {
    const issue = (data.issue ?? null) as Record<string, unknown> | null
    if (!issue) return { kind: 'skip', reason: 'missing_issue' }
    const project = (issue.project ?? null) as Record<string, unknown> | null
    const organization = (issue.organization ?? null) as Record<string, unknown> | null
    const permalink = asString(issue.permalink) ?? asString(issue.web_url)
    const { orgSlug: orgFromUrl, projectSlug: projectFromUrl } = slugsFromUrl(permalink)
    const projectSlug = asString(project?.slug) ?? projectFromUrl
    const orgSlug = asString(organization?.slug) ?? orgFromUrl
    if (!orgSlug || !projectSlug) {
      return { kind: 'skip', reason: 'missing_slugs' }
    }
    const shortId = asString(issue.shortId) ?? asString(issue.short_id) ?? ''
    const issueId = asString(issue.id) ?? shortId
    if (!issueId) return { kind: 'skip', reason: 'missing_issue_id' }
    const trigger = mapIssueAction(action)
    const sentryIssueUrl =
      permalink ?? `https://${orgSlug}.sentry.io/issues/${issueId}/`
    const normalized: Normalized = {
      projectSlug,
      orgSlug,
      shortId: shortId || issueId,
      issueId,
      title: asString(issue.title) ?? '(no title)',
      culprit: asString(issue.culprit),
      level: asLevel(issue.level),
      platform: asString(issue.platform) ?? asString(project?.platform) ?? 'unknown',
      environment: null,
      release: null,
      firstSeen: asString(issue.firstSeen) ?? asString(issue.first_seen),
      lastSeen: asString(issue.lastSeen) ?? asString(issue.last_seen),
      count: asNumber(issue.count),
      userCount: asNumber(issue.userCount) ?? asNumber(issue.user_count),
      issueType: asString(issue.type),
      issueCategory: asString(issue.issueCategory) ?? asString(issue.issue_category),
      sentryIssueUrl,
      sentryEventUrl: null,
      sentryApiEventUrl: null,
      latestEventId: null,
      triggeredRule: null,
      trigger,
      exception: null,
      topFrames: [],
      breadcrumbs: [],
      tags: extractTags(null, issue, redactPii),
      dispatchId: opts.dispatchId,
    }
    return { kind: 'normalized', data: normalized }
  }

  return { kind: 'skip', reason: 'unsupported_resource' }
}
