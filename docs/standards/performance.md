# Performance standards

Rules for code in `server-data/resources/[local]/`. Target: each resource uses **≤ 0.02 ms idle and ≤ 0.10 ms while active** on the client, as shown by `resmon 1` in the F8 console. Check server-side CPU time with `profiler` in the txAdmin console when a resource does heavy work.

## Client loops

- No permanent `while true do ... Wait(0) end` loops. Wait for one frame (`Wait(0)`) only while something must be drawn or checked every frame (markers, DrawText, disabling controls), and only while the player is near or the feature is active.
- Make loops sleep longer when nothing is nearby: e.g. `Wait(1000)` when far, `Wait(0)` only inside the interaction range.
- Prefer event- and zone-driven code over polling:
  - `lib.points.new` (with `onEnter` / `onExit` / `nearby`) or `lib.zones` for location-based logic.
  - `ox_target` (`exports.ox_target:addBoxZone`, `addModel`, `addLocalEntity`) for interactions instead of "press E" loops with distance checks.
  - `lib.onCache('vehicle', fn)`, `lib.onCache('ped', fn)` and game events (`baseevents`, `gameEventTriggered`) instead of polling for state changes.
- Use `cache.ped`, `cache.vehicle`, `cache.coords`, `cache.playerId` from ox_lib instead of calling `PlayerPedId()` / `GetVehiclePedIsIn` every tick.
- Compare distances with `#(a - b)` on `vector3` values, not `GetDistanceBetweenCoords`.

## Natives and assets

- Before spawning, load models, animation dictionaries and particle effects with `lib.requestModel`, `lib.requestAnimDict`, `lib.requestNamedPtfxAsset`, then free them with `SetModelAsNoLongerNeeded` / `RemoveAnimDict`.
- Delete the entities, blips, zones and target options you create when the resource stops (`AddEventHandler('onResourceStop', ...)` with a check against `GetCurrentResourceName()`), and when the feature ends.
- Store values that don't change (config lookups, hashes via `` `model` `` backtick literals) in local variables instead of recomputing them.

## Network

- Don't trigger net events every frame or on a fast timer. Send changes, not continuous state, and throttle anything that reacts to player input.
- Use `lib.callback.await` for request/response instead of pairs of events.
- Use state bags for data that many clients need to read (`Entity(ent).state`, `GlobalState`) instead of broadcasting events to everyone; only replicate what clients actually use.
- Send events to one player or a small group (`TriggerClientEvent(name, src, ...)`) rather than `-1` (everyone) unless every player really needs it. Keep payloads small: send IDs, not whole config tables.

## Server and database

- Never call the database inside loops over players or items. Batch the work (`MySQL.prepare` with several parameter sets, or `MySQL.transaction`) or cache the results in memory and write them back periodically or on player drop.
- Load static data once at resource start, not per request.
- Use the `.await` oxmysql variants only inside threads/handlers that can yield; don't block startup with large queries.
- Server tick loops (`CreateThread` + `Wait`) should run at the slowest interval that still works (seconds, not frames).

## Review checklist

- [ ] No `Wait(0)` loop that runs while the player is away from the feature.
- [ ] Interactions use ox_target or `lib.points` / `lib.zones`, not distance polling.
- [ ] Loaded assets are released; created entities, blips and zones are cleaned up on stop.
- [ ] No per-frame net events; broadcasts to `-1` are justified.
- [ ] No database calls inside loops.
- [ ] `resmon` checked in-game for client-heavy changes.
