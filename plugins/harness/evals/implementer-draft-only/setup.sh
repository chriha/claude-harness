#!/usr/bin/env bash
# Case setup (run by ../_shared/scaffold.sh in the run dir): the state /harness:work leaves before it spawns an implementer:
# .user/ git-excluded and .user/worktrees/_main (detached origin/main). The implementer creates its own worktree issue-41.
set -euo pipefail
printf '.user/\n' >> .git/info/exclude
git worktree add -q --detach .user/worktrees/_main origin/main
mkdir -p .user/reports
