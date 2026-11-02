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

## Running with Docker + txAdmin

`docker-compose.yml` runs two containers: FXServer with txAdmin, and MariaDB.

1. Download the **Linux** artifact (`fx.tar.xz`) from
   <https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/> and extract it into
   `artifacts/` so you have `artifacts/run.sh` and `artifacts/alpine/`.
   On Windows extract it from Git Bash with `tar -xf fx.tar.xz` — 7-Zip/WinRAR break the symlinks.
   To update FXServer later, replace those two and run `docker compose restart fxserver`.
2. `cp .env.example .env` and set a database password.
3. `cp server-data/secrets.cfg.example server-data/secrets.cfg`, add your [license key](https://portal.cfx.re)
   and use the same password in `mysql_connection_string` (host `mariadb`).
4. `./scripts/install-resources.sh`
5. `docker compose up -d --build`
6. Get the txAdmin PIN: `docker compose logs fxserver | grep -i pin`
7. Open <http://localhost:40120>, enter the PIN, link your Cfx.re account, then in the setup wizard
   choose **Existing Server Data** with path `/server-data` and config `server.cfg`.
8. Import the Qbox tables once:
   ```sh
   docker compose exec -T mariadb sh -c 'mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' \
     < "server-data/resources/[qbx]/qbx_core/qbx_core.sql"
   ```

Useful commands: `docker compose logs -f fxserver`, `docker compose restart fxserver`,
`docker compose down` (data is kept in the `txdata` and `dbdata` volumes).

**Apple Silicon Macs are not supported.** FXServer is x86_64 only and crashes under both
Rosetta and QEMU emulation (`Stack overflow in unmanaged`, restart loop). Run the server on a
Windows PC or an x86_64 Linux machine/VPS; a Mac can still be used to edit `server-data/resources/`.

## Prebuilt image (run on another PC)

The private image `ghcr.io/esuedu/fivem-city` contains FXServer, `server.cfg` and all resources.
Secrets are never baked in; they come from `.env`.

**Build and push** (from this repo, after `./scripts/install-resources.sh`):
```sh
docker login ghcr.io -u esuEdu   # token needs write:packages
docker buildx build --platform linux/amd64 -f docker/fxserver/Dockerfile \
  -t ghcr.io/esuedu/fivem-city:latest --push .
```

**Run on the server PC** (x86_64 Windows/Linux with Docker):
1. Copy the `deploy/` folder to that PC.
2. `cp .env.example .env` and set `CFX_LICENSE_KEY` and `MYSQL_ROOT_PASSWORD`.
3. `docker login ghcr.io -u esuEdu` with a token that has `read:packages`.
4. `docker compose up -d` — the Qbox tables are imported automatically on first start.
5. Get the txAdmin PIN with `docker compose logs fxserver | grep -i pin`, open
   <http://localhost:40120> and pick **Existing Server Data** → `/server-data` → `server.cfg`.

To update: push a new image, then `docker compose pull && docker compose up -d` on the server PC.
Changes made inside the container to `/server-data` are lost on update; commit them to the repo instead.

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
