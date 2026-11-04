# Running the server with Docker

The server runs in two containers from `docker-compose.yml` in the repo root:

- **fxserver**: FXServer with txAdmin. It runs the `server-data/` folder straight from the repo (mounted at `/server-data`), so a `git pull` is all it takes to get new code.
- **mariadb**: the database.

FXServer is x86_64 only: run this on a Windows PC or an x86_64 Linux machine. **It does not run on Apple Silicon Macs** (it crashes under both Rosetta and QEMU). A Mac can still be used to edit the code.

## What you need

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) on Windows (with WSL 2), or Docker Engine + the Compose plugin on Linux.
- Git. On Windows, use **Git Bash** for the commands below.
- A Cfx.re server license key from <https://portal.cfx.re> → Server Registration Keys.

## First start

1. **Get the code**
   ```sh
   git clone https://github.com/esuEdu/fivem-city.git
   cd fivem-city
   ```
2. **Settings**: copy the example and fill it in.
   ```sh
   cp .env.example .env
   ```
   | Setting | What to put |
   |---|---|
   | `CFX_LICENSE_KEY` | Your license key. |
   | `MYSQL_ROOT_PASSWORD` | Any password, **letters and numbers only** (it goes into a connection URL). |
   | `MYSQL_DATABASE` | Leave `fivem_city`. |

   `.env` is never committed. The container writes `server-data/secrets.cfg` from it on every start.
3. **Build and start**
   ```sh
   docker compose up -d --build
   ```
   The first build downloads FXServer and takes a few minutes. The database is created on this first start, with qbx_core's tables.
4. **Create the other tables** (banking, appearance, phone, vehicles, houses, …):
   ```sh
   bash scripts/import-sql.sh
   ```
   Safe to run again at any time; it never deletes data.
5. **Set up txAdmin**
   1. Get the PIN: `docker compose logs fxserver | grep -i pin`
   2. Open <http://localhost:40120>, enter the PIN and link your Cfx.re account.
   3. In the setup wizard choose **Existing Server Data**, path **`/server-data`**, config **`server.cfg`**.

      ⚠️ Don't pick a recipe (like "Qbox"): it installs its own copy of the server under `/txData`, which ignores this repo. If you did, go to txAdmin → Settings → FXServer and set the Server Data Folder to `/server-data`.
   4. Start the server from txAdmin.
6. **Make yourself admin**: join the server once, find your `license:` identifier in txAdmin (Players → you), add this line at the bottom of `server-data/server.cfg`, and restart:
   ```
   add_principal identifier.license:YOUR_LICENSE_HERE group.admin
   ```
   In game, `/optin` turns admin duty on (needed for admin commands like `/kit` and `/giveitem`).

Players connect to your PC's IP on port **30120** (open/forward 30120 TCP+UDP on your router to play from outside).

## Everyday use

| To… | Run |
|---|---|
| Get the latest code | `git pull`, then in the txAdmin console `ensure <resource>` for what changed, or restart the server from txAdmin |
| See the server log | `docker compose logs -f fxserver` (or the txAdmin console) |
| Restart the server | from txAdmin, or `docker compose restart fxserver` |
| Stop everything | `docker compose down` (the data is kept) |
| Start again | `docker compose up -d` |
| After new resources with SQL | `bash scripts/import-sql.sh` |

Changing a file in `server-data/` takes effect after `ensure <resource>` (or a server restart); no rebuild is needed. Only rebuild for FXServer updates or changes under `docker/`.

## Updating

- **FXServer** (new build): `docker compose build --no-cache fxserver && docker compose up -d`. To pin a specific build, set `FIVEM_ARTIFACT_URL` in `.env` (see `.env.example`).
- **Third-party scripts** (Qbox, ox, …): `bash scripts/install-resources.sh` re-downloads them all and re-applies our patches in `scripts/patches/`; then `bash scripts/import-sql.sh` and restart. Commit the result.

## Where the data lives

| Volume | Holds |
|---|---|
| `dbdata` | The database: characters, money, inventories, vehicles, houses. |
| `txdata` | txAdmin: its admins, settings and logs. |

They survive `docker compose down`, rebuilds and updates. **`docker compose down -v` deletes them**, which wipes every character. Only do that to start completely fresh.

**Backing up the database:**
```sh
docker compose exec -T mariadb sh -c 'mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" "$MARIADB_DATABASE"' > backup.sql
```

**Opening the database with a tool** (HeidiSQL, DBeaver): add `ports: ["127.0.0.1:3307:3306"]` under `mariadb` in `docker-compose.yml`, run `docker compose up -d`, then connect to `127.0.0.1:3307` as `root`. It isn't exposed by default so it can't clash with a local MySQL/XAMPP on 3306.

## Troubleshooting

| Problem | Fix |
|---|---|
| `ensure city_inventory` says *Couldn't find resource* / the old inventory shows | txAdmin is running a recipe copy: set the Server Data Folder to `/server-data` (see step 5). |
| `Error relocating … symbol not found` | FXServer was mounted from a Windows drive; it must come from the image (don't mount `artifacts/`). |
| Restart loop with `Stack overflow in unmanaged` | You're on an Apple Silicon Mac; use an x86_64 PC. |
| Database connection errors | Use only letters and numbers in `MYSQL_ROOT_PASSWORD`. If you changed it after the first start, the database still has the old one: put the old one back, or `docker compose down -v` to start over (wipes data). |
| A script errors about a missing table | `bash scripts/import-sql.sh` |
| Port 30120 or 40120 already in use | Stop the other FXServer/txAdmin, or change the left side of the port in `docker-compose.yml`. |
