# Dependency Health & Supply Chain Review

## Objective

Audit the project's dependency tree for security vulnerabilities, outdated
packages, license compliance, unused dependencies, and supply chain risks.

## Prerequisites

Before running any dependency commands, install dependencies first:

```bash
npm install  # or yarn install, pnpm install — use the project's package manager
```

## Review Checklist

### Vulnerability Scanning

- [ ] Run `npm audit` (or equivalent) and review all findings
- [ ] Categorize vulnerabilities by severity (critical, high, moderate, low)
- [ ] For each vulnerability:
  - Is there a patched version available? → Update
  - Is the vulnerable code path actually used by the app? → Assess real risk
  - Is there a workaround or alternative package? → Document
- [ ] Check if any dependencies have known supply chain attacks
- [ ] Verify no `postinstall` scripts do anything suspicious

### Outdated Dependencies

- [ ] Run `npm outdated` (or equivalent) and review the results
- [ ] **Critical updates** (security patches): update immediately
- [ ] **Minor/patch updates**: assess changelog for breaking changes
- [ ] **Major updates**: document what's needed for migration
- [ ] If Dependabot/Renovate is configured:
  - Are all dependency groups still valid?
  - Are any important packages missing from automation?

### Key Dependency Status

Review the health of the project's most critical dependencies:

- [ ] **Framework** (React, Vue, Svelte, Next.js, etc.) — version, known issues
- [ ] **Backend** (Express, Fastify, database clients, etc.) — version, deprecations
- [ ] **Auth** — security patches, version alignment
- [ ] **Payment** (Stripe, etc.) — API version, SDK version, deprecated endpoints
- [ ] **Build tools** (Vite, Webpack, etc.) — version, plugin compatibility
- [ ] **Language** (TypeScript, etc.) — version, new features to leverage

### Unused Dependencies

- [ ] Identify packages in `package.json` that are not imported anywhere
  - Check both `dependencies` and `devDependencies`
  - Some packages may be used via CLI (not imported) — verify before removing
- [ ] Identify packages that could be replaced with:
  - Built-in Node.js/runtime APIs
  - Smaller alternatives
  - Code already in the project

### Bundle Impact

- [ ] Identify the heaviest dependencies by bundle size contribution
- [ ] Check if large dependencies are tree-shaken properly
- [ ] Verify lazy loading for route-specific heavy dependencies
- [ ] Flag any dependency that adds >100KB to the client bundle
- [ ] Check for duplicate packages (same package at different versions)

### License Compliance

- [ ] All dependencies use compatible open-source licenses
  - MIT, Apache 2.0, BSD — generally safe
  - GPL, AGPL — check compatibility with project license
  - Custom/proprietary — flag for review
- [ ] No dependency has changed its license recently to something incompatible
- [ ] Transitive dependencies don't introduce license conflicts

### Lock File Integrity

- [ ] Lock file is committed and up to date
- [ ] No unexpected changes in lock file (integrity hash mismatches)
- [ ] Lock file doesn't reference private registries unexpectedly
- [ ] Package resolution is consistent (no conflicting versions)

### Supply Chain Security

- [ ] Dependencies come from expected registries (npmjs.com, etc.)
- [ ] No typosquat package names (names similar to popular packages)
- [ ] GitHub Actions are pinned to a full commit SHA (with the version
      as a trailing comment), not a mutable tag like `@v4` or `@main`.
      Mutable tags are a supply chain risk (see CVE-2025-30066)
- [ ] Docker images (if any) use specific tags, not `latest`
- [ ] No `eval()` or dynamic code execution from dependency content

## What to Fix

1. **Update** packages with known vulnerabilities to patched versions
2. **Remove** unused dependencies from `package.json`
3. **Document** any dependencies that can't be updated (with reason)
4. **Flag** license concerns for human review
5. **Update** dependency automation config if new groups are needed

## Severity Guide

- **CRITICAL**: Known exploited vulnerability, compromised package, license violation
- **HIGH**: Unpatched security vulnerability, severely outdated critical dependency
- **MEDIUM**: Outdated dependencies with available updates, unused dependencies
- **LOW**: Minor version updates, bundle optimization opportunities
