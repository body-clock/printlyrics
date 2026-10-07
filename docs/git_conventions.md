# Git conventions

Formats for commits, branches, and pull request titles, plus the mechanics that
keep a mutating git command in the checkout you meant. PrintLyrics has two
long-lived branches carrying parallel histories, so the operations that move
work between them need more care than a single-trunk repository does.

## Commits — `<type>(scope)!: description`

Types: feat fix perf revert docs chore refactor test ci build style

- scope optional, `!` = breaking change
- body: blank line, then why not how
- footer: `Refs: #123`, `BREAKING CHANGE: ...`

```
feat(songbook): gather a visit's sheets into one offer
fix(search): keep a miss on the path to a sheet
chore(deps): bump honeybadger from 6.9.2 to 6.9.3
```

Release Please reads these subjects — not the diff — to build `CHANGELOG.md` and
`version.txt`, using the sections in `.release-please-config.json`. A subject it
cannot parse is dropped from the changelog, and so are `build:` and `style:`,
which have no section configured. `test:` and `ci:` are parsed but hidden.

## Branches — `<type>/description`

Types: feat, fix, chore, docs, refactor, test, release

- lowercase, hyphens only, no leading/trailing/double hyphens
- dots only in release versions: release/v1.2.0
- trunk (`main`, `development`) = no prefix
- `main` is released: release PRs and promotions land there
- `development` is integration: branch off it, merge back into it
- tool-generated: `dependabot/*`, `release-please--branches--main`, and agent
  prefixes (`claude/*`, `codex/*`, `agent/*`)

```
feat/songbooks
fix/faq-closing-rule
chore/umami-secrets-from-proton-pass
```

## Pull requests — title follows the commit convention

A squash merge turns the PR title into the commit subject on the target branch,
so it uses the same `<type>(scope)!: description` format as a commit. Release
Please parses those subjects, so a title like `Add the songbook guide` never
reaches the changelog.

Pull requests target `development`. The two exceptions are the promotion PR
(`development` → `main`) and Release Please's own release PR
(`release-please--branches--main` → `main`).

```
feat(songbook): read the demand list in Umami and gather a visit's sheets
fix(faq): stop the list drawing a rule above the resource links
```

## Promotions — `development` → `main`

- **Squash and merge, never a merge commit.** The histories are parallel: work
  squashed onto `main` is not reachable from `development` by SHA, so a merge
  commit puts every already-released commit back into Release Please's range and
  emits its changelog entry a second time.
- **Merge `main` into `development` first, and push that.** Release metadata
  belongs to `main`; without the merge back, the promotion diff reverts it —
  `version.txt` going backwards and released `CHANGELOG.md` entries
  disappearing.
- **Expect conflicts where both branches carry the same work**, and resolve them
  to `development`'s side. Prove the resolution instead of trusting it:
  `git diff <pre-merge development head> <merge commit>` should list only the
  release files, and `git diff main <merge commit>` should list none.
- **Judge what a promotion ships by tree diff** — `git diff --stat main
  development` — never by `git log main..development`, which counts features
  already released on `main` under other commits.

## Never let a command run in the wrong checkout

A `cd` that fails leaves the shell where it was, and the next command runs
against that repository. Don't depend on it: `git -C <dir> <command>` fails with
exit 128 when the directory is missing, and a `cd` in a chain needs `&&`, never
`;` or `||`, before the command it guards.

Worktrees share refs, remotes, and the object store with the main checkout, so
the same branch names resolve in both. A command that lands in the wrong one
reports no error — it produces a plausible result, after it has already
rewritten that checkout's index and working tree. `--no-commit` only skips the
commit; it does not make a merge harmless.

Before anything that mutates — `merge`, `rebase`, `reset`, `stash`, `checkout`,
`clean` — assert where you are:

```sh
[ "$(git rev-parse --show-toplevel)" = "$expected" ] || exit 1
```

`git branch -f` refuses a branch checked out in another worktree; merges and
`add -A` do not.

A ref question has the same hazard. `HEAD` is whatever branch is checked out,
so `git show HEAD:docs/foo.md` answers for that branch and not for the published
one — which is how a file that is committed and pushed on `main` appears to be
missing. `git fetch` first, then ask by full ref (`git show origin/main:path`,
`git ls-tree origin/main -- docs/`), or read the file on GitHub.

## Scratch worktrees

- Create at a unique path (`mktemp -d`), not at a fixed name a previous run may
  have left behind, and never behind a `||` fallback: if creation fails, every
  later command runs in whatever checkout the shell was in.
- Don't create the worktree in the same operation as the command that uses it;
  they are two steps with a dependency.
- A scratch worktree has no `vendor/bundle` (it is ignored), and rebuilding it
  is a trap: on this machine `bundle install` fails to build native extensions
  (`bigdecimal`, `ed25519`) and leaves stub extension directories that later
  resolve as `missing extensions`. Point `BUNDLE_PATH` at the main checkout's
  bundle and install only the gems the branch bumped. The worktree has its own
  `db/`, so its tests use their own database.
- Leave the developer's `bin/dev` alone. `tmp/pids/server.pid` is theirs; see
  [AGENTS.md](../AGENTS.md).
- Remove it when done (`git worktree remove --force`, then `git worktree prune`)
  and confirm the checkout you care about afterwards, from that directory:
  `git status` and `git log -1`.

## Probe a merge without mutating

`git merge-tree --write-tree --name-only <ours> <theirs>` prints the files that
would conflict and exits nonzero, without touching an index or a working tree
(needs git ≥ 2.38). Use it to decide whether a merge needs a scratch worktree at
all, and to check a resolution before committing it.

## Rules

- 1 change/commit, subject ≤72 chars
- branch off `development`
- no force-push of shared branches without confirmation
- PR title in commit format, since it becomes the squash-merge subject
