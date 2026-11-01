# fivem-city

FiveM roleplay server built on [Qbox](https://github.com/Qbox-project) + the [ox](https://github.com/communityox) resource stack.

## Stack

| Resource | Purpose |
| --- | --- |
| oxmysql | MySQL / MariaDB driver |
| ox_lib | Shared UI + utility library |
| qbx_core | Qbox framework core |
| ox_target | Third-eye interaction |
| ox_inventory | Inventory |
| pma-voice | Proximity voice |

## Layout

```
server.cfg              main config (committed)
secrets.cfg.example     template for keys / DB string -> copy to secrets.cfg
scripts/                setup helpers
resources/
  [cfx-default]/        default cfx resources (chat, spawnmanager, ...)
  [ox]/                 ox stack
  [qbx]/                Qbox resources
  [voice]/              pma-voice
  [standalone]/         third-party scripts not tied to a framework
  [maps]/               MLOs and map edits
  [local]/              our own resources (start new ones here)
```

## First-time setup

1. **Server artifacts** – download the latest recommended FXServer build from
   <https://runtime.fivem.net/artifacts/fivem/> into `artifacts/` (gitignored).
2. **Database** – install MariaDB (or MySQL 8) and create a database, e.g. `fivem_city`.
3. **Secrets** – `cp secrets.cfg.example secrets.cfg` and fill in your
   [license key](https://portal.cfx.re) and `mysql_connection_string`.
4. **Resources** – run `./scripts/install-resources.sh` (needs `git`, `curl`, `unzip`).
5. **SQL** – import `resources/[qbx]/qbx_core/qbx_core.sql` into the database.
6. **Run** – from the repo root:
   ```sh
   ./artifacts/run.sh +exec server.cfg      # Linux
   artifacts\FXServer.exe +exec server.cfg  # Windows
   ```
7. **Admin** – connect once, grab your `license:` identifier from the console and add it
   at the bottom of `server.cfg`.

## Adding resources

- Our own code goes in `resources/[local]/` — `city_base` is a starter template.
- Qbox scripts (`qbx_*`) go in `resources/[qbx]/`, everything else in `[standalone]/`.
- Every `[group]` folder is started by `server.cfg`, so dropping a resource in is enough.
