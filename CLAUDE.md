> **Cross-repo work**: this repo is part of the VION platform.
> Architecture state, decisions, and cross-repo specs live in [`../architecture`](https://github.com/VION-IoT/architecture).
> Clone it: `git clone git@github.com:VION-IoT/architecture.git ../architecture`
> Before planning a feature with scope ≥ 2 repos, read the relevant `architecture/systems/*.md`
> and run `/spec <slug> <repos>` from the architecture repo.
> Cross-repo work is dispatched with the `vion-dispatch` plugin
> ([mechanics](https://github.com/VION-IoT/architecture/blob/main/plugins/vion-dispatch/README.md),
> [VION procedure](https://github.com/VION-IoT/architecture/blob/main/runbooks/session-orchestration.md)).
> A session dispatched into this repo ends with `/vion-dispatch:report`.

# CLAUDE.md — VION shared workflows

Reusable GitHub Actions workflows and composite actions that the VION-IoT repositories call at
`@v1` or at an exact tag. The repository runs only callers of its own workflows: the `proof-*.yml`
workflows that exercise them against `tests/fixtures/`, and `close-prs.yml`, which closes pull
requests from forks. The inventory, the calling conventions, the
secrets model and the semver rules are in [`README.md`](README.md); they are not repeated here.
Every change that reaches a consumer gets a line under `## Unreleased` in `CHANGELOG.md`.

## Working agreement

### Lanes

At the start of a task, answer two questions out loud: is the change local? is a design point open?

- **Fix-sized** — local, nothing open: branch, commit, review, pull request. No document. A change
  that turns out not to be local stops and says so, and becomes feature-sized.
- **Feature-sized** — a change doc first, in `docs/changes/`. Ratified before code when a question
  in it is open. Archived in the pull request that lands it.

### STOPs

- A STOP is named up front — by the brief, by an open question in the change doc, or by the lane
  answer — and there is no other. With none named, the human review is on the pull request.
- A STOP is a `partial` REPORT with a question in it.
- A decision nobody named is surfaced, not taken. A hedge in a brief is a STOP when it fails.
- Scope does not widen on its own: a design or naming question is answered with options and changes
  nothing until the human chooses; work nobody asked for is proposed, not produced.
- A question from the human is a question, not an instruction.
- Anything committed after a `done` REPORT needs a new REPORT.
- A request that breaks a convention of this repo is pushed back on before complying, naming the
  convention.
- Verification only a human can do is not a STOP: it is written as "not run, routes to a human" under
  the pull request's Verification.

### Communication

- Say what was run, not that it worked.
- A count is pasted with the command that produced it.
- Expand an initialism the first time it is used.
- Promise no notification that cannot be subscribed to.
- A finding cites the line, or says it is inferred.

### Never

- Push to or commit on the default branch.
- Force-push.
- Delete a remote branch.
- Merge a pull request.
- Write to Jira without saying so first.
- Paste a secret into chat.

## Skills in this repo

Naming the `vion-git` skills below opts this repo into them.

| moment | skill |
|---|---|
| starting work on a change | `/vion-git:branch` |
| a unit of work lands — a task, an acceptance criterion, a fixed review finding | `/vion-git:commit` |
| the branch is ready for a pull request | `/vion-git:pr` |

### Pre-PR obligations

None run locally: CI is the gate. The regression tests are the `proof-*.yml` workflows, which run
on the pull request, each only when the pull request touches one of its `paths`. Most need what a
workstation lacks — a Windows runner, a live Mender server, the caller secrets. A pull request that
touches no proof's `paths` runs no proof — the only check it shows is `close-prs.yml`'s job, skipped
for a branch of this repository — and it says so rather than calling it green.
`actions/journal-lint/journal-lint.ps1` runs locally for a quick loop, but its proof asserts the exact
findings per fixture, and only the workflow checks that.

## Parallel sessions

The main checkout stays on `main`. Every branch lives in the worktree `../shared-workflows-<key>`
beside it: `/vion-git:branch` creates it, or reuses it when it is clean and its branch is not other
work's, and stops otherwise. The `vion-git` hook denies edits to the main checkout that git does not
ignore, and blocks a shell command that leaves new changes there. Nothing here is a singleton: no
server, no port, no globally installed tool.

## Releasing

A release is a lightweight tag `vX.Y.Z` on a merge commit on `main`, with a GitHub release on it,
and then the floating `v1` moved to the same commit. Consumers pin to either, so both steps change
what other repositories run.

1. **The version.** `git ls-remote --tags origin` lists every tag; `gh release list` does not (it
   starts at `v1.11.0`). Take the highest `vX.Y.Z` and bump it by the rules in `README.md` §
   Versioning: a renamed or removed input or output is major, an addition minor, a fix patch.
2. **The tag must not exist.** `git ls-remote --tags origin vX.Y.Z` prints nothing. `gh release
   create` attaches to a tag that already exists and ignores `--target`, which is how `v1.11.0`'s
   release landed on a commit it was not meant for.
3. **The changelog heading, in a release pull request.** `/vion-git:branch chore/changelog-vX-Y-Z`,
   then turn what this release ships under `## Unreleased` into `## vX.Y.Z — YYYY-MM-DD`, dated the
   day the release is created. Do not assume `## Unreleased` holds only this release: entries an
   earlier tag already shipped (`git log --oneline <tag>..<next tag>` shows which pull requests each
   tag holds) go under that tag's own heading. `/vion-git:pr`, and a human merges it.
4. **The release.** `git fetch origin`; the merge commit is
   `gh pr view <number> --json mergeCommit --jq .mergeCommit.oid`. Then
   `gh release create vX.Y.Z --target <merge commit> --title vX.Y.Z --generate-notes`.
   `.github/release.yml` sections the notes by the `feat`, `fix` and `chore` labels.
5. **Moving `v1`** — the one exception to "Never force-push" above. Read the old SHA with
   `git ls-remote --tags origin v1`. An agent moves the tag only after the human has said yes to a
   question naming the old and the new SHA; in a dispatched session that question is a `partial`
   REPORT, and a brief that includes a release names this move as its STOP. Every consumer's `@v1`
   changes the moment the tag moves. Then
   `gh api -X PATCH repos/VION-IoT/shared-workflows/git/refs/tags/v1 -f sha=<merge commit> -F force=true`.
   A major release does not move `v1`; its new major tag is a question of its own.
6. **Check.** `git ls-remote --tags origin v1 vX.Y.Z` lists both refs at the merge commit's SHA.
   This holds for lightweight tags only: an annotated tag lists its tag object, and its commit is
   the `^{}` line.
