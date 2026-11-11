---
name: ship
description: Check, preview and ship a change to the fivem-city server - run scripts/check.sh, preview NUI pages in Chrome, review against docs/standards, commit and push, and give in-game test steps. Use when work is done and the user wants it committed/pushed/tested ("commit and push", "ship it", "is it ready?", "/ship").
---

# Ship a change

The server can't run on this Mac (FXServer is x86_64 only), so everything that can be checked without the game is checked here, and the user tests the rest on the server PC.

## 1. Checks (always)

```sh
bash scripts/check.sh
```

Lua syntax of every `[local]` file, `node --check` on UI scripts, locale JSON, and the unit tests in `tests/`. Fix failures before going on; never commit with a failing check. If logic changed in a resource that has tests, add or update a test for it (`tests/<resource>/`, see `tests/city_inventory/harness.lua`).

## 2. Review (for code changes)

Go through the review checklist at the end of each `docs/standards/` file (security, performance, code style) for the files that changed. The usual misses: a server handler without type/distance checks, a client loop without a sleep, a hard-coded color in CSS, a file past ~300 lines.

## 3. Preview NUI (when a `web/` page changed)

1. Make a preview page in the scratchpad that iframes the resource's `web/index.html` and `postMessage`s the same messages the client sends (`setup` with the theme from `city_ui/theme.lua` and labels, then `open`, and any panel messages). Serve the scratchpad and the resource's `web/` from one origin, e.g. a `site/` folder with a symlink to `web/`, and `python3 -m http.server`.
2. Screenshot it with headless Chrome at 1920x1080 and 1600x900:
   `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --user-data-dir=<scratch dir> --window-size=1600,900 --virtual-time-budget=6000 --screenshot=<file> <url>`
3. Look at it (Read the PNG) and fix what's off. When the user wants to see it, open it in their Chrome with `open -a "Google Chrome" <url>`, and stop the server when they're done.

The preview has no game behind it: CSS `backdrop-filter` looks fine there but is black in FiveM, so never rely on it.

## 4. Commit and push (only when the user asked)

- Check `git status` and stage only what belongs to the change (never `.env`, `secrets.cfg`, scratch files).
- Follow `docs/standards/git.md`. Small docs or config fixes go straight to `main` when the user asks to commit and push. Features and anything that needs an in-game test go on a `<type>/<topic>` branch (`feat/player-search`, `fix/fuel-payment`); open the pull request with base **`Cidade_Teste`** (the test server's branch), never `main`, and the user merges. Fixes found in testing are new commits on the same feature branch, merged into `Cidade_Teste` again. Only the user takes a finished branch to `main` (see "Cidade_Teste and main" in `git.md`).
- Message: `<type>(<scope>): <description>` (`feat(inventory): add trunks and gloveboxes`), then a short body saying what changed and why, ending with the attribution trailer the environment gives (`Co-Authored-By: ...`). Split unrelated changes into separate commits.
- `git push` (`-u origin <branch>` the first time). Report the commit hash.

## 5. Tell the user how to test it

On the server PC (Git Bash, in the repo folder):

```sh
git switch Cidade_Teste && git pull   # after the PR into Cidade_Teste is merged
bash scripts/import-sql.sh    # only if a resource added tables
```

Then the reload that fits: `ensure <resource>` in the txAdmin console for one of our resources; a server restart from txAdmin when a vendored script, `server.cfg` or `city_ui` changed; `docker compose up -d --build` only when `docker/` changed. Finish with the concrete in-game steps to try (commands like `/optin`, `/kit`, `/giveitem`, where to go, what should happen), and ask for the red lines from F8 or the txAdmin console if something fails.
