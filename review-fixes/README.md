# Review fixes pending a `workflows`-permission merge

The automated codebase-review **fixer** runs with the repository's GitHub App
token. GitHub refuses to let a GitHub App create or update **any** file under
`.github/workflows/` (including the helper scripts in
`.github/workflows/scripts/`) unless the App has the `workflows` permission,
which this token does not have.

Because the entire reviewed codebase lives under `.github/workflows/`, the
fixer cannot land those changes directly. Each `*.patch` file here contains the
complete, verified fix so a maintainer (or a token that has `workflows`
permission) can apply it:

```bash
git apply review-fixes/error-handling-2026-06-28.patch
# then commit the result and delete the applied patch:
git rm review-fixes/error-handling-2026-06-28.patch
```

Each patch is generated against `main` and has been verified with `shellcheck`
(scripts) and `actionlint` (workflows) after application.
