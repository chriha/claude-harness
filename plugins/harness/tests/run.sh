#!/usr/bin/env bash
# Self-check for bin/ scripts: bash plugins/harness/tests/run.sh (needs git, go). Exits non-zero on the first failure.
set -euo pipefail
bin="$(cd "$(dirname "$0")/../bin" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t GIT_CONFIG_GLOBAL=/dev/null
fail() { echo "FAIL: $*"; exit 1; }
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

echo "ok"
