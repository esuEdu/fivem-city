# fivem-city

FiveM roleplay server built on [Qbox](https://github.com/Qbox-project) + the [ox](https://github.com/communityox) resource stack.

## Stack

| Resource | Purpose |
| --- | --- |
| oxmysql | MySQL / MariaDB driver |
| ox_lib | Shared UI + utility library |
| qbx_core | Qbox framework core |
| ox_target | Third-eye interaction |
| city_inventory | Inventory (our own, in `[local]/`; replaces ox_inventory) |
| pma-voice | Proximity voice |

## Layout

```
artifacts/                  FXServer build: run.sh + alpine/ (gitignored)
server-data/                everything the server loads
  server.cfg                main config
  secrets.cfg.example       template for keys / DB string -> copy to secrets.cfg
  resources/
    [cfx-default]/          default cfx resources (chat, spawnmanager, ...)
    [ox]/                   ox stack
    [qbx]/                  Qbox resources
    [voice]/                pma-voice
    [standalone]/           third-party scripts not tied to a framework
    [maps]/                 MLOs and map edits
    [local]/                our own resources (start new ones here)
docker/                     Dockerfile for the FXServer container
scripts/                    setup helpers
docker-compose.yml          FXServer + txAdmin and MariaDB
.env.example                Docker settings -> copy to .env
```

## Running with Docker

`docker-compose.yml` runs FXServer with txAdmin and MariaDB, using `server-data/` straight from the repo.
The full guide (first start, txAdmin setup, everyday commands, updates, backups, troubleshooting) is in
**[docs/docker.md](docs/docker.md)**. In short:

```sh
cp .env.example .env              # license key + database password
docker compose up -d --build
bash scripts/import-sql.sh        # the other resources' tables
docker compose logs fxserver | grep -i pin   # then http://localhost:40120 -> Existing Server Data -> /server-data
```

**Apple Silicon Macs can't run the server** (FXServer is x86_64 only); use a Windows PC or an x86_64 Linux machine.
The scripts on the server and their known issues are listed in [docs/scripts/](docs/scripts/README.md).

## First-time setup (without Docker)

1. **Server artifacts** – download the latest recommended FXServer build from
   <https://runtime.fivem.net/artifacts/fivem/> and extract it into `artifacts/`.
2. **Database** – install MariaDB (or MySQL 8) and create a database, e.g. `fivem_city`.
3. **Secrets** – `cp server-data/secrets.cfg.example server-data/secrets.cfg` and fill in your
   [license key](https://portal.cfx.re) and `mysql_connection_string`.
4. **Resources** – run `./scripts/install-resources.sh` (needs `git`, `curl`, `unzip`).
5. **SQL** – import `server-data/resources/[qbx]/qbx_core/qbx_core.sql` into the database.
6. **Run** – from `server-data/`:
   ```sh
   ../artifacts/run.sh +exec server.cfg            # Linux
   ..\artifacts\FXServer.exe +exec server.cfg      # Windows
   ```
7. **Admin** – connect once, grab your `license:` identifier from the console and add it
   at the bottom of `server-data/server.cfg`.

## Adding resources

- Our own code goes in `server-data/resources/[local]/` — `city_base` is a starter template.
- Qbox scripts (`qbx_*`) go in `server-data/resources/[qbx]/`, everything else in `[standalone]/`.
- Every `[group]` folder is started by `server.cfg`, so dropping a resource in is enough.
