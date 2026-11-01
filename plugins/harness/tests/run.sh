#!/usr/bin/env bash
# Self-check for bin/ scripts: bash plugins/harness/tests/run.sh (needs git, go, jq). Exits non-zero on the first failure.
set -euo pipefail
bin="$(cd "$(dirname "$0")/../bin" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
fail() { echo "FAIL: $*" >&2; exit 1; }
eq() { [ "$1" = "$2" ] || fail "$3: got [$1], want [$2]"; }

# repo <dir> <harness.md body>: git repo with an origin, main pushed
repo() {
    git init -q --bare "$1.git"; git init -q -b main "$1"
    mkdir -p "$1/.claude"; printf '%s\n' "$2" > "$1/.claude/harness.md"
    (cd "$1" && git remote add origin "$1.git" && git add -A && git commit -qm init && git push -q origin main)
}

# --- harness-config: markdown stripped (#1, #5)
repo "$tmp/cfg" '## Scripts
test_file_glob: `**/*_test.go`
red_check_test_cmd: `go test -count=1`   <!-- red-check appends the packages -->
setup-worktree:    <!-- none; bin/ is gitignored -->
test: make check
empty:
exclude_from_size: `:(exclude,glob)**/*_test.go` `:!go.sum`'
cd "$tmp/cfg"
eq "$("$bin/harness-config" key test_file_glob)" '**/*_test.go' "backticked glob"
eq "$("$bin/harness-config" key red_check_test_cmd)" 'go test -count=1' "backticks + comment"
eq "$("$bin/harness-config" key setup-worktree)" '' "comment-only value"
eq "$("$bin/harness-config" key test)" 'make check' "plain value"
eq "$("$bin/harness-config" key empty)" '' "empty value"
eq "$("$bin/harness-config" key exclude_from_size)" '`:(exclude,glob)**/*_test.go` `:!go.sum`' "several spans kept"

# --- harness-red-check on Go (#2, #4)
go_cfg='## Scripts
test_file_glob: `**/*_test.go`
red_check_test_cmd: `go test -count=1`   <!-- appends packages -->'
repo "$tmp/go" "$go_cfg"
cd "$tmp/go"
printf 'module x\n\ngo 1.21\n' > go.mod
mkdir a b
printf 'package a\n\nfunc one() int { return 1 }\n' > a/a.go
printf 'package b\n\nfunc two() int { return 2 }\n' > b/b.go
git add -A && git commit -qm base && git push -q origin main

# behaviour change in two packages, tests use unexported symbols
git checkout -qb fix/1
printf 'package a\n\nfunc one() int { return 11 }\n' > a/a.go
printf 'package b\n\nfunc two() int { return 22 }\n' > b/b.go
printf 'package a\n\nimport "testing"\n\nfunc TestOne(t *testing.T) { if one() != 11 { t.Fatal(one()) } }\n' > a/a_test.go
printf 'package b\n\nimport "testing"\n\nfunc TestTwo(t *testing.T) { if two() != 22 { t.Fatal(two()) } }\n' > b/b_test.go
git add -A && git commit -qm fix
rc=0; out=$("$bin/harness-red-check" "$tmp/go" main 2>&1) || rc=$?
eq "$rc" 0 "go multi-package red-check exit ($out)"

# {files} still gets file paths
rc=0; RED_CHECK_TEST_CMD="echo {files} > $tmp/args; exit 1" "$bin/harness-red-check" "$tmp/go" main >/dev/null 2>&1 || rc=$?
eq "$rc" 2 "{files} run exit"
eq "$(cat "$tmp/args")" 'a/a_test.go b/b_test.go' "{files} expansion"

# additive API: no stub → compile red (5); stub commit → valid red (0)
git checkout -q main && git checkout -qb feature/2
printf 'package a\n\nfunc one() int { return 1 }\n\nfunc Double(n int) int { return 0 }\n' > a/a.go
git add -A && git commit -qm stub; stub=$(git rev-parse HEAD)
printf 'package a\n\nfunc one() int { return 1 }\n\nfunc Double(n int) int { return 2 * n }\n' > a/a.go
printf 'package a\n\nimport "testing"\n\nfunc TestDouble(t *testing.T) { if Double(2) != 4 { t.Fatal() } }\n' > a/a_test.go
git add -A && git commit -qm double
rc=0; "$bin/harness-red-check" "$tmp/go" main >/dev/null 2>&1 || rc=$?
eq "$rc" 5 "additive API without stub"
rc=0; out=$("$bin/harness-red-check" "$tmp/go" main "$stub" 2>&1) || rc=$?
eq "$rc" 0 "additive API with stub commit ($out)"
eq "$(git status --porcelain)" '' "tree restored"

# --- harness-worktree add: setup-worktree comments (#5)
for setup in 'setup-worktree:    <!-- none -->' 'setup-worktree: `touch marker`   <!-- trailing -->'; do
    rm -rf "$tmp/wt" "$tmp/wt.git"
    repo "$tmp/wt" "## Commands
$setup"
    cd "$tmp/wt"
    rc=0; wt=$("$bin/harness-worktree" add issue-1 --branch fix/1-x 2>"$tmp/err") || rc=$?
    eq "$rc" 0 "worktree add with [$setup] ($(cat "$tmp/err"))"
    case "$setup" in *marker*) [ -f "$wt/marker" ] || fail "setup command did not run" ;; esac
done

# --- harness-guard: PreToolUse deny in harness scope, allow outside (#15)
R=/r; W=$R/.user/worktrees/issue-1
# guard <cwd> <tool> <tool_input json> → the deny reason, or "" when allowed
guard() {
    local out
    out=$(jq -nc --arg cwd "$1" --arg t "$2" --argjson i "$3" --arg a "${AGENT:-}" \
        '{hook_event_name: "PreToolUse", cwd: $cwd, tool_name: $t, tool_input: $i} + if $a == "" then {} else {agent_type: $a, agent_id: "a1"} end' |
        "$bin/harness-guard") || fail "guard exit non-zero for $2 $3"
    [ -z "$out" ] || jq -er 'select(.hookSpecificOutput.permissionDecision == "deny") | .hookSpecificOutput.permissionDecisionReason' <<<"$out" ||
        fail "guard output not a deny: $out"
}
bash_in() { jq -nc --arg c "$1" '{command: $c}'; }
file_in() { jq -nc --arg f "$1" '{file_path: $f, old_string: "a", new_string: "b"}'; }
denies() { # denies <brief> <cwd> <tool> <input>
    local r; r=$(guard "$2" "$3" "$4"); [ -n "$r" ] || fail "not denied: $3 $4 (cwd $2)"
    case $r in *"$1"*) ;; *) fail "reason lacks $1: $r" ;; esac
}
allows() { eq "$(guard "$1" "$2" "$3")" '' "allowed: $2 $3 (cwd $1)"; }

bad_bash=(
    'git push -f origin fix/1-x' 'git push origin fix/1-x --force' 'git push --force-with-lease origin fix/1-x'
    'git push --force-with-lease=fix/1-x:abc origin fix/1-x' 'git push -uf origin fix/1-x' 'git push origin +fix/1-x'
    'git -C /r/.user/worktrees/issue-1 push --force' 'cd /r/.user/worktrees/issue-1 && git status && git push -f'
    'git push "--force"' 'FOO=1 git push -f'
    'gh pr merge 12 --squash' 'gh pr ready 12' 'gh pr review 12 --approve' 'echo x; gh pr merge 12'
    'git commit --no-verify -m x' 'git commit -n -m x' 'git commit -anm x' 'git add a && git commit -m "x" --no-verify'
)
for c in "${bad_bash[@]}"; do
    case $c in *push*) b=git-rules.md ;; gh*|*'gh pr'*) b=adapters/github.md ;; *) b=git-rules.md ;; esac
    denies "$b" "$W" Bash "$(bash_in "$c")"
done
denies git-rules.md /elsewhere Bash "$(bash_in 'cd /r/.user/worktrees/issue-1 && git push -f')" # scope via command text
denies git-rules.md /elsewhere Bash "$(bash_in 'git -C .user/worktrees/issue-1 push -f')"

good_bash=(
    'git push -u origin fix/1-x' 'git commit -m "fix: no -n or --no-verify here, git push -f"' 'git commit -m -n'
    'git commit -F msg.txt' 'gh pr create --draft --title x' 'gh pr view 12' 'gh pr review 12 --comment -b ok'
    'git worktree remove --force /r/.user/worktrees/issue-1' 'echo "git push -f"' 'git merge origin/main'
    "git commit -m \"\$(cat <<'EOF'
fix: x

gh pr merge is not run here
EOF
)\""
)
for c in "${good_bash[@]}"; do allows "$W" Bash "$(bash_in "$c")"; done
for c in "${bad_bash[@]}"; do # same calls, interactive session outside any worktree
    case $c in *.user/worktrees*) continue ;; esac
    allows /home/me/proj Bash "$(bash_in "$c")"
done

for f in go.mod go.sum composer.lock package-lock.json yarn.lock pnpm-lock.yaml Cargo.lock sub/dir/Gemfile.lock; do
    for t in Edit Write MultiEdit; do denies implementer.md "$W" "$t" "$(file_in "$W/$f")"; done
    denies implementer.md /elsewhere Write "$(file_in "$W/$f")"
    allows /home/me/proj Edit "$(file_in "/home/me/proj/$f")"
done
denies implementer.md "$W" Edit "$(file_in go.mod)" # relative to cwd
for f in "$R/.user/worktrees/_main/a.go" "$R/.user/worktrees/_main/go.mod" "$W/../_main/x" "$R/.user/worktrees/_main"; do
    denies verifier.md "$W" Write "$(file_in "$f")"
done
denies verifier.md "$W" NotebookEdit "$(jq -nc --arg f "$R/.user/worktrees/_main/n.ipynb" '{notebook_path: $f}')"
allows "$W" Edit "$(file_in "$W/a.go")"
allows "$W" Write "$(file_in "$W/go.mod.txt")"
allows "$W" Edit "$(file_in "$R/.user/reports/issue-1.md")"
allows /home/me/proj Write "$(file_in "/home/me/proj/.user/worktrees-old/_main/x")"
allows "$W" Read "$(file_in "$R/.user/worktrees/_main/go.mod")"
eq "$(printf 'not json' | "$bin/harness-guard"; echo "rc=$?")" 'rc=0' "guard fails open on bad input"

# agent-type scope: harness:* sub-agents are checked anywhere; other agent types only by path (as above)
for c in "${bad_bash[@]}"; do AGENT=harness:implementer denies harness-guard /home/me/proj Bash "$(bash_in "$c")"; done
AGENT=harness:verifier denies implementer.md /home/me/proj Edit "$(file_in /home/me/proj/go.mod)"
AGENT=harness:triager allows /home/me/proj Bash "$(bash_in 'gh issue edit 3 --add-label needs-info')"
AGENT=harness:implementer allows /home/me/proj Edit "$(file_in /home/me/proj/a.go)"
for c in "${bad_bash[@]}"; do
    case $c in *.user/worktrees*) continue ;; esac
    AGENT=general-purpose allows /home/me/proj Bash "$(bash_in "$c")"
done

# --- plugin agents (#15): read-only roles can't edit; /harness:work spawns them
agents="$(cd "$bin/../agents" && pwd)"
fm() { sed -n '2,/^---$/p' "$agents/$1.md"; } # frontmatter
for a in triager verifier implementer; do
    [ -f "$agents/$a.md" ] || fail "agents/$a.md missing"
    fm "$a" | grep -qx "name: $a" || fail "agents/$a.md name"
done
for a in triager verifier; do
    d=$(fm "$a" | sed -n 's/^disallowedTools: //p')
    for t in Edit Write MultiEdit NotebookEdit; do case ", $d," in *", $t,"*) ;; *) fail "agents/$a.md does not disallow $t" ;; esac; done
    fm "$a" | grep -q '^tools:' && fail "agents/$a.md: use disallowedTools, not tools (keeps MCP tools)"
done
fm implementer | grep -q '^disallowedTools:' && fail "implementer must keep its edit tools"
work="$bin/../skills/work/SKILL.md"
grep -q 'subagent_type: "general-purpose"' "$work" && fail "work skill still spawns general-purpose"
for a in triager implementer verifier; do grep -q "harness:$a" "$work" || fail "work skill does not spawn harness:$a"; done

# --- settings deny backstop (#15): force-push variants and merge/ready in the template; init merges, doctor checks
base="$bin/../templates/settings.base.json"
for d in 'Bash(git push --force:*)' 'Bash(git push -f:*)' 'Bash(git push --force-with-lease:*)' 'Bash(git push * --force*)' \
    'Bash(git push * -f*)' 'Bash(gh pr merge:*)' 'Bash(gh pr ready:*)'; do
    jq -e --arg d "$d" '.permissions.deny | index($d)' "$base" >/dev/null || fail "settings.base.json deny lacks $d"
done
jq -e '[.permissions.deny[] | test("^[A-Za-z]+\\(.+\\)$")] | all' "$base" >/dev/null || fail "invalid deny entry syntax"
grep -q '`deny`' "$bin/../skills/init/SKILL.md" || fail "init step 5 does not merge deny"
grep -q 'missing deny' "$bin/../skills/doctor/SKILL.md" || fail "doctor does not flag missing deny entries"


# --- harness-worktree clean archives the report; harness-sync prunes after 90 days (#13)
repo "$tmp/arch" '## Tracker
forge: none'
cd "$tmp/arch"
"$bin/harness-worktree" add issue-7 --branch fix/7-x >/dev/null
git -C .user/worktrees/issue-7 push -q -u origin fix/7-x
git push -q origin --delete fix/7-x
mkdir -p .user/reports .user/runs .user/reports/archive
echo r > .user/reports/issue-7.md; touch -t 202001010000 .user/reports/issue-7.md
echo old > .user/reports/archive/issue-1-old.md; echo old > .user/runs/old.md
echo new > .user/reports/archive/issue-2-new.md; echo new > .user/runs/new.md
touch -t 202001010000 .user/reports/archive/issue-1-old.md .user/runs/old.md
out="$("$bin/harness-sync")"
case "$out" in *"issue-7 deleted"*) ;; *) fail "sync cleaned issue-7: $out" ;; esac
case "$out" in *"pruned 2"*) ;; *) fail "sync prunes 2: $out" ;; esac
[ ! -e .user/reports/issue-7.md ] || fail "report left in place"
eq "$(cat ".user/reports/archive/issue-7-$(date +%F).md")" r "report archived"
[ ! -e .user/reports/archive/issue-1-old.md ] && [ ! -e .user/runs/old.md ] || fail "old files kept"
out="$("$bin/harness-sync")"
case "$out" in *pruned*) fail "second sync prunes nothing: $out" ;; esac
[ -e ".user/reports/archive/issue-7-$(date +%F).md" ] || fail "archived report pruned by old mtime"
[ -e .user/reports/archive/issue-2-new.md ] && [ -e .user/runs/new.md ] || fail "new files pruned"
echo "ok"
