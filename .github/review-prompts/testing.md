# Testing Coverage & Quality Review

## Objective

Audit test coverage, test quality, and adherence to testing best practices.
Focus on real code execution over mocking.

## Review Checklist

### Coverage Gaps

- [ ] **Backend functions without tests**: Every API endpoint, mutation, query,
      and server action should have corresponding tests
  - List all untested functions
  - Prioritize testing for functions that handle: auth, payments, data mutation
- [ ] **New features without tests**: Check recent commits/PRs for features
      that were merged without test coverage
- [ ] **Bug fixes without regression tests**: Every bug fix should have a test
      that would catch the bug if it recurred
- [ ] **Edge cases**: Happy path tested but error/edge cases missing:
  - Unauthenticated users
  - Empty/null inputs
  - Rate-limited scenarios
  - Concurrent operations
  - Boundary values

### Mock Discipline

**Prefer exercising real code over mocking. Only mock at external boundaries.**

- [ ] **No internal mocks**: Tests should not mock your own modules or functions.
      If internal code is mocked, the test verifies assumptions, not behavior.
- [ ] **Only external boundary mocks**: The ONLY acceptable mocks are:
  - Third-party API clients (Stripe, payment processors, email services)
  - `fetch` calls to external HTTP APIs
  - External CDN/storage URL constants
- [ ] **No `vi.fn()` / `jest.fn()` replacing internal functions**: If a test
      replaces a real function from your codebase with a mock, that's a red flag
- [ ] **Real database/backend testing**: Tests should exercise real data operations,
      not mocked data layers

### Test Quality

- [ ] **Tests exercise real code paths**: Not just checking mocked return values
- [ ] **Assertions are meaningful**: Not just `expect(result).toBeDefined()`
  - Assert specific values, structures, and side effects
  - Check database/store state after mutations
  - Verify error types and messages
- [ ] **Test descriptions are clear**: `it('should ...')` describes the behavior
- [ ] **No flaky tests**: Tests that sometimes pass and sometimes fail
- [ ] **No skipped tests**: `it.skip()` or `describe.skip()` without explanation
- [ ] **Tests don't test implementation details**: Focus on behavior, not internals

### Test Organization

- [ ] Tests mirror source structure
- [ ] Shared test helpers are in appropriate utility files
- [ ] Test data setup is clear and minimal
- [ ] No test pollution: each test is independent

### E2E Tests

- [ ] Smoke test coverage for critical user journeys:
  - Sign up / sign in
  - Profile creation and editing
  - Core feature interactions
  - Payment/checkout flows
- [ ] E2E tests fail on JS errors and `console.error`
- [ ] Test count is reasonable (not excessive — think smoke tests)
- [ ] Fixtures and setup follow established patterns

### Missing Test Categories

Identify and flag gaps in any of these:

- [ ] Authorization tests (can user X access resource Y?)
- [ ] Input validation tests (do validators reject bad input?)
- [ ] Error handling tests (do errors propagate correctly?)
- [ ] Concurrent operation tests (race conditions?)
- [ ] Data migration/schema change tests

## Shell / Infrastructure Repos

The checklist above assumes a JS/TS (Vitest/Jest) stack. For repos whose only
executable logic is Bash scripts or CI workflows (like this one), apply the same
principles with shell-appropriate tooling:

- **Test runner**: Use [Bats](https://bats-core.readthedocs.io/) (`bats-core`).
  Put tests under `tests/` mirroring the script layout, one `.bats` per script.
- **Boundary-only mocking**: The same "only mock external boundaries" rule
  applies. For shell, stub external CLIs (`gh`, `curl`, `aws`) by placing an
  executable of that name earlier on `PATH`. Never edit or replace the script's
  own internal logic — exercise the real script end to end.
- **Exit-code assertions**: Assert on `status` (exit code), on `stdout`/`stderr`
  content (`output`), and on files the script writes (e.g. `GITHUB_OUTPUT`).
  Verify the failure paths too: `set -euo pipefail` and `${VAR:?}` guards should
  produce non-zero exits on missing inputs.
- **Config drift**: Where a value is duplicated across scripts, workflow YAML,
  and docs, add a test asserting the copies stay in sync.
- **CI gate**: Lint with `shellcheck` (scripts) and `actionlint` (workflows) in
  addition to running the Bats suite.

## Severity Guide

- **CRITICAL**: Internal code being mocked, auth functions untested
- **HIGH**: Payment/billing functions untested, core features without coverage
- **MEDIUM**: Missing edge case tests, skipped tests, flaky tests
- **LOW**: Test organization improvements, assertion quality, description clarity
