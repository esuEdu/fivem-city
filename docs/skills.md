# Skills

Every Claude Code skill this project uses: the ones we wrote for fivem-city, and the ones that come from somewhere else. Call a skill with `/<name>` or just ask for the task.

The `skill-registry` agent (`.claude/agents/skill-registry.md`) keeps this list up to date. It runs as soon as someone starts a new skill, and also when one is renamed, moved or removed. Don't edit the "Ours" table by hand without updating the skill's `SKILL.md` too: the table copies its `name` and `description`.

## Ours

Written for this project and committed in the repo.

| Name | Description | Location |
| --- | --- | --- |
| `add-item` | Add or change an item, weapon, ammo, attachment, crafting recipe, test kit or shop entry in city_inventory. | `.claude/skills/add-item/` |
| `new-resource` | Create a new `city_<feature>` script in `server-data/resources/[local]/` following the project standards. | `.claude/skills/new-resource/` |
| `patch-script` | Change a vendored script (qbx_*, ox_*, npwd, [standalone]) as `scripts/patches/<resource>.patch` so the change survives updates. | `.claude/skills/patch-script/` |
| `replace-script` | Replace a vendored script with our own `city_<feature>` resource and remove the old one everywhere. | `.claude/skills/replace-script/` |
| `ship` | Run `scripts/check.sh`, preview NUI pages in Chrome, review against `docs/standards`, commit and push, give in-game test steps. | `.claude/skills/ship/` |

## Not ours

Built into Claude Code or installed from elsewhere. Not in the repo: each person's machine or claude.ai account decides which are available.

| Name | Description | Location |
| --- | --- | --- |
| `code-review` | Review the current diff or a PR for bugs (`ultra` = deep multi-agent review in the cloud). | Built into Claude Code |
| `security-review` | Security review of the pending changes on the current branch. | Built into Claude Code |
| `simplify` | Review changed code for reuse and simplification, then apply the fixes. | Built into Claude Code |
| `run` | Launch the app to see a change working. | Built into Claude Code |
| `init` | Create a CLAUDE.md for a codebase. | Built into Claude Code |
| `claude-in-chrome` | Drive Chrome: open pages, click, screenshot, read the console (`ship` uses it to preview NUI pages). | Built into Claude Code |
| `update-config`, `keybindings-help`, `fewer-permission-prompts` | Change Claude Code settings, hooks, permissions and shortcuts. | Built into Claude Code |
| `loop`, `schedule` | Repeat a task on an interval, or run cloud agents on a schedule. | Built into Claude Code |
| `artifact-design`, `artifact-capabilities`, `artifact-diagramming`, `dataviz` | Make claude.ai artifact pages, diagrams and charts (e.g. design mockups). | Built into Claude Code |
| `plugin-authoring`, `claude-api` | Make Claude Code mods; Claude API reference. | Built into Claude Code |
| `anthropic-skills:*` (`docx`, `pdf`, `pptx`, `xlsx`, `docs`, `deep-research`, `skill-creator`, `mcp-builder`, …) | Office files, PDFs, docs, research, making new skills and MCP servers. | claude.ai account (synced) |
| `cowork-plugin-management:*` | Create or customize Claude plugins. | claude.ai account (synced) |
| `figma:*` | Figma design ↔ code, libraries, diagrams. | Plugin `figma@claude-plugins-official`, `~/.claude/plugins/cache/claude-plugins-official/figma/` |
| `hbk-dls-ios` | DSKit SwiftUI design system (another project, not fivem-city). | User skill, `~/.claude/skills/hbk-dls-ios/` |
