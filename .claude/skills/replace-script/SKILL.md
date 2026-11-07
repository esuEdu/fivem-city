---
name: replace-script
description: Replace a third-party (vendored) script with our own city_<feature> resource and remove the old one completely, so both never run together and nothing breaks - e.g. city_police replacing qbx_police, city_racing replacing qbx_lapraces/qbx_streetraces, city_phone replacing npwd. Use whenever a new script of ours takes over what an installed script does ("make our own police job", "replace X", "remove the old X now", "/replace-script").
---

# Replace a script

When one of our resources takes over what a vendored script does, the old one has to go **in the same branch**: running both means two police menus, two handlers for the same item, duplicate events. But other scripts may call the old one, so it's removed only after everything that uses it is handled.

`city_inventory` replacing ox_inventory is the worked example: about 40 scripts call `exports.ox_inventory`, so a tiny stand-in (`[local]/ox_inventory`) forwards those calls, and qbx_core is patched to use the new one.

Build the new resource with the `new-resource` skill; this skill is the replacement and clean-up around it. Do step 1 **before** designing the new resource, because it decides what the new one must provide.

## 1. Map what the old script provides and who uses it

Read the old resource (`fxmanifest.lua`, `config/`, `client/`, `server/`, its `.sql`) and list:

- **Exports** it defines: `exports('Name'`, `exports("Name"`.
- **Events** it registers (`RegisterNetEvent`, `AddEventHandler`) and triggers that others listen to.
- **Callbacks** (`lib.callback.register`), **commands** (`lib.addCommand`, `RegisterCommand`), **keybinds**.
- **Usable items** (`CreateUseableItem`), items and shops it registers (`RegisterShop`, `RegisterStash`).
- **Database tables** (its `.sql`, `CREATE TABLE`), **state bags** and `GlobalState` keys it sets.
- **Jobs/gangs** it expects in `qbx_core/shared/jobs.lua` / `gangs.lua`, and **convars** it reads.

Then find every user of those, across all resources:

```sh
cd server-data/resources
grep -rn --include='*.lua' --include='*.js' --include='*.json' -e "exports.<old>" -e "exports\['<old>'\]" -e "exports\[\"<old>\"\]" -e "GetResourceState('<old>')" -e "'<old>'" . | grep -v "^./\[.*\]/<old>/"
grep -rn --include='*.lua' "<event prefix>:" . | grep -v "^./\[.*\]/<old>/"   # e.g. police:client: / police:server:
grep -rn "<old>" ../server.cfg ../../scripts ../../docs ../../CLAUDE.md ../../.claude
```

Radial menus, admin tools and HUDs often fire the old script's events by name (`qbx_radialmenu/config/client.lua`, `city_staff/server/players.lua`); check them.

Write the result down as a table for the user and for the PR:

| What | Used by | Plan |
| --- | --- | --- |
| `exports.qbx_police:IsLeoAndOnDuty` | qbx_ambulancejob | new resource provides the same export |
| `police:client:SearchPlayer` | qbx_radialmenu | patch the radial menu to fire `city_police:client:search` |
| `police_*` tables | — | migrate to `city_police` tables / keep / drop |

## 2. Decide how each use keeps working

For each row, in this order of preference:

1. **The new resource takes over the job under its own names**, and the callers are pointed at it: a patch on the vendored caller (`patch-script` skill) or a config change.
2. **Compatibility** when many scripts depend on the old name, or one checks for it by name: keep the same export/event names in the new resource, or a small stand-in resource in `[local]/` with the old name that forwards to the new one (like `[local]/ox_inventory`). A stand-in has no logic of its own.
3. **Drop it** when nothing we keep needs it. Say so in the table.

Ask the user (AskUserQuestion) only about features the old script had that the new one won't (e.g. "qbx_police has evidence bags; leave them out?") and about data (below). Everything else, decide and say.

**Data**: never delete players' data without the user saying so. Options: the new resource reads the old tables, a one-off migration (`scripts/migrate-<old>.sql` or code that runs once at start, idempotent), or leave the old tables in the database untouched. Old tables can be dropped later, by the user, after the new resource has run for a while.

## 3. Remove the old script

All of these, so it never comes back on the next `install-resources.sh`:

- [ ] Delete the folder: `git rm -r "server-data/resources/[group]/<old>"`.
- [ ] `scripts/install-resources.sh`: remove it from `RELEASES`, `REPOS` or `QBX_REPOS`, and any follow-up step that touches it.
- [ ] `scripts/patches/<old>.patch`: delete it. Also patches of *other* resources that only existed for the old one.
- [ ] `scripts/import-sql.sh`: remove its `.sql` from `FILES` (the tables stay in the database; see Data).
- [ ] `server-data/server.cfg`: its `ensure` line if it has one, its convars, ACE lines for its commands.
- [ ] `dependencies` / `dependency` in other `fxmanifest.lua` files that name it (patch vendored ones).
- [ ] Docs: `docs/scripts/README.md` (move the row to our resource), `docs/scripts/issues.md`, `docs/roadmap.md`, `CLAUDE.md` if it named the old script, other skills that mention it.

Then check nothing still points at it; the only hits left should be the stand-in (if any), the migration, and history in docs:

```sh
grep -rn "<old>" server-data scripts docs CLAUDE.md .claude --include='*' | grep -v "^server-data/resources/\[local\]/<new>/"
```

## 4. Verify

1. `bash scripts/check.sh` passes.
2. The removal survives an update: in a temporary `git worktree`, run `bash scripts/install-resources.sh`; `git status` must show the old folder isn't back and no patch failed.
3. In game, on a fresh server start (not just `ensure`, since a removed resource stays loaded until restart): `docker compose restart fxserver`, then the F8 console and server log have no `No such export`, `Couldn't find resource` or missing-dependency errors, and **every row of the step 1 table** works: the new feature itself, and each script that used the old one (e.g. radial menu actions, the admin menu, other jobs).

## 5. Ship

On one `feat/<topic>` branch (see `docs/standards/git.md`), as separate commits:

```
feat(<new>): add <feature> to replace <old>
fix(<caller>): use <new> instead of <old>          one per patched caller, if any
chore(<old>)!: remove <old>, replaced by <new>
```

The removal commit is breaking (`!`) when players lose something or data moves; its body says what happens to the old data (`BREAKING CHANGE: police_records stay in the database but are no longer read`). Put the step 1 table in the PR description, with the in-game test list from step 4. Use the `ship` skill to commit and push when the user asks.
