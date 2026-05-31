# Proposed fixes pending human application

Patches in this directory are code fixes prepared by the automated review
system that could not be pushed directly because the change touches
`.github/workflows/*` and the GitHub App identity used by the action does
not have the `workflows: write` permission.

## How to apply a patch

From the repository root:

```sh
git checkout -b apply/<short-name>
git am .github/proposed-fixes/<patch-file>.patch
git push -u origin HEAD
```

Then open a PR and delete the corresponding patch file once merged.
