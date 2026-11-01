#!/usr/bin/env bash
# scaffold.sh <case dir> — builds a harness eval run in the current directory (the run cwd `claude plugin eval --scaffold`
# gives the case's scaffold.sh): a git repo from _shared/repo plus <case>/repo, pushed to a bare origin in .harness-eval/;
# .harness-eval/ (git-excluded) with the case's fixtures, the fake gh, gh.log and bodies/; and a PATH that puts the fake gh
# first. Fails if any other gh or harness-resolve would win on that PATH. Both ablation arms get that PATH (bin/ and the
# briefs it resolves), so a no-plugin arm says nothing: run the suite with --ablation none.
# <case>/setup.sh, when present, then runs in the run dir (extra branches, worktrees, reports). After it, every ref update
# in the repo (commit, checkout, branch, remote-tracking) is appended to .harness-eval/git.log as "<old> <new> <ref>", and
# every ref update on the bare origin (a push) to .harness-eval/origin.log.
set -euo pipefail
case_dir="$(cd "${1:?usage: scaffold.sh <case dir>}" && pwd)"
shared="$(cd "$(dirname "$0")" && pwd)"
run="$(pwd)"
# It writes to $HOME (.zshenv, .bashrc): only in a throwaway home, never the account's real one.
if [ "$HOME" = "$(eval echo "~$(id -un)")" ]; then echo "scaffold: \$HOME is your real home; run it via claude plugin eval" >&2; exit 1; fi

cp -R "$shared/repo/." "$run/"
if [ -d "$case_dir/repo" ]; then cp -R "$case_dir/repo/." "$run/"; fi
git init -q -b main
git add -A
git -c user.name="Eval" -c user.email="eval@example.invalid" commit -qm "initial commit"
git init -q --bare "$run/.harness-eval/origin.git"
git remote add origin "$run/.harness-eval/origin.git"
git push -q origin main
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
# The eval sandbox denies writes to .git/config, so `git worktree add -b <b> <wt> origin/<base>` (harness-worktree) would
# fail when it records the upstream; new branches record none.
git config branch.autoSetupMerge false

ev="$run/.harness-eval"
mkdir -p "$ev/bin" "$ev/bodies"
cp -R "$case_dir/fixtures" "$ev/fixtures"
cp "$shared/fake-gh" "$ev/fake-gh"
: > "$ev/gh.log"
printf '#!/usr/bin/env bash\nexport HARNESS_EVAL_DIR=%q\nexec bash %q "$@"\n' "$ev" "$ev/fake-gh" > "$ev/bin/gh"
chmod +x "$ev/bin/gh"

# PATH for the agent's shell: the fake gh, then the plugin under test's bin/ (ahead of any installed harness copy). The
# eval's Bash tool ignores settings env but sources $HOME/.zshenv (zsh) / .bashrc (bash), so path.sh is hooked in there.
plugin_bin="$(cd "$shared/../../bin" && pwd)"
# macOS: /usr/bin/git (and git-upload-pack / git-receive-pack, which local fetches and pushes run) are xcrun shims that
# fail inside the eval sandbox; call the real binaries instead.
if [ "$(command -v git)" = /usr/bin/git ] && [ "$(uname)" = Darwin ]; then
    for g in "$(xcode-select -p 2>/dev/null)/usr/bin/git" /Library/Developer/CommandLineTools/usr/bin/git; do
        if [ -x "$g" ]; then
            for n in git git-upload-pack git-receive-pack; do
                if [ -x "$(dirname "$g")/$n" ]; then printf '#!/bin/sh\nexec %q "$@"\n' "$(dirname "$g")/$n" > "$ev/bin/$n"; chmod +x "$ev/bin/$n"; fi
            done
            break
        fi
    done
fi
# macOS: a bare `mktemp` / `mktemp -d` ignores TMPDIR and uses the per-user temp dir, which the sandbox denies (scripts like
# harness-red-check then fail); give them a template under TMPDIR.
if [ "$(uname)" = Darwin ]; then
    printf '#!/bin/sh\ncase "$*" in "" | -d) exec /usr/bin/mktemp "$@" "${TMPDIR:-/tmp}/tmp.XXXXXXXXXX" ;; esac\nexec /usr/bin/mktemp "$@"\n' \
        > "$ev/bin/mktemp"
    chmod +x "$ev/bin/mktemp"
fi
prefix="$ev/bin:$plugin_bin"
printf 'export PATH=%q:"$PATH"\n' "$prefix" > "$ev/path.sh"
hook="$(printf '. %q' "$ev/path.sh")"
for rc in .zshenv .bashrc; do grep -qxF "$hook" "$HOME/$rc" 2>/dev/null || printf '%s\n' "$hook" >> "$HOME/$rc"; done
if [ "$(PATH="$prefix:$PATH" command -v gh)" != "$ev/bin/gh" ]; then echo "scaffold: the fake gh is not first on PATH" >&2; exit 1; fi
if [ "$(PATH="$prefix:$PATH" command -v harness-resolve)" != "$plugin_bin/harness-resolve" ]; then
    echo "scaffold: harness-resolve does not come from the plugin under test" >&2; exit 1
fi
printf '.harness-eval/\n' >> .git/info/exclude

if [ -f "$case_dir/setup.sh" ]; then bash "$case_dir/setup.sh"; fi
# git.log: the repo's own hooks dir (a global core.hooksPath would hide it), set up after the case setup so it stays empty
# until the agent changes a ref (no-op deletions such as AUTO_MERGE are skipped).
mkdir -p "$ev/hooks"
printf '#!/usr/bin/env bash\n[ "$1" = committed ] || exit 0\nawk '\''$1 != $2'\'' >> %q\n' "$ev/git.log" > "$ev/hooks/reference-transaction"
chmod +x "$ev/hooks/reference-transaction"
git config core.hooksPath "$ev/hooks"
# canary: an empty git.log must mean "no ref changed", not "the hook never fires" (old git, hooks off)
git update-ref refs/harness-eval/canary HEAD
grep -q 'refs/harness-eval/canary$' "$ev/git.log" 2>/dev/null || { echo "scaffold: the git ref log hook does not fire" >&2; exit 1; }
git update-ref -d refs/harness-eval/canary
: > "$ev/git.log"
# origin.log: the same for the bare origin, so graders see what a push changed there (e.g. main must never move)
mkdir -p "$ev/origin-hooks"
printf '#!/usr/bin/env bash\n[ "$1" = committed ] || exit 0\nawk '\''$1 != $2'\'' >> %q\n' "$ev/origin.log" > "$ev/origin-hooks/reference-transaction"
chmod +x "$ev/origin-hooks/reference-transaction"
git -C "$ev/origin.git" config core.hooksPath "$ev/origin-hooks"
git -C "$ev/origin.git" update-ref refs/harness-eval/canary main
grep -q 'refs/harness-eval/canary$' "$ev/origin.log" 2>/dev/null || { echo "scaffold: the origin ref log hook does not fire" >&2; exit 1; }
git -C "$ev/origin.git" update-ref -d refs/harness-eval/canary
: > "$ev/origin.log"
