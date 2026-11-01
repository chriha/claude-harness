#!/usr/bin/env bash
# scaffold.sh <case dir> — builds a harness eval run in the current directory (the run cwd `claude plugin eval --scaffold`
# gives the case's scaffold.sh): a git repo from _shared/repo plus <case>/repo, pushed to a bare origin in .harness-eval/;
# .harness-eval/ (git-excluded) with the case's fixtures, the fake gh, gh.log and bodies/; and a PATH that puts the fake gh
# first. Fails if any other gh or harness-resolve would win on that PATH. Both ablation arms get that PATH (bin/ and the
# briefs it resolves), so a no-plugin arm says nothing: run the suite with --ablation none.
# <case>/setup.sh, when present, then runs in the run dir (extra branches, worktrees, reports). After it, every ref update
# in the repo (commit, checkout, branch, remote-tracking) is appended to .harness-eval/git.log as "<old> <new> <ref>".
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
# macOS: /usr/bin/git is an xcrun shim that fails inside the eval sandbox; call the real binary instead.
if [ "$(command -v git)" = /usr/bin/git ] && [ "$(uname)" = Darwin ]; then
    for g in "$(xcode-select -p 2>/dev/null)/usr/bin/git" /Library/Developer/CommandLineTools/usr/bin/git; do
        if [ -x "$g" ]; then printf '#!/bin/sh\nexec %q "$@"\n' "$g" > "$ev/bin/git"; chmod +x "$ev/bin/git"; break; fi
    done
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
printf '#!/bin/sh\n[ "$1" = committed ] || exit 0\nawk '\''$1 != $2'\'' >> %q\n' "$ev/git.log" > "$ev/hooks/reference-transaction"
chmod +x "$ev/hooks/reference-transaction"
git config core.hooksPath "$ev/hooks"
: > "$ev/git.log"
