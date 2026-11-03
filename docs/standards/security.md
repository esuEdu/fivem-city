# Security standards

Rules for code in `server-data/resources/[local]/`. Assume every client is modified: players can run their own Lua code, trigger any net event with any arguments, and read every client file and NUI file.

## The server owns the truth

- Anything with value (money, items, job, grade, vehicles, XP, cooldowns) is decided and changed **only on the server**. A client event can *ask* for something; the server checks whether it's allowed and does it.
- Never accept prices, amounts, rewards, item names or target players from the client without checking them against server-side config or state. Look up the price on the server from an ID; don't receive it.
- Never write a net event like `server:addMoney(amount)` or `server:giveItem(item, count)`. Name events after the player action (`server:sellFish`) and work out the result on the server.
- Secrets, webhooks, API keys and admin logic go in server files only. Anything in `client_scripts`, `shared_scripts` or `files` is sent to every player.

## Validating net events

Every `RegisterNetEvent` / `lib.callback.register` handler on the server must:

1. Use `source` (captured at the top: `local src = source`), never a player ID from the arguments, to decide who is acting.
2. Fetch the player with `exports.qbx_core:GetPlayer(src)` and return early if it's `nil`.
3. Check the argument types (`type(x) == 'number'`, integer, range, known enum value) before using them.
4. Check that the context makes sense: job/grade, distance to the relevant coords (`#(GetEntityCoords(GetPlayerPed(src)) - coords) < maxDist`), required item present, not dead or handcuffed if relevant.
5. Enforce cooldowns and rate limits on the server, keyed by `src` or by citizenid, for anything repeatable that gives a reward.

If the check fails, return without doing anything and log it with `lib.print.warn` (resource, source, reason). Don't kick or ban automatically unless the spec says to.

## Commands and permissions

- Admin commands: `lib.addCommand` with `restricted = 'group.admin'` (or `group.mod` / `group.support`), plus the Qbox admin-duty check `exports.qbx_core:IsOptin(source)`. Allow `source == 0` (server console).
- Never check permissions on the client only. Hiding a menu option is UX; the server handler must check again.
- Validate player IDs in arguments (`type = 'playerId'` in `lib.addCommand` params, or `GetPlayerName(id)` not `nil`).

## Database

- Use oxmysql with parameters only: `MySQL.query.await('SELECT * FROM x WHERE id = ?', { id })`. Never build SQL from strings with `..` or `format`.
- Database calls run only on the server. Prefer the Qbox and ox_inventory exports over writing to their tables directly.

## Entities and state

- Don't trust entity ownership or net IDs sent by the client. Check `NetworkGetEntityFromNetworkId`, `DoesEntityExist`, entity type/model and distance before acting on them.
- Write state bags that other code relies on from the server (`Entity(ent).state:set(k, v, true)` on the server, or `Player(src).state`). Client-set state bags are only for cosmetic, non-trusted data.
- Spawn valuable entities (job vehicles, loot props) on the server or after a server-approved callback.

## NUI

- Treat NUI callback data the same as net event data. Validate it on the server before acting.
- Don't put HTML from player input on the page without escaping it (chat messages, names, notes).

## Review checklist

- [ ] Every server event and callback validates `source`, types, ranges and context.
- [ ] No reward, price or amount comes from the client.
- [ ] Repeatable rewards have a server-side cooldown.
- [ ] SQL uses `?` parameters.
- [ ] No secrets or webhooks in client/shared files.
- [ ] Admin actions are restricted by ACE and check `IsOptin`.
