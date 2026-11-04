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
- Features and anything that needs an in-game test go on a branch; the user merges it (pull request or merge) after testing.
- Small docs or config fixes can go straight to `main` when the user asks.

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
