# Removing the ox_inventory stand-in

`[local]/ox_inventory` is a two-file stand-in that forwards ox's export names to `city_inventory`. It can only be deleted once **no script calls `exports.ox_inventory` or looks for a resource named `ox_inventory`**. This is every script that still does, what it uses, and what it needs.

Our own `[local]` resources already call `exports.city_inventory` directly. The `ox_inventory:*` **events** (`itemCount`, `currentWeapon`, `openedInventory`, …) are fired by city_inventory itself, so they keep working without the stand-in.

Counts are from a grep of `server-data/resources` on 2026-11-07. Re-run it before starting:

```sh
grep -rn "ox_inventory" server-data/resources --include=*.lua | grep -v "\[local\]"
```

## Summary

| Group | Scripts | Work |
|---|---|---|
| A. Break without a resource named ox_inventory | 4 | Hand-written patch each |
| B. Only call `exports.ox_inventory:*` | 24 | Rename to `exports.city_inventory` |
| C. Only listen to `ox_inventory:*` events | 2 | Nothing (rename optional) |
| D. ox_inventory code that never runs here | 2 | Nothing |

32 vendored scripts in all. None needs a full rewrite: city_inventory already has every export they use, with the same names and arguments.

## A. Break without a resource named ox_inventory

These check for the resource by name or version, so a rename alone isn't enough.

| Script | What ties it to ox_inventory | Fix |
|---|---|---|
| **ox_fuel** | `fxmanifest.lua` lists `ox_inventory` in `dependencies`; `config.lua` does `lib.checkDependency('ox_inventory', '2.30.0', true)` and stops if it fails. `server.lua` keeps `local ox_inventory = exports.ox_inventory` (`RemoveItem`/`GetItemCount` of `money`, `GetCurrentWeapon`, `SetMetadata`, `CanCarryItem`, `AddItem` for the petrol can); the client uses `GetItemCount`, `getCurrentWeapon` and the `currentWeapon` event. | Patch: dependency and version check → `city_inventory`, rename the exports. Or remake as **city_fuel**, which could charge through city_economy directly instead of the `money` item. |
| **ox_target** | `client/utils.lua` only turns on item checks (`items = ...` on a target option) if `utils.hasExport('ox_inventory.Items')`; then it counts with `exports.ox_inventory:Search('count', …)` and the `itemCount` event. Without it, options that need an item never show. | Patch: `hasExport('city_inventory.Items')` and `exports.city_inventory:Search`. (`client/framework/esx.lua` also checks it, but only loads on ESX.) |
| **qbx_police** | Removed (replaced by city_police, which calls city_inventory directly); nothing to do. Was: `server/main.lua` registers its locker and trash stashes on `onServerResourceStart` for `'ox_inventory'` and when `GetResourceState('ox_inventory') == 'started'`; without it the stashes are never registered. Also calls `RegisterStash`, `ClearInventory`, `AddItem`, `RemoveItem`, `Search`, `GetCurrentWeapon`, `openInventory`, `openNearbyInventory`, `getCurrentWeapon`, `Items`. | Extend `scripts/patches/qbx_police.patch`: check `city_inventory` and rename the exports. Or fold into a future **city_police**. |
| **qbx_core** | Already patched to load city_inventory's items and weapons. Left: the inventory converter (`server/convert/inventory.lua`) calls `exports.ox_inventory:Items` and refuses to run unless `GetResourceState('ox_inventory') == 'started'`; it also reads and writes ox's `ox_inventory` SQL table. Plus messages and `@deprecated` comments that name ox_inventory. | Extend `scripts/patches/qbx_core.patch` to point the converter at city_inventory, or disable it (we don't import qb-inventory data). The messages are cosmetic. |

## B. Only call `exports.ox_inventory:*`

For each one, replacing `exports.ox_inventory` with `exports.city_inventory` (and `local ox_inventory = exports.ox_inventory` the same way) is the whole change.

| Script | Exports used | Files |
|---|---|---|
| **mm_radio** | `GetSlotWithItem`, `GetSlotIdWithItem`, `GetSlot`, `SetMetadata`, `AddItem`, `RemoveItem`, `Search` (+ the `updateInventory` event) | 3 |
| **ox_doorlock** | `RemoveItem`, `Search` (through `local ox_inventory`) | 1 |
| **qbx_bankrobbery** | `AddItem` ×14, `Search` ×11, `RemoveItem` ×4 | 4 |
| **qbx_consumables** (in qbx_smallresources) | `RemoveItem` ×4. Its `resource == 'ox_inventory'` branches handle ox's QB bridge and never run here. | 1 |
| **qbx_divegear** | `RemoveItem` | 1 |
| **qbx_diving** | `GetItemCount`, `RemoveItem`, `AddItem` | 1 |
| **qbx_drugs** | `Items` ×5, `AddItem`, `RemoveItem`, `GetItemCount`, `Search` | 4 |
| **qbx_fireworks** | `Search`, `GetItemCount`, `RemoveItem` | 1 |
| **qbx_houserobbery** | `Items` | 1 |
| **qbx_idcard** | `AddItem`, `Search`, `GetSlot`, `SetMetadata` (server), `displayMetadata` (client) | 3 |
| **qbx_jewelery** | `Items`, `Search`, `CanCarryItem`, `AddItem`, `CustomDrop` | 1 |
| **qbx_mechanicjob** | `Items` ×9, `RegisterStash`, `Search`, `RemoveItem`, `openInventory` | 2 |
| **qbx_pawnshop** | `Items` ×4, `GetPlayerItems` ×2 | 2 |
| **qbx_properties** | `RegisterStash`, `registerHook`, `forceOpenInventory` | 1 |
| **qbx_recyclejob** | `CanCarryItem`, `AddItem` | 1 |
| **qbx_scrapyard** | `AddItem` | 1 |
| **qbx_seatbelt** | `GetSlot`, `RemoveItem`, `SetMetadata` | 1 |
| **qbx_storerobbery** | `Search`, `RemoveItem`, `AddItem` | 1 |
| **qbx_taxijob** | `Items` | 1 |
| **qbx_truckrobbery** | `RemoveItem`, `CanCarryItem`, `AddItem`, `CustomDrop`, `Search` (+ the `disarm` event) | 2 |
| **qbx_vehiclekeys** | `RemoveItem` | 1 |
| **qbx_vineyard** | `GetItem`, `RemoveItem`, `AddItem` | 1 |
| **qbx_weed** | `AddItem` ×5, `RemoveItem` ×3, `GetSlot`, `Search` | 1 |

`qbx_properties` is the one to test hardest: `registerHook` currently gets its calling script passed on by the stand-in (`city_inventory/server/exports.lua`, `GetInvokingResource`); called directly, city_inventory sees qbx_properties itself, which is what we want.

## C. Only listen to `ox_inventory:*` events

city_inventory fires and handles these events itself, so these keep working with the stand-in gone.

| Script | Events |
|---|---|
| **qbx_hud** | `ox_inventory:openedInventory`, `closedInventory`, `currentWeapon` |
| **qbx_medical** | triggers `ox_inventory:disarm` (city_inventory listens) |

Renaming the events to `city_inventory:*` is optional. If it's done, change the senders in `city_inventory/client/compat.lua`, `client/main.lua` and `server/actions.lua`, and every listener: these two, mm_radio, ox_target, ox_fuel, qbx_truckrobbery, and our `city_phone`, `city_phone_calls` (`ox_inventory:itemCount`).

## D. ox_inventory code that never runs here

| Script | Why nothing breaks |
|---|---|
| **illenium-appearance** | `server/framework/ox/main.lua` only loads on ox_core (`Framework.Ox()`); on Qbox it uses the qb framework files. |
| **vehiclehandler** | `server.lua` registers the `cleaningkit` export only when ox_inventory is started, but it's an ox item-`export` callback that city_inventory never calls, so the cleaning kit is already unused today. Making it usable is a separate job (`exports.qbx_core:CreateUseableItem`). |

## How to do it

1. **Rename in one place, not 24 patches.** Add a step to `scripts/install-resources.sh`, after the downloads and before the patches, that replaces `exports.ox_inventory` and `exports['ox_inventory']` with `exports.city_inventory` in every vendored `.lua` file. The rename then survives updates with no per-script patch, and group B is done.
2. **Patch group A** (ox_fuel, ox_target, qbx_core; qbx_police is gone) with the `patch-script` skill. Rebuild existing patches with `bash scripts/make-patch.sh`, never a bare `git diff`.
3. **Test in game** with the stand-in still running: fuel and petrol can, a target option that needs an item, police locker/trash/search/rob, radio, an ID card, a house stash, prison in and out, a bank robbery, drug corner selling, a jewellery store, the mechanic stash.
4. **Remove the stand-in:** delete `server-data/resources/[local]/ox_inventory`, remove `ensure ox_inventory` (and its comment) from `server.cfg`, and run the grep above; only comments and READMEs should be left.
5. **Clean up city_inventory:** drop the stand-in case in `server/exports.lua` (`resource == 'ox_inventory'` and the `invoker` argument of `registerHook` / `removeHooks`).
6. **Update the docs:** `CLAUDE.md` (the ox_inventory bullet and the `ensure` order), `docs/scripts/issues.md` and `README.md`, the `replace-script` skill (it uses the stand-in as its worked example), and `docs/standards/code-style.md` / `security.md` (they say "ox_inventory exports").

New third-party scripts will usually be written for ox_inventory. After this, they get the same rename (step 1 covers anything installed by the script; anything added by hand needs it done by hand or in a patch).
