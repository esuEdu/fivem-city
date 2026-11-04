---
name: patch-script
description: Change a third-party (vendored) script such as a qbx_*, ox_*, npwd or [standalone] resource so the change survives updates, by turning it into scripts/patches/<resource>.patch. Use when the user wants to change how a Qbox/ox script behaves, fix a bug in one, or change its config ("make the police job...", "change qbx_X so...", "/patch-script").
---

# Patch a vendored script

Every resource outside `[local]/` is downloaded by `scripts/install-resources.sh`, which **wipes the folder** and then re-applies `scripts/patches/<resource>.patch`. An edit that isn't in a patch is lost on the next update. Our own resources in `[local]/` are edited directly and need none of this.

## 1. Before editing

- Check whether it needs a patch at all:
  - Many scripts read **convars** set in `server-data/server.cfg` (e.g. `qbx:*`, `ox:*`, `voice_*`, `inventory:*`): changing a convar there needs no patch.
  - If our own code can do it, prefer that: hooks, exports and events (for example `exports.ox_fuel:setPaymentMethod`), or `exports.city_inventory` settings.
- Read the code you'll change and the script's `config/` files: most behavior is in config (`config/shared.lua`, `config/client.lua`, `config/server.lua`). Config edits still need a patch.
- Look at `docs/scripts/issues.md` for known problems with that script.
- `ls scripts/patches/` to see if the resource already has a patch: the new change will be merged into it.

## 2. Edit

Make the smallest change that does it, in the script's own style (these files don't follow our standards; don't reformat them). Add a short comment at our changes saying why, so they're easy to spot in the patch.

## 3. Write the patch

```sh
bash scripts/make-patch.sh "server-data/resources/[qbx]/<resource>"
```

It rebuilds `scripts/patches/<resource>.patch` with **all** our changes to that resource (old patch + new edit) from the upstream version, and checks it applies. Don't hand-write patches or use a bare `git diff`: the committed copy already contains the old patch, so a plain diff would hold only the new change and the next update would drop the old one.

Commit both the edited files and the patch.

## 4. Verify

1. `git diff --stat` shows the resource files and its `.patch`, nothing else.
2. `bash scripts/check.sh` (only checks `[local]`, but catches anything our code broke).
3. If the change is non-trivial, prove it survives an update on a scratch copy: in a temporary `git worktree`, run `bash scripts/install-resources.sh` and check `git status` shows no difference for that resource. (Downloads everything; skip for one-line config changes and say so.)
4. In game: `git pull` on the server PC, then `ensure <resource>` (or restart the server if other scripts depend on it).

## 5. Record it

- If it fixes an item in `docs/scripts/issues.md`, move or update it there.
- `CLAUDE.md` lists the patches in its architecture section when they change how things fit together (e.g. qbx_core using city_inventory); add a line for a new patch of that kind.
