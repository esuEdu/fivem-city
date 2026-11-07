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
   | `YOUTUBE_API_KEY` | Optional. A YouTube Data API v3 key (Google Cloud console → APIs & Services → enable "YouTube Data API v3" → Credentials → API key), so the phone's Music app can search songs by title. The free quota is about 100 searches a day; repeated searches are cached. Without it, players paste links. After changing it: `docker compose up -d` (a restart doesn't read `.env` again). |

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
5. **Set up txAdmin** (only the first time; see [First-time txAdmin setup](#first-time-txadmin-setup) below for every screen)
   1. Get the PIN: `docker compose logs fxserver | grep -i pin`
   2. Open <http://localhost:40120>, enter the PIN, log in with your Cfx.re account and create the master admin password.
   3. In the setup wizard choose **Existing Server Data**, folder **`/server-data`**, config **`server.cfg`**. ⚠️ Not a recipe.
   4. Save and start the server.
6. **Make yourself admin**: join the server once, find your `license:` identifier in txAdmin (Players → you), add this line at the bottom of `server-data/server.cfg`, and restart:
   ```
   add_principal identifier.license:YOUR_LICENSE_HERE group.admin
   ```
   In game, `/optin` turns admin duty on (needed for admin commands like `/kit` and `/giveitem`).

Players connect to your PC's IP on port **30120** (open/forward 30120 TCP+UDP on your router to play from outside).

## First-time txAdmin setup

The first time you open <http://localhost:40120> (and again if the `txdata` volume is deleted), txAdmin walks you through these screens. Names can change a little between txAdmin versions; the choices are what matter.

| Screen | What to do |
|---|---|
| **PIN** | Enter the 4-digit PIN from `docker compose logs fxserver \| grep -i pin`. It changes every time the container starts until setup is done. |
| **Cfx.re login** | "Link Account" and log in with your Cfx.re (FiveM forum) account. That account becomes the master admin, and lets the in-game `/tx` menu recognise you. |
| **Master account password** | Pick a password for logging into txAdmin with a username (backup login). Keep it somewhere safe. |
| **Server name** | Anything (e.g. `fivem-city`). Only shown inside txAdmin; the name players see is `sv_hostname` in `server.cfg`. |
| **Deployment type** | **Existing Server Data**. Don't pick *Popular Recipes* (e.g. Qbox) or *Remote URL*: those download their own copy of a server under `/txData` and ignore this repo. |
| **Server Data Folder** | `/server-data` (the repo's `server-data/`, mounted into the container). txAdmin checks it finds a `resources` folder there. |
| **CFG File** | `server.cfg`. txAdmin reads it to check it's valid. |
| **Finish** | "Save & Run Server". The server starts; the **Live Console** shows it loading. |

You don't need the database step: the database connection comes from `.env` (the container writes it into `server-data/secrets.cfg`). The `TXHOST_DEFAULT_DB*` settings in `docker-compose.yml` only pre-fill that step for recipes.

**After the wizard, check these in txAdmin:**

- **Settings → FXServer**: Server Data Folder = `/server-data`, CFG File Path = `server.cfg`, and **Autostart** on, so the server starts with the container.
- **Settings → Restarter** (optional): scheduled restarts, e.g. once a day at a quiet hour; txAdmin warns players before and the inventory saves on shutdown.
- **Admin Manager**: add your friends who help run the server as admins, with their Cfx.re or Discord identifiers, so they can use the txAdmin web panel and the in-game `/tx` menu. (In-game admin commands like `/kit` use the `group.admin` lines in `server.cfg` instead; see step 6.)

If the server ever runs the wrong files (old inventory, *Couldn't find resource city_inventory*), it's almost always **Settings → FXServer → Server Data Folder** pointing at a recipe folder under `/txData` instead of `/server-data`.

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
