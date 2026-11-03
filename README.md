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

FXServer is downloaded inside the image build (the current recommended Linux build, or
`FIVEM_ARTIFACT_URL` from `.env`), so `artifacts/` is not used here. Don't mount a Linux artifact
from a Windows drive: NTFS breaks its symlinks (`Error relocating ... symbol not found`).
To update FXServer, run `docker compose build --no-cache fxserver && docker compose up -d`.

1. `cp .env.example .env` and set your [license key](https://portal.cfx.re) and a database password.
   `server-data/secrets.cfg` is written from it on every start.
2. `docker compose up -d --build` — the Qbox tables are imported the first time the database is created.
3. Get the txAdmin PIN: `docker compose logs fxserver | grep -i pin`
4. Open <http://localhost:40120>, enter the PIN, link your Cfx.re account, then in the setup wizard
   choose **Existing Server Data** with path `/server-data` and config `server.cfg`.

Resources are committed; run `./scripts/install-resources.sh` only to update them.

Useful commands: `docker compose logs -f fxserver`, `docker compose restart fxserver`,
`docker compose down` (data is kept in the `txdata` and `dbdata` volumes).

**Apple Silicon Macs are not supported.** FXServer is x86_64 only and crashes under both
Rosetta and QEMU emulation (`Stack overflow in unmanaged`, restart loop). Run the server on a
Windows PC or an x86_64 Linux machine/VPS; a Mac can still be used to edit `server-data/resources/`.

## Letting friends join through Cloudflare

FiveM players connect over UDP, which a public Cloudflare Tunnel hostname can't carry. Instead the
tunnel exposes the server as a *private network* and friends reach it with the free Cloudflare WARP app.
The server always has the address `172.30.50.10` inside Docker.

**Cloudflare dashboard (once)** — <https://one.dash.cloudflare.com>, free Zero Trust plan:
1. **Networks → Tunnels → Create a tunnel → Cloudflared**, name it `fivem-city`. Copy the token from the
   install command (the long `eyJ...` value) into `.env`:
   ```
   COMPOSE_PROFILES=tunnel
   CLOUDFLARE_TUNNEL_TOKEN=eyJ...
   ```
   then `docker compose up -d`. The tunnel should show **Healthy** in the dashboard.
2. In the tunnel, **CIDR / Private networks → Add** `172.30.50.10/32`.
3. **Settings → Network → Firewall/Proxy**: enable the proxy with **TCP** and **UDP**.
4. **Settings → WARP Client → Device enrollment permissions → Manage**: add a rule allowing your
   friend's email (login method: One-time PIN).
5. **Settings → WARP Client → Device settings → Default profile → Split Tunnels**: remove
   `172.16.0.0/12` from the Exclude list, otherwise WARP skips the server's address.

**Your friend:**
1. Install the Cloudflare WARP / Cloudflare One app from <https://1.1.1.1>.
2. Preferences → Account → **Login to Cloudflare Zero Trust**, enter your team name, then the
   PIN emailed to them. Turn WARP on.
3. In FiveM press F8 and run `connect 172.30.50.10:30120`.

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
