# Scalability & Performance Review

## Objective

Deep audit for performance bottlenecks and scalability issues. This review
ensures the codebase can handle significant growth in users and data volume.

For every pattern you review, ask: "Does this work at 10x the current load?
At 100x?" If the answer is "no" at any scale, flag it.

## Scaling Context

At low traffic, many inefficiencies are invisible. At 10x scale:

- Database tables are 10x larger. Full table scans that took 50ms now take 500ms.
- Concurrent writes increase 10x. Hot-spot documents become write bottlenecks.
- Real-time subscriptions/WebSocket connections multiply with connected clients.
- API calls to external services increase proportionally.
- Server/CDN invocations and bandwidth scale with traffic.

At 100x scale:

- Any O(n) scan becomes a real problem. Indexes are mandatory, not optional.
- N+1 query patterns that worked fine with 10 items now fire 1,000 queries.
- Memory usage on the client matters — mobile users with limited RAM.
- Connection limits for real-time features approach infrastructure limits.
- Cost scales linearly (or worse) with every unoptimized external API call.

## Review Checklist

### Database Query Performance (HIGHEST PRIORITY)

- [ ] **Index coverage audit**: For every unindexed filter/query:
  - What table is it on?
  - How many rows will that table have at 10x? At 100x?
  - If >1,000 rows possible: this MUST use an index
- [ ] **N+1 query detection**: Search for patterns where:
  - A query returns a list, then each item triggers another query
  - A loop contains a database query inside it
  - Multiple sequential lookups that could be batched
- [ ] **Unbounded result sets**: Queries without limits or pagination:
  - "Get all items for user" — fine at 5, broken at 500
  - "Get all members" — fine at 20, broken at 2,000
  - Every list query needs a limit or pagination strategy
- [ ] **Over-fetching**: Queries returning entire records when the client
      uses only a few fields — at scale, this wastes bandwidth and memory

### Write Performance

- [ ] **Write hot spots**: Records updated by many concurrent users
  - Global counters, aggregate stats, shared state
  - At scale, these become serialization bottlenecks
  - Fix: use sharding, per-user counters, or eventual consistency
- [ ] **Cascading writes**: One write triggering many downstream writes
  - At 10x scale, a cascade of 10 becomes a cascade of 100

### Frontend Performance

- [ ] **Main thread blocking**: Heavy computation in the render cycle
  - 3D rendering, data transformation, sorting/filtering large datasets
  - Fix: web workers, `requestAnimationFrame`, virtual scrolling
- [ ] **Bundle size**: Large dependencies that could be lazy-loaded
  - Verify tree-shaking is effective (no `import *` for large libraries)
  - At scale, every KB matters for mobile users on slow connections
- [ ] **Memory leaks**: Event listeners, timers, subscriptions not cleaned up
  - Growing arrays/maps that are never pruned
- [ ] **Virtual scrolling**: Any list that could have >50 items needs virtual
      scrolling (feeds, search results, member lists)
- [ ] **Image optimization**: Lazy loading, responsive sizing, modern formats

### Network Performance

- [ ] **Redundant API calls**: Components that each make their own query for shared data
- [ ] **Payload size**: Responses that grow with user count — need pagination
- [ ] **Waterfall requests**: Sequential calls that could be parallelized
- [ ] **Caching**: Frequently accessed reference data should be cached client-side

### Rate Limiting & Cost Control (CRITICAL AT SCALE)

- [ ] **User-facing rate limits**: Are limits appropriate for growth?
  - Can limits be bypassed by creating multiple accounts?
  - At 100x users, what's the worst-case cost if all hit limits?
- [ ] **External API costs**: Token limits, request caps
  - Calculate projected costs at 10x and 100x active users
  - Are there per-user daily/monthly caps?
- [ ] **Third-party API rate limits**: Could you hit provider rate limits at scale?

### Database Scalability

- [ ] **Table growth projections**: Which tables grow fastest? Which will hit
      100K rows first? 1M?
- [ ] **Index efficiency at scale**: Indexes with poor selectivity at large row counts
- [ ] **Data archival**: Tables that grow indefinitely need cleanup or archival
- [ ] **Pagination everywhere**: Any endpoint that returns a list must paginate

## Severity Guide

- **CRITICAL**: Full table scan on table that will exceed 10K rows, unbounded
  query with no pagination, O(n^2) algorithm on user data
- **HIGH**: N+1 pattern on growing data, missing rate limits, memory leaks,
  write hot spots that will serialize under load
- **MEDIUM**: Missing pagination on growing lists, large bundle size,
  redundant API calls, missing virtual scrolling
- **LOW**: Minor optimization opportunities, build performance, preloading hints
