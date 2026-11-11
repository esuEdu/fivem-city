# Git standards

Branch names and commit messages for the whole repo, based on [Conventional Commits](https://www.conventionalcommits.org/).

## Types

| Type | For |
| --- | --- |
| `feat` | Something new players, staff or server owners can use (a feature, item, app, command, config option) |
| `fix` | A bug fix, in our code or a vendored script's patch |
| `refactor` | Code changed without changing what it does |
| `perf` | Faster or lighter (resmon, server CPU, database) |
| `test` | Unit tests in `tests/` only |
| `docs` | `docs/`, `CLAUDE.md`, READMEs, comments only |
| `chore` | Tooling and upkeep: `scripts/`, `.claude/skills/`, Docker, updating vendored resources, `server.cfg` housekeeping |

## Branches

`<type>/<topic>`: the type of the main change, then a short kebab-case topic.

```
feat/player-search
fix/fuel-payment
feat/city-os-tablet
chore/update-qbox-recipe
docs/docker-guide
```

- One topic per branch. If it grows into a second feature, finish or split it.
- Every change (features, fixes, docs, config) goes on a branch and to `Cidade_Teste` first (below). Nothing is committed or pushed to `main` directly.

## Cidade_Teste and main

`main` is locked: only a feature that is 100% done goes there, with nothing left to add or fix. Everything still being tested lives on **`Cidade_Teste`**, the branch the test server runs.

1. Branch from `main` (`feat/app-x`) and do the work.
2. Merge the branch into `Cidade_Teste` (a pull request with base `Cidade_Teste`, or `git switch Cidade_Teste && git merge feat/app-x && git push`). The feature branch stays open: when the PR closes, don't delete it.
3. Test on the server. A bug, a missing piece or a "forgot X" is fixed **on `feat/app-x`**, never on `Cidade_Teste`, and merged into `Cidade_Teste` again (only the new commits go in).
4. When it has been tested and 100% of the feature works, with nothing more to add, someone from the team opens the pull request **`feat/app-x` → `main`** by hand. Claude never opens pull requests to `main`.

Rules:

- Never merge `Cidade_Teste` into `main` or into a feature branch: everything under test, finished or not, would go with it. `Cidade_Teste` only receives merges.
- A fix made on `Cidade_Teste` is lost for `main`, because `main` gets the feature branch. Always fix on the feature branch.
- A conflict between two features is solved on `Cidade_Teste` and again on `main` later; `git config --global rerere.enabled true` lets git reuse the first resolution.
- A feature that needs another one branches from it (or waits until the other is in `main`); otherwise it works on `Cidade_Teste` and breaks on `main`.
- Now and then reset `Cidade_Teste` to `main` and merge again only the branches still under test, so abandoned work leaves the test server.

## Commits

```
<type>(<scope>): <description>

<body>

<trailer>
```

- **scope**: the part changed.
  - Our resources: their name without `city_` (`inventory`, `os`, `racing`, `ui`).
  - Vendored scripts: the resource name (`qbx_police`, `ox_fuel`).
  - Everything else: `docker`, `scripts`, `skills`, `tests`, `roadmap`.
  - Leave it out when a change spans many: `docs: ...`.
- **description**: lowercase, imperative ("add", not "added" or "adds"), no full stop, the whole first line at most 72 characters.
- **body** (optional for one-line changes): what changed and why, wrapped at 72. Bullets are fine.
- **breaking change** (players lose items or money, saved data changes shape, an export changes its arguments): add `!` after the scope, `feat(inventory)!: ...`, and a `BREAKING CHANGE: ...` line in the body saying what to do.
- One logical change per commit. A feature together with its tests and docs is one change.
- End with the attribution trailer when Claude wrote the commit.

Examples:

```
feat(inventory): add player search for police, robbers and staff
fix(inventory): pay ox_fuel from qbx cash
fix(qbx_police): accept the hands-up key's animation when robbing
chore(qbx_radialmenu): remove the dead Give Contact Details button
docs(roadmap): tick Phase 0 player search
feat(inventory)!: key stashes by citizenid
```

## Review checklist

- [ ] Branch is `<type>/<topic>`.
- [ ] Every commit's first line is `<type>(<scope>): <description>`, lowercase imperative, ≤ 72 characters.
- [ ] Breaking changes have `!` and a `BREAKING CHANGE:` line.
- [ ] No `.env`, `secrets.cfg` or scratch files staged.
