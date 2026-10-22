---
name: doctor
description: Check this repo's harness setup — missing config, overrides that drifted from the plugin, copied pack rules that differ from upstream, invalid permission entries, stale per-project pipeline copies
disable-model-invocation: true
allowed-tools: Read, Grep, Glob, AskUserQuestion, Edit, Bash(ls:*), Bash(diff:*), Bash(jq:*), Bash(git log:*), Bash(git status:*), Bash(harness-*:*)
---

Read-only report first, fixes only after I pick them. Plugin root: `${CLAUDE_PLUGIN_ROOT}`.

1. **Config:** `.claude/harness.md` exists; required keys non-empty (`test:`, `test_file_glob:`, `red_check_test_cmd:`); `tracker:`/`forge:`
   adapters resolve (`harness-resolve adapters/<name>.md`); `.user/` ignored; each command in § Commands actually exists (check the binary / script).
2. **Overrides:** every file under `.claude/harness/` — diff against the plugin file of the same path. Report: *identical* (delete it),
   *differs* (summarise the delta in one line; flag when the plugin default changed after the override was made: compare `git log -1` dates),
   *orphan* (no plugin counterpart — fine for custom adapters/domains).
3. **Pack drift:** for each `.claude/rules/*.md` and `.githooks/*` that exists in `packs/<stack>/`, diff against upstream. List
   `upstream has newer lines` vs `project-specific edits`; offer to apply upstream hunks I choose.
4. **Permissions:** `.claude/settings.json` + `settings.local.json`: entries that are not valid `Tool(pattern)` syntax (e.g. `Bash(git push and git merge:*)`),
   duplicates, over-broad writers (`Bash(git push:*)` in project settings → flag).
5. **Stale copies:** old per-project pipeline commands/briefs/scripts as in `/harness:init` step 7.
6. Print a table `check | status | action`, then ask which fixes to apply.
