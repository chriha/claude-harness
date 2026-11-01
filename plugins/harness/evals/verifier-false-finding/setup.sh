#!/usr/bin/env bash
# Case setup (run by ../_shared/scaffold.sh in the run dir): the state /harness:work leaves when it spawns a verifier.
# .user/worktrees/_main (detached origin/main), the source ticket's worktree issue-21 with its fix committed, and its report
# whose ## Findings holds one false finding: test.sh does stop on a failing test (set -e), so the verdict must be invalid.
set -euo pipefail
c() { git -c user.name="Eval" -c user.email="eval@example.invalid" "$@"; }
printf '.user/\n' >> .git/info/exclude
git worktree add -q --detach .user/worktrees/_main origin/main
git worktree add -q -b fix/21-farewell-exit-code .user/worktrees/issue-21 origin/main
(
    cd .user/worktrees/issue-21
    sed -i.bak 's/exit 0/exit 2/' farewell.sh && rm farewell.sh.bak
    printf 'rc=0; bash farewell.sh 2>/dev/null || rc=$?; eq "$rc" 2 "farewell without a name exits 2"\n' >> tests/farewell.sh
    c commit -qam "fix: exit 2 when farewell gets no name" -m "Refs #21"
)
mkdir -p .user/reports
cat > .user/reports/issue-21.md <<'REPORT'
## Status
done
## Commits
fix: exit 2 when farewell gets no name
## Touched
- farewell.sh — exit 2 on a missing name
- tests/farewell.sh — case for the missing name
## Tests
- `bash test.sh` → ok
## Review
none
## Verify
not run
## Open
none
## Findings
- **test.sh passes when a test fails** — test.sh:5 — the `for` loop ignores the exit status of `bash "$t"`, so a failing tests/*.sh still ends with `ok` and exit 0; expected test.sh to exit non-zero on the first failure, as its header says.
REPORT
