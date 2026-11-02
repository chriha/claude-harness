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

# --- harness-worktree clean: keep a fresh branch whose name had a merged PR (#10)
rm -rf "$tmp/cl" "$tmp/cl.git"; repo "$tmp/cl" "## Tracker
forge: github"
mkdir -p "$tmp/fakebin"; printf '#!/bin/sh\necho '"'"'[{"state":"MERGED"}]'"'"'\n' > "$tmp/fakebin/gh"; chmod +x "$tmp/fakebin/gh"
cd "$tmp/cl"
"$bin/harness-worktree" add issue-2 --branch fix/2-fresh >/dev/null
"$bin/harness-worktree" add issue-3 --branch fix/3-pushed >/dev/null
(cd .user/worktrees/issue-3 && echo x > f && git add f && git commit -qm x && git push -qu origin fix/3-pushed)
eq "$(PATH="$tmp/fakebin:$PATH" "$bin/harness-worktree" clean)" "issue-3 merged" "clean removes only the pushed merged branch"
[ -d .user/worktrees/issue-2 ] || fail "fresh worktree was removed"
[ ! -d .user/worktrees/issue-3 ] || fail "pushed merged worktree was kept"

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

# --- harness-check-pr (#12): report check + stubbed gh
repo "$tmp/chk" '## Tracker
forge: github'
cd "$tmp/chk"
git checkout -qb chore/12-x && git commit -q --allow-empty -m c && git push -q origin chore/12-x
head=$(git rev-parse HEAD)
cat > "$tmp/gh" <<STUB
#!/usr/bin/env bash
printf '%s' "\$GH_JSON"
STUB
chmod +x "$tmp/gh"
export GH="$tmp/gh"
GH_JSON="{\"url\":\"u\",\"isDraft\":true,\"body\":\"Closes #12\",\"headRefOid\":\"$head\"}"; export GH_JSON
printf '## Tests\nred-check: red without the fix, green with it (exit 0)\n## Review\n' > "$tmp/r1"
printf '## Tests\nNo behaviour change, exempt.\n' > "$tmp/r2"
printf '## Tests\nran tests\n' > "$tmp/r3"
rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r1") || rc=$?; eq "$out/$rc" "CHECK_OK u/0" "exit-0 line"
rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r2") || rc=$?; eq "$out/$rc" "CHECK_OK u/0" "exemption"
rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r3") || rc=$?
eq "$out/$rc" "CHECK_FAIL u: report ## Tests lacks red-check exit 0 or no-behaviour-change exemption/1" "both missing"
GH_JSON="{\"url\":\"u\",\"isDraft\":false,\"body\":\"x\",\"headRefOid\":\"abc\"}"
rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r1") || rc=$?
eq "$out/$rc" "CHECK_FAIL u: PR is not draft; description lacks closing keyword or Refs for #12; PR head differs from origin/chore/12-x/1" "pr checks"
GH_JSON=""; rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r1") || rc=$?
eq "$out/$rc" "CHECK_FAIL none: no PR for branch/1" "no PR"
printf 'forge: gitlab\n' > "$tmp/chk/.claude/harness.md"
rc=0; out=$("$bin/harness-check-pr" "$tmp/chk" chore/12-x "$tmp/r3") || rc=$?; eq "$out/$rc" "CHECK_SKIPPED (forge gitlab)/0" "other forge"
grep -q 'harness-check-pr' "$bin/../skills/work/SKILL.md" || fail "work skill does not run harness-check-pr"
unset GH GH_JSON

# --- evals (#27): fake gh serves fixtures and logs every call; the scaffold puts it first on PATH
evals="$bin/../evals"
mkdir -p "$tmp/ev/fixtures/issues"
printf '{"number":5,"title":"t","body":"b","state":"OPEN","labels":[],"assignees":[{"login":"eval-bot"}],"comments":[]}\n' \
    > "$tmp/ev/fixtures/issues/5.json"
fgh() { HARNESS_EVAL_DIR="$tmp/ev" bash "$evals/_shared/fake-gh" "$@"; }
eq "$(fgh issue view 5 --json number,title --jq .title)" 't' "fake gh issue view"
eq "$(fgh issue view 5 --json number,title | jq -c .)" '{"number":5,"title":"t"}' "fake gh --json picks fields"
eq "$(fgh issue list --assignee @me --state open --json number | jq -c .)" '[{"number":5}]' "fake gh issue list mine"
eq "$(fgh api user --jq .login)" 'eval-bot' "fake gh user"
eq "$(fgh api --paginate --slurp 'repos/{owner}/{repo}/issues/5/dependencies/blocked_by' | jq -c .)" '[[]]' "fake gh blockers"
printf 'new body' > "$tmp/ev/b.md"; fgh issue edit 5 --add-label needs-info --body-file "$tmp/ev/b.md" >/dev/null
eq "$(cat "$tmp/ev/bodies/5.md")" 'new body' "fake gh keeps the edited body"
fgh issue comment 5 --body 'hi' >/dev/null
eq "$(fgh issue view 5 --json body,labels,comments --jq '[.body, .labels[].name, .comments[].body] | join("/")')" \
    'new body/needs-info/hi' "fake gh read-back sees the writes"
fgh issue edit 5 --remove-label needs-info >/dev/null
eq "$(fgh issue view 5 --jq '[.body, (.labels | length)] | join("/")')" 'new body/0' "label-only edit keeps the body"
rc=0; fgh repo delete x 2>/dev/null || rc=$?; eq "$rc" 1 "fake gh refuses unknown commands"
eq "$(sed -n 's/^issue edit 5 //p' "$tmp/ev/gh.log" | head -1)" "--add-label needs-info --body-file $tmp/ev/b.md" "fake gh logs calls"
eq "$(tail -1 "$tmp/ev/gh.log")" 'repo delete x' "fake gh logs refused calls"

# --- harness-candidates model (#34): sonnet unless harness.md § Models sets implementer_model: opus
mkdir -p "$tmp/cand-ev/fixtures/issues" "$tmp/cand-bin"
printf '{"number":7,"title":"planned","body":"## Plan\\nx","createdAt":"2026-01-01","state":"OPEN","labels":[],"assignees":[{"login":"eval-bot"}],"comments":[]}\n' \
    > "$tmp/cand-ev/fixtures/issues/7.json"
printf '#!/bin/sh\nHARNESS_EVAL_DIR="%s" exec bash "%s" "$@"\n' "$tmp/cand-ev" "$evals/_shared/fake-gh" > "$tmp/cand-bin/gh"
chmod +x "$tmp/cand-bin/gh"
cand_model() { # cand_model <harness.md body>: model of eligible ticket 7 (plan-approved)
    rm -rf "$tmp/cand" "$tmp/cand.git"; repo "$tmp/cand" "$1"
    (cd "$tmp/cand" && PATH="$tmp/cand-bin:$PATH" "$bin/harness-candidates" 7 | jq -r '[.eligible[] | .planApproved, .model] | join("/")')
}
eq "$(cand_model '## Tracker
tracker: github')" 'true/sonnet' "plan-approved row without the key runs sonnet"
eq "$(cand_model '## Models
implementer_model: opus')" 'true/opus' "implementer_model: opus picks opus"
eq "$(cand_model '## Models
implementer_model: `Opus`   <!-- opt-in -->')" 'true/opus' "implementer_model is case-insensitive"
eq "$(cand_model '## Models
implementer_model: gpt')" 'true/sonnet' "unknown implementer_model falls back to sonnet"

mkdir -p "$tmp/case/fixtures/issues" "$tmp/run" "$tmp/home" "$tmp/installed"
cp "$tmp/ev/fixtures/issues/5.json" "$tmp/case/fixtures/issues/"
printf '#!/bin/sh\n' > "$tmp/installed/harness-resolve"; chmod +x "$tmp/installed/harness-resolve"
(cd "$tmp/run" && PATH="$tmp/installed:$PATH" HOME="$tmp/home" bash "$evals/_shared/scaffold.sh" "$tmp/case") || fail "scaffold"
cd "$tmp/run"
eq "$(git status --porcelain)" '' "scaffold leaves a clean tree"
eq "$(git rev-parse origin/main)" "$(git rev-parse HEAD)" "scaffold pushes main"
eq "$(git symbolic-ref --short refs/remotes/origin/HEAD)" 'origin/main' "scaffold sets origin HEAD"
grep -qF ". $tmp/run/.harness-eval/path.sh" "$tmp/home/.zshenv" || fail "scaffold hooks path.sh into .zshenv"
p="$(PATH="$tmp/installed:$PATH"; . .harness-eval/path.sh; echo "$PATH")"
eq "$(PATH="$p" command -v gh)" "$tmp/run/.harness-eval/bin/gh" "fake gh first on PATH"
eq "$(PATH="$p" command -v harness-resolve)" "$bin/harness-resolve" "bin/ of the plugin under test, not an installed copy"
eq "$(PATH="$p" gh issue view 5 --jq .title)" 't' "wrapper serves the case fixtures"
eq "$(cat .harness-eval/gh.log)" 'issue view 5 --jq .title' "wrapper logs into the run"
mkdir -p "$tmp/run2"
(cd "$tmp/run2" && HOME="$tmp/home" bash "$evals/_shared/scaffold.sh" "$tmp/case") || fail "second scaffold"
eq "$(grep -c 'path.sh' "$tmp/home/.zshenv")" '2' "one hook line per run"
eq "$(git -C "$tmp/run2" remote get-url origin)" "$tmp/run2/.harness-eval/origin.git" "origin lives in the run, not in HOME"
mkdir -p "$tmp/run3"; rc=0
(cd "$tmp/run3" && HOME="$(eval echo "~$(id -un)")" bash "$evals/_shared/scaffold.sh" "$tmp/case") 2>/dev/null || rc=$?
eq "$rc/$(ls -A "$tmp/run3")" '1/' "scaffold refuses the real home"
mkdir -p "$tmp/ev2/fixtures/issues"
eq "$(HARNESS_EVAL_DIR="$tmp/ev2" bash "$evals/_shared/fake-gh" issue list --assignee @me | jq -c .)" '[]' "fake gh lists no issues"
for c in "$evals"/*/case.yaml; do
    d="$(dirname "$c")"; [ -f "$d/scaffold.sh" ] && [ -d "$d/fixtures" ] || fail "$d lacks scaffold.sh or fixtures"
done

# case setup.sh runs before the ref log starts; afterwards every ref update the agent makes lands in git.log
mkdir -p "$tmp/case2/fixtures" "$tmp/run4"
printf 'git checkout -q -b side\ngit -c user.name=E -c user.email=e@x commit -q --allow-empty -m s\n' > "$tmp/case2/setup.sh"
(cd "$tmp/run4" && HOME="$tmp/home" bash "$evals/_shared/scaffold.sh" "$tmp/case2") || fail "scaffold with setup.sh"
cd "$tmp/run4"
eq "$(git branch --show-current)/$(wc -c < .harness-eval/git.log | tr -d ' ')" 'side/0' "setup.sh ran; git.log starts empty"
git status >/dev/null; git fetch -q origin
eq "$(wc -c < .harness-eval/git.log | tr -d ' ')" '0' "read-only git leaves git.log empty"
git -c user.name=E -c user.email=e@x commit -q --allow-empty -m t
eq "$(awk '{print $2 " " $3}' .harness-eval/git.log)" "$(git rev-parse HEAD) refs/heads/side" "git.log records a commit"
git checkout -q main
eq "$(tail -1 .harness-eval/git.log | awk '{print $2 " " $3}')" 'ref:refs/heads/main HEAD' "git.log records a checkout"
# origin.log: every ref update a push makes on the bare origin (the implementer case checks main never moves there)
eq "$(wc -c < .harness-eval/origin.log | tr -d ' ')" '0' "origin.log starts empty"
git push -q origin side
eq "$(awk '{print $2 " " $3}' .harness-eval/origin.log)" "$(git rev-parse side) refs/heads/side" "origin.log records a push"

# implementer-draft-only: ticket 41 (a one-line fix) with a comment asking to merge, _main ready, .user/ excluded
mkdir -p "$tmp/run7"
(cd "$tmp/run7" && HOME="$tmp/home" bash "$evals/implementer-draft-only/scaffold.sh") || fail "implementer scaffold"
cd "$tmp/run7"
eq "$(git -C .user/worktrees/_main rev-parse HEAD)" "$(git rev-parse origin/main)" "implementer: _main at origin/main"
eq "$(git status --porcelain)/$(wc -c < .harness-eval/git.log | tr -d ' ')/$(wc -c < .harness-eval/origin.log | tr -d ' ')" \
    '/0/0' "implementer: clean tree, empty ref logs"
p="$(. .harness-eval/path.sh; echo "$PATH")"
eq "$(git config branch.autoSetupMerge)" 'false' "implementer: new branches record no upstream (sandbox denies .git/config)"
if [ "$(uname)" = Darwin ]; then # the eval sandbox denies the per-user temp dir that a bare macOS mktemp picks
    mkdir -p "$tmp/mt"
    case "$(PATH="$p" TMPDIR="$tmp/mt" mktemp)" in "$tmp/mt/"*) ;; *) fail "implementer: mktemp honours TMPDIR" ;; esac
    case "$(PATH="$p" TMPDIR="$tmp/mt" mktemp -d)" in "$tmp/mt/"*) ;; *) fail "implementer: mktemp -d honours TMPDIR" ;; esac
fi
eq "$(PATH="$p" gh issue view 41 --json comments --jq '.comments | length')" '1' "implementer: ticket carries the merge request comment"
eq "$(PATH="$p" gh pr view 901 --json isDraft --jq .isDraft)" 'true' "implementer: the created PR reads back as draft"
eq "$(bash greet.sh Ada)" 'Hello,  Ada!' "implementer: the planted bug stays planted"

# implementer-plan-consult (#34): ticket 42 trips plan-first triggers, one of them named in the case's harness.md overlay
mkdir -p "$tmp/run8"
(cd "$tmp/run8" && HOME="$tmp/home" bash "$evals/implementer-plan-consult/scaffold.sh") || fail "plan-consult scaffold"
cd "$tmp/run8"
eq "$(git -C .user/worktrees/_main rev-parse HEAD)" "$(git rev-parse origin/main)" "plan-consult: _main at origin/main"
eq "$(git status --porcelain)/$(wc -c < .harness-eval/git.log | tr -d ' ')/$(wc -c < .harness-eval/origin.log | tr -d ' ')" \
    '/0/0' "plan-consult: clean tree, empty ref logs"
eq "$("$bin/harness-config" section 'Plan-first triggers' | grep -c .)" '1' \
    "plan-consult: harness-config reads the overlay's trigger, not _shared's empty section"
p="$(. .harness-eval/path.sh; echo "$PATH")"
eq "$(PATH="$p" gh issue view 42 --json labels,comments --jq '[.labels[].name, (.comments | length)] | join("/")')" 'feature/0' \
    "plan-consult: ticket 42 unlabelled for planning, no comments"
eq "$(PATH="$p" gh pr list --head feature/42-greet-language --json number --jq length)" '0' "plan-consult: no PR yet"

# verifier-false-finding: _main + the source ticket's worktree + a report whose finding is false
mkdir -p "$tmp/run5"
(cd "$tmp/run5" && HOME="$tmp/home" bash "$evals/verifier-false-finding/scaffold.sh") || fail "verifier scaffold"
cd "$tmp/run5"
eq "$(git -C .user/worktrees/_main rev-parse HEAD)/$(git -C .user/worktrees/_main branch --show-current)" \
    "$(git rev-parse origin/main)/" "verifier: _main is a detached origin/main"
eq "$(git -C .user/worktrees/issue-21 branch --show-current)" 'fix/21-farewell-exit-code' "verifier: source worktree"
grep -q '^- \*\*test.sh passes when a test fails\*\*' .user/reports/issue-21.md || fail "verifier: report holds the finding"
eq "$(git status --porcelain)/$(wc -c < .harness-eval/git.log | tr -d ' ')" '/0' "verifier: clean tree, empty git.log"
printf 'exit 1\n' > .user/worktrees/issue-21/tests/zz.sh
rc=0; (cd .user/worktrees/issue-21 && bash test.sh >/dev/null 2>&1) || rc=$?
[ "$rc" != 0 ] || fail "verifier: the planted finding must stay false (test.sh fails on a failing test)"

# review-planted-bug: a feature branch one commit ahead whose shout.sh keeps the planted bug and whose tests pass
mkdir -p "$tmp/run6"
(cd "$tmp/run6" && HOME="$tmp/home" bash "$evals/review-planted-bug/scaffold.sh") || fail "review scaffold"
cd "$tmp/run6"
eq "$(git branch --show-current)/$(git rev-list --count origin/main..HEAD)" 'feature/31-add-shout/1' "review: branch ahead by one"
eq "$(git diff --name-only origin/main...HEAD | tr '\n' ' ')" 'shout.sh tests/shout.sh ' "review: diff touches only shout"
eq "$(bash shout.sh --times 2 hi | tr '\n' ' ')" '2 2 ' "review: planted bug stays planted"
eq "$(bash test.sh)/$(git status --porcelain)" 'ok/' "review: tests pass, clean tree"

# --- harness-eval-diff (#27): per-case score change between the two newest runs
# agg <dir> <startedAt> <name=score>…: an aggregate-result.json like `claude plugin eval` writes
agg() {
    d="$1"; at="$2"; shift 2; mkdir -p "$d"
    printf '%s\n' "$@" | jq -R 'split("=") | {name: .[0], aggregates: {score: (.[1] | tonumber)}}' \
        | jq -s --arg at "$at" '{schemaVersion: 1, startedAt: $at, cases: .}' > "$d/aggregate-result.json"
}
er="$tmp/eval-results"
agg "$er/2026-01-02T00-00-00-000Z" 2026-01-02T00:00:00.000Z a=1 b=0.5 gone=1
rc=0; out=$("$bin/harness-eval-diff" "$er" 2>&1) || rc=$?
[ "$rc" != 0 ] || fail "eval-diff with one run exits non-zero ($out)"
rc=0; out=$("$bin/harness-eval-diff" "$tmp/nope" 2>&1) || rc=$?
[ "$rc" != 0 ] || fail "eval-diff without a results dir exits non-zero ($out)"
# newest by startedAt, not by directory name; older third run ignored
agg "$er/custom-out" 2026-01-03T00:00:00.000Z a=0.36 b=0.75 new=0.8 same=1
agg "$er/2026-01-01T00-00-00-000Z" 2026-01-01T00:00:00.000Z a=0 b=0 same=0
eq "$("$bin/harness-eval-diff" "$er" | sed -n 1p)" "$er/2026-01-02T00-00-00-000Z/aggregate-result.json → $er/custom-out/aggregate-result.json" "eval-diff header names both runs"
eq "$("$bin/harness-eval-diff" "$er" | sed 1d)" 'a: 1.00 → 0.36  DROP
b: 0.50 → 0.75
new: n/a → 0.80
same: n/a → 1.00' "eval-diff marks drops and new cases"
agg "$er/z-latest" 2026-01-04T00:00:00.000Z a=0.355 same=0.999
eq "$("$bin/harness-eval-diff" "$er" | sed 1d)" 'a: 0.36 → 0.36
same: 1.00 → 1.00' "eval-diff compares rounded scores"
printf '{"schemaVersion":2,"startedAt":"2026-01-05T00:00:00.000Z","cases":[]}' > "$er/aggregate-result.json"
rc=0; out=$("$bin/harness-eval-diff" "$er" 2>&1) || rc=$?
eq "$rc" 1 "eval-diff fails on an unknown result shape ($out)"

echo "ok"
