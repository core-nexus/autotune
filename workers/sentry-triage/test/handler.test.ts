import { describe, expect, it, beforeEach } from 'vitest'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { handleRequest } from '../src/handler.js'
import { hmacSha256Hex } from '../src/signature.js'
import type { Env } from '../src/types.js'

const here = dirname(fileURLToPath(import.meta.url))
const fixture = (name: string): string =>
  readFileSync(join(here, 'fixtures', name), 'utf8')

const SECRET = 'shh-its-a-secret'
const NOW_MS = 1_745_323_200_000
const TS_SECONDS = String(NOW_MS / 1000)

const PROJECT_MAP = JSON.stringify({
  core: { repo: 'acme/web', eventType: 'sentry-triage' },
})

function baseEnv(): Env {
  return {
    SENTRY_CLIENT_SECRET: SECRET,
    PROJECT_MAP,
    GITHUB_PAT: 'ghp_testtoken',
    LOG_LEVEL: 'error', // keep test output quiet
    REDACT_PII: 'true',
    ALLOW_WARNINGS_GLOBAL: 'false',
  }
}

// In-memory KV that implements the subset of KVNamespace we use.
class FakeKV {
  store = new Map<string, string>()
  async get(key: string): Promise<string | null> {
    return this.store.get(key) ?? null
  }
  async put(key: string, value: string, _opts?: unknown): Promise<void> {
    this.store.set(key, value)
  }
}

async function signedRequest(
  body: string,
  resource: string,
  opts?: { secret?: string; timestamp?: string; url?: string; method?: string },
): Promise<Request> {
  const sig = await hmacSha256Hex(opts?.secret ?? SECRET, body)
  return new Request(opts?.url ?? 'https://worker.example.com/sentry/webhook', {
    method: opts?.method ?? 'POST',
    headers: {
      'content-type': 'application/json',
      'sentry-hook-resource': resource,
      'sentry-hook-timestamp': opts?.timestamp ?? TS_SECONDS,
      'sentry-hook-signature': sig,
    },
    body,
  })
}

type FetchCall = { url: string; init: RequestInit | undefined }

function makeFetchRecorder(status = 204): {
  fn: typeof fetch
  calls: FetchCall[]
} {
  const calls: FetchCall[] = []
  const fn: typeof fetch = async (url, init) => {
    calls.push({ url: String(url), init })
    return new Response(null, { status })
  }
  return { fn, calls }
}

describe('handler /health', () => {
  it('returns 200 for GET /health', async () => {
    const res = await handleRequest(
      new Request('https://w.test/health'),
      baseEnv(),
      undefined,
    )
    expect(res.status).toBe(200)
  })
})

describe('handler /sentry/webhook - validation', () => {
  it('rejects non-POST', async () => {
    const res = await handleRequest(
      new Request('https://w.test/sentry/webhook', { method: 'GET' }),
      baseEnv(),
      undefined,
    )
    expect(res.status).toBe(405)
  })

  it('rejects non-JSON content-type', async () => {
    const res = await handleRequest(
      new Request('https://w.test/sentry/webhook', {
        method: 'POST',
        headers: { 'content-type': 'text/plain' },
        body: 'hello',
      }),
      baseEnv(),
      undefined,
    )
    expect(res.status).toBe(415)
  })

  it('rejects when Sentry headers are missing', async () => {
    const res = await handleRequest(
      new Request('https://w.test/sentry/webhook', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: '{}',
      }),
      baseEnv(),
      undefined,
    )
    expect(res.status).toBe(400)
  })

  it('rejects a bad signature', async () => {
    const body = '{"action":"created"}'
    const req = await signedRequest(body, 'issue', { secret: 'wrong-secret' })
    const res = await handleRequest(req, baseEnv(), undefined, {
      now: () => NOW_MS,
    })
    expect(res.status).toBe(401)
  })

  it('rejects a stale timestamp', async () => {
    const body = fixture('issue_created.json')
    const req = await signedRequest(body, 'issue', {
      timestamp: String(NOW_MS / 1000 - 600),
    })
    const res = await handleRequest(req, baseEnv(), undefined, {
      now: () => NOW_MS,
    })
    expect(res.status).toBe(401)
  })

  it('returns 404 for unknown paths', async () => {
    const res = await handleRequest(
      new Request('https://w.test/nope', { method: 'POST' }),
      baseEnv(),
      undefined,
    )
    expect(res.status).toBe(404)
  })
})

describe('handler /sentry/webhook - routing', () => {
  let fetchRecorder: ReturnType<typeof makeFetchRecorder>
  let kv: FakeKV

  beforeEach(() => {
    fetchRecorder = makeFetchRecorder(204)
    kv = new FakeKV()
  })

  it('dispatches an event_alert to GitHub', async () => {
    const body = fixture('event_alert.json')
    const req = await signedRequest(body, 'event_alert')
    const env = { ...baseEnv(), SENTRY_SEEN: kv as unknown as KVNamespace }
    const res = await handleRequest(req, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(202)
    const json = (await res.json()) as { status: string; dispatchId: string }
    expect(json.status).toBe('dispatched')
    expect(fetchRecorder.calls).toHaveLength(1)
    const call = fetchRecorder.calls[0]!
    expect(call.url).toBe('https://api.github.com/repos/acme/web/dispatches')
    const posted = JSON.parse(String(call.init?.body))
    expect(posted.event_type).toBe('sentry-triage')
    expect(posted.client_payload.shortId).toBe('WEB-4F2')
    const postedData = JSON.parse(posted.client_payload.data)
    expect(postedData.projectSlug).toBe('core')
    expect(postedData.trigger).toBe('event_alert')
    // KV got populated.
    expect(kv.store.size).toBe(1)
  })

  it('drops when the project is not in PROJECT_MAP', async () => {
    const body = fixture('event_alert.json')
    const req = await signedRequest(body, 'event_alert')
    const env = {
      ...baseEnv(),
      PROJECT_MAP: JSON.stringify({
        other: { repo: 'acme/other', eventType: 'sentry-triage' },
      }),
    }
    const res = await handleRequest(req, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(200)
    const json = (await res.json()) as { status: string; reason: string }
    expect(json.status).toBe('filtered')
    expect(json.reason).toBe('unknown_project')
    expect(fetchRecorder.calls).toHaveLength(0)
  })

  it('accept-ignores metric_alert without dispatching', async () => {
    const body = JSON.stringify({ action: 'triggered', data: {} })
    const req = await signedRequest(body, 'metric_alert')
    const res = await handleRequest(req, baseEnv(), undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(200)
    const json = (await res.json()) as { status: string }
    expect(json.status).toBe('filtered')
    expect(fetchRecorder.calls).toHaveLength(0)
  })

  it('accept-ignores an unknown resource type', async () => {
    const body = JSON.stringify({ action: 'whatever', data: {} })
    const req = await signedRequest(body, 'unknown_resource')
    const res = await handleRequest(req, baseEnv(), undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(200)
    expect(fetchRecorder.calls).toHaveLength(0)
  })

  it('drops an issue with action=assigned (trigger=other)', async () => {
    const body = JSON.stringify({
      action: 'assigned',
      data: {
        issue: {
          id: '1',
          shortId: 'WEB-X',
          title: 't',
          level: 'error',
          platform: 'node',
          project: { slug: 'core' },
          organization: { slug: 'acme' },
        },
      },
    })
    const req = await signedRequest(body, 'issue')
    const res = await handleRequest(req, baseEnv(), undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(200)
    const json = (await res.json()) as { status: string; reason: string }
    expect(json.status).toBe('filtered')
    expect(json.reason).toBe('trigger_other')
    expect(fetchRecorder.calls).toHaveLength(0)
  })

  it('returns 502 when GitHub dispatch fails', async () => {
    const failingFetch = makeFetchRecorder(500)
    const body = fixture('event_alert.json')
    const req = await signedRequest(body, 'event_alert')
    const res = await handleRequest(req, baseEnv(), undefined, {
      fetchFn: failingFetch.fn,
      now: () => NOW_MS,
    })
    expect(res.status).toBe(502)
  })
})

describe('handler /sentry/webhook - dedup', () => {
  it('returns deduped on the second request within TTL', async () => {
    const fetchRecorder = makeFetchRecorder(204)
    const kv = new FakeKV()
    const env = { ...baseEnv(), SENTRY_SEEN: kv as unknown as KVNamespace }
    const body = fixture('event_alert.json')
    const req1 = await signedRequest(body, 'event_alert')
    const res1 = await handleRequest(req1, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res1.status).toBe(202)
    expect(fetchRecorder.calls).toHaveLength(1)

    const req2 = await signedRequest(body, 'event_alert')
    const res2 = await handleRequest(req2, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res2.status).toBe(200)
    const json2 = (await res2.json()) as { status: string }
    expect(json2.status).toBe('deduped')
    // No second GitHub call.
    expect(fetchRecorder.calls).toHaveLength(1)
  })

  it('bypasses dedup for a regression (issue unresolved)', async () => {
    const fetchRecorder = makeFetchRecorder(204)
    const kv = new FakeKV()
    const env = { ...baseEnv(), SENTRY_SEEN: kv as unknown as KVNamespace }

    const createdBody = fixture('issue_created.json')
    const req1 = await signedRequest(createdBody, 'issue')
    const res1 = await handleRequest(req1, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res1.status).toBe(202)

    const unresolvedBody = fixture('issue_unresolved.json')
    const req2 = await signedRequest(unresolvedBody, 'issue')
    const res2 = await handleRequest(req2, env, undefined, {
      fetchFn: fetchRecorder.fn,
      now: () => NOW_MS,
    })
    expect(res2.status).toBe(202)
    expect(fetchRecorder.calls).toHaveLength(2)
    const posted = JSON.parse(String(fetchRecorder.calls[1]!.init?.body))
    const postedData = JSON.parse(posted.client_payload.data)
    expect(postedData.trigger).toBe('regressed')
  })
})
