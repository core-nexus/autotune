# Security & Authorization Review

## Objective

Deep-dive security audit of the entire codebase, focused on authentication,
authorization, injection, secrets, and attack surface reduction.

## Review Checklist

### Authentication & Session Management

- [ ] Every API endpoint or server function that accesses user data verifies
      the user's identity and handles the unauthenticated case
- [ ] Session tokens are not exposed in URLs, logs, or client-side storage
      beyond what the auth library requires
- [ ] Auth callbacks validate redirect URIs to prevent open redirect attacks
- [ ] Password/credential handling follows best practices (hashing, no plaintext)
- [ ] Token expiration and refresh logic is correctly implemented

### Authorization & Access Control

- [ ] Admin-only functions enforce admin access without exception
- [ ] Ownership checks: users cannot read or modify other users' data
  - Payment sessions, billing info, subscriptions
  - Profile fields, user content, collections
  - Private content respects visibility/permission settings
- [ ] Internal/server-only functions are never exposed as public endpoints
- [ ] Rate limiting exists and cannot be bypassed
- [ ] Role-based or permission-based access is consistently enforced

### Input Validation & Injection

- [ ] All user inputs are validated and sanitized
- [ ] No raw string interpolation into queries, commands, or HTML
- [ ] No unescaped user content rendered as HTML (XSS)
- [ ] URL parameters and query strings are validated before use
- [ ] File uploads validate type, size, and content
- [ ] SQL/NoSQL injection vectors are eliminated through parameterized queries

### Secrets & Configuration

- [ ] No API keys, tokens, or credentials committed to source
  - Check for hardcoded keys in code files
  - Check environment variable example files vs actual patterns
- [ ] Environment detection is FAIL-CLOSED: unknown environment = production
- [ ] API keys use correct prefix for the environment (test vs live)
- [ ] No logging of sensitive data (tokens, emails, PII, credentials)

### OWASP Top 10 Considerations

- [ ] A01 Broken Access Control — covered by auth/authz checks above
- [ ] A02 Cryptographic Failures — proper use of crypto APIs, no weak algorithms
- [ ] A03 Injection — covered by input validation above
- [ ] A04 Insecure Design — check for security anti-patterns in architecture
- [ ] A05 Security Misconfiguration — headers, CORS, CSP, deployment config
- [ ] A06 Vulnerable Components — flag any known-vulnerable dependency versions
- [ ] A07 Authentication Failures — covered by auth section above
- [ ] A08 Software/Data Integrity — verify CI/CD integrity, dependency pinning
- [ ] A09 Logging/Monitoring Failures — ensure security events are logged
- [ ] A10 SSRF — validate any server-side URL fetching

### API & Webhook Security

- [ ] HTTP endpoints validate origin and authenticate requests
- [ ] Scheduled/cron functions don't have exploitable timing windows
- [ ] File storage URLs are scoped appropriately
- [ ] Webhook handlers verify signatures (Stripe, etc.)
- [ ] GraphQL/REST endpoints enforce query depth and complexity limits

## Reporting Guardrail

When you report a finding that involves a concrete secret, credential, token,
private key, or a real PII value, refer to it ONLY by location and type — e.g.
"hardcoded API key at `path:line`". NEVER paste, quote, or closely paraphrase
the literal value into an issue, comment, or PR body. Review outputs are visible
to everyone with repo access (on public repos, the entire internet), so
reproducing a discovered secret there converts a contained leak into a broadcast
one. Keep findings actionable by location without amplifying the exposure.

## Severity Guide

- **CRITICAL**: Auth bypass, data exposure, secret leak, injection vulnerability
- **HIGH**: Missing ownership check, unvalidated admin action, SSRF vector
- **MEDIUM**: Missing rate limit, overly permissive CORS, weak input validation
- **LOW**: Informational logging of non-sensitive data, minor config hardening
