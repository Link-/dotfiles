#!/usr/bin/env bash
# Shell snippets and matching patterns intentionally keep variables literal.
# shellcheck disable=SC2016

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-install-test.XXXXXX")"
trap 'rm -r -- "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/source/tools" "$TEST_ROOT/tmp" "$TEST_ROOT/brew/opt/fzf"
cp "$REPO_DIR/AGENTS.md" "$REPO_DIR/install" "$REPO_DIR/.zshrc" \
	"$REPO_DIR/.vimrc" "$REPO_DIR/.tmux.conf" "$REPO_DIR/.gitconfig" \
	"$REPO_DIR/.p10k.zsh" "$REPO_DIR/start_ssh_agent.sh" "$TEST_ROOT/source/"
cp "$REPO_DIR/tools/date" "$REPO_DIR/tools/lnav" "$TEST_ROOT/source/tools/"
SOURCE_FILE="$TEST_ROOT/source/AGENTS.md"
INSTALLER="$TEST_ROOT/source/install"
START_MARKER="<!-- dotfiles:agent-instructions:start -->"
END_MARKER="<!-- dotfiles:agent-instructions:end -->"

cat > "$TEST_ROOT/mocks" <<'EOF'
mock_log() { printf '%s\n' "$*" >> "$TEST_LOG"; }
mock_fails() {
	case " ${TEST_FAILURES:-} " in *" $1 "*) return 0 ;; esac
	return 1
}
brew() {
	mock_log "brew $*"
	case "$1" in
		--version) if mock_fails homebrew; then return 20; fi ;;
		--prefix) printf '%s\n' "$TEST_ROOT/brew" ;;
		install) if mock_fails "brew:$2"; then return 21; fi ;;
		*) return 99 ;;
	esac
}
sudo() {
	mock_log "sudo $*"
	if mock_fails sudo; then return 22; fi
}
git() {
	mock_log "git $*"
	if [[ "$1" == -C ]]; then
		[[ "$2" == "$TEST_ROOT/"* && -d "$2/.git" ]]
		return
	fi
	[[ "$1" == clone ]] || return 99
	local destination
	for destination in "$@"; do :; done
	[[ "$destination" == "$TEST_ROOT/"* ]] || return 98
	if mock_fails "git:$(basename "$destination")"; then return 23; fi
	mkdir -p "$destination/.git"
}
curl() {
	mock_log "curl $*"
	if mock_fails curl; then return 24; fi
	local output=""
	while [[ "$#" -gt 0 ]]; do
		if [[ "$1" == -o ]]; then output="$2"; shift; fi
		shift
	done
	[[ "$output" == "$TEST_ROOT/"* ]] || return 98
	printf '# Mock downloaded content\n' > "$output"
}
kubectl() {
	mock_log "kubectl $*"
	if mock_fails kubectl; then printf 'Partial output\n'; return 25; fi
	printf '#compdef kubectl\n'
}
helm() {
	mock_log "helm $*"
	if mock_fails helm; then return 26; fi
	printf '#compdef helm\n'
}
zsh() {
	mock_log "zsh $*"
	[[ "$1" == -n && "$2" == "$TEST_ROOT/"* ]] || return 98
	"$REAL_ZSH" "$@"
}
EOF
cat > "$TEST_ROOT/brew/opt/fzf/install" <<'EOF'
#!/usr/bin/env bash
printf 'fzf %s\n' "$*" >> "$TEST_LOG"
[[ " ${TEST_FAILURES:-} " != *" fzf "* ]]
EOF
chmod +x "$TEST_ROOT/brew/opt/fzf/install"
REAL_ZSH="$(command -v zsh)"
TEST_LOG="$TEST_ROOT/commands.log"
export TEST_ROOT TEST_LOG REAL_ZSH

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

run_install() {
	local home="$1"
	shift
	mkdir -p "$home"
	: > "$TEST_LOG"
	HOME="$home" COPILOT_HOME="" CODEX_HOME="" CLAUDE_CONFIG_DIR="" \
		ZSH="" ZSH_CUSTOM="" TMPDIR="$TEST_ROOT/tmp" BASH_ENV="$TEST_ROOT/mocks" \
		env "$@" "$BASH" "$INSTALLER" > "$TEST_ROOT/install.log" 2>&1
}

write_block() {
	printf '%s\n' "$START_MARKER"
	cat "$SOURCE_FILE"
	printf '%s\n' "$END_MARKER"
}

check_defaults() {
	local home="$1" path
	write_block > "$TEST_ROOT/expected"
	for path in .copilot/copilot-instructions.md .codex/AGENTS.md .claude/CLAUDE.md; do
		cmp "$TEST_ROOT/expected" "$home/$path" || fail "Unexpected instructions: $path"
	done
}

expect_failure() {
	if run_install "$@"; then
		fail "Installation unexpectedly succeeded"
	fi
	grep -q 'ERROR:' "$TEST_ROOT/install.log" || fail "Missing error message"
}

cat > "$TEST_ROOT/requested" <<'EOF'
## Communication

1. Always use simple language that makes it easy to reason about the content. Always optimise for human understanding. Use jargon derived from the context supplied to you, do not invent jargon unless absolutely necessary. Retain the jargon used by the environment and prioritise that over any new word constructions you think are relevant.
2. Don't be unnecessarily verbose. Reduce the prose to the maximum needed to convey an idea. Optimise for brevity but not at the expense of clarity.
3. Don't assume readers are always subject matter experts. Explain new concepts that you're bringing into the context.
4. Optimise explaining the why.
5. Optimise for providing evidence for your reasoning, analysis and outputs.
EOF
cmp "$TEST_ROOT/requested" "$SOURCE_FILE" || fail "Communication wording changed"

cd "$TEST_ROOT"
home="$TEST_ROOT/fresh home"
run_install "$home"
check_defaults "$home"
[[ ! -e "$home/AGENTS.md" ]] || fail "Unexpected universal home instruction file"
run_install "$home"
check_defaults "$home"
printf 'PASS: exact contents, default destinations, spaces, and repeat installation\n'

printf '\nA changed shared instruction.\n' >> "$SOURCE_FILE"
run_install "$home"
check_defaults "$home"
cp "$TEST_ROOT/requested" "$SOURCE_FILE"
run_install "$home"
check_defaults "$home"
printf 'PASS: shared source changes replace installed sections without duplication\n'

home="$TEST_ROOT/existing"
for path in .copilot/copilot-instructions.md .codex/AGENTS.md .claude/CLAUDE.md; do
	mkdir -p "$(dirname "$home/$path")"
	{
		printf 'Existing instructions before.\n%s\nStale managed text.\n%s\n' "$START_MARKER" "$END_MARKER"
		printf 'Existing instructions after.\n'
	} > "$home/$path"
done
chmod 640 "$home/.copilot/copilot-instructions.md"
run_install "$home"
run_install "$home"
{
	write_block
	printf 'Existing instructions before.\nExisting instructions after.\n'
} > "$TEST_ROOT/expected"
for path in .copilot/copilot-instructions.md .codex/AGENTS.md .claude/CLAUDE.md; do
	cmp "$TEST_ROOT/expected" "$home/$path" || fail "Existing content changed: $path"
done
[[ "$(LC_ALL=C ls -l "$home/.copilot/copilot-instructions.md")" == -rw-r-----* ]] ||
	fail "Existing file permissions changed"
printf 'PASS: existing content around managed sections and file permissions are preserved\n'

home="$TEST_ROOT/symlink"
mkdir -p "$home/.claude"
printf 'Existing content without a final newline.' > "$TEST_ROOT/personal-instructions"
ln -s "$TEST_ROOT/personal-instructions" "$home/.claude/CLAUDE.md"
run_install "$home"
run_install "$home"
{
	write_block
	printf 'Existing content without a final newline.\n'
} > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$home/.claude/CLAUDE.md" || fail "Symlink content changed"
[[ -L "$home/.claude/CLAUDE.md" ]] || fail "Existing symlink was replaced"
printf 'PASS: existing symlinks and unmarked instructions are preserved\n'

home="$TEST_ROOT/custom home"
copilot="$TEST_ROOT/custom copilot"
codex="$TEST_ROOT/custom codex"
claude="$TEST_ROOT/custom claude"
mkdir -p "$codex"
printf 'Existing global Codex instructions.\n' > "$codex/AGENTS.md"
printf 'Existing Codex override.\n' > "$codex/AGENTS.override.md"
run_install "$home" "COPILOT_HOME=$copilot" "CODEX_HOME=$codex" "CLAUDE_CONFIG_DIR=$claude"
run_install "$home" "COPILOT_HOME=$copilot" "CODEX_HOME=$codex" "CLAUDE_CONFIG_DIR=$claude"
write_block > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$copilot/copilot-instructions.md"
cmp "$TEST_ROOT/expected" "$claude/CLAUDE.md"
{
	write_block
	printf 'Existing global Codex instructions.\n'
} > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$codex/AGENTS.md"
{
	write_block
	printf 'Existing Codex override.\n'
} > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$codex/AGENTS.override.md"
[[ ! -e "$home/.copilot" && ! -e "$home/.codex" && ! -e "$home/.claude" ]] ||
	fail "Custom installation wrote to default paths"
printf 'PASS: directory overrides and existing Codex global overrides\n'

home="$TEST_ROOT/large-existing-file"
mkdir -p "$home/.codex"
awk 'BEGIN { for (i = 0; i < 2000; i++) print "Existing user instructions." }' \
	> "$home/.codex/AGENTS.md"
cp "$home/.codex/AGENTS.md" "$TEST_ROOT/large-before"
run_install "$home"
{
	write_block
	cat "$TEST_ROOT/large-before"
} > "$TEST_ROOT/expected"
cmp "$TEST_ROOT/expected" "$home/.codex/AGENTS.md"
head -c 32768 "$home/.codex/AGENTS.md" > "$TEST_ROOT/codex-default-budget"
grep -q '^5. Optimise for providing evidence' "$TEST_ROOT/codex-default-budget" ||
	fail "Codex default size limit hid the shared instructions"
printf 'PASS: shared instructions precede large existing Codex files\n'

for content in '' '   '; do
	home="$TEST_ROOT/blank-override-${#content}"
	mkdir -p "$home/.codex"
	printf '%s' "$content" > "$home/.codex/AGENTS.override.md"
	cp "$home/.codex/AGENTS.override.md" "$TEST_ROOT/override-before"
	run_install "$home"
	check_defaults "$home"
	cmp "$TEST_ROOT/override-before" "$home/.codex/AGENTS.override.md"
done
printf 'PASS: empty and whitespace-only Codex overrides remain untouched\n'

for malformed in unclosed unmatched nested duplicate; do
	home="$TEST_ROOT/malformed-$malformed"
	mkdir -p "$home/.copilot"
	destination="$home/.copilot/copilot-instructions.md"
	case "$malformed" in
		unclosed) printf 'Keep this.\n%s\nUnclosed section.\n' "$START_MARKER" ;;
		unmatched) printf 'Keep this.\n%s\n' "$END_MARKER" ;;
		nested) printf '%s\n%s\n%s\n' "$START_MARKER" "$START_MARKER" "$END_MARKER" ;;
		duplicate) write_block; write_block ;;
	esac > "$destination"
	cp "$destination" "$TEST_ROOT/before"
	expect_failure "$home"
	cmp "$TEST_ROOT/before" "$destination" || fail "Malformed file was changed"
	[[ -f "$home/.codex/AGENTS.md" && -f "$home/.claude/CLAUDE.md" ]] ||
		fail "Failed agent step prevented the other agent integrations"
	[[ -z "$(find "$home" -name '.dotfiles-agent-instructions.*' -print)" ]] ||
		fail "Temporary file was not cleaned up"
done
printf 'PASS: malformed managed sections fail clearly without changing the destination\n'

home="$TEST_ROOT/invalid-directory"
mkdir -p "$home/.copilot/copilot-instructions.md"
expect_failure "$home"
[[ -d "$home/.copilot/copilot-instructions.md" ]] || fail "Directory was replaced"
home="$TEST_ROOT/broken-symlink"
mkdir -p "$home/.copilot"
ln -s "$TEST_ROOT/missing" "$home/.copilot/copilot-instructions.md"
expect_failure "$home"
[[ -L "$home/.copilot/copilot-instructions.md" && ! -e "$TEST_ROOT/missing" ]] ||
	fail "Broken symlink was changed"
printf 'PASS: invalid destinations fail clearly without being replaced\n'

home="$TEST_ROOT/source-symlink"
mkdir -p "$home/.copilot"
ln -s "$SOURCE_FILE" "$home/.copilot/copilot-instructions.md"
run_install "$home"
cmp "$TEST_ROOT/requested" "$SOURCE_FILE" || fail "Shared source was rewritten through a symlink"
printf 'PASS: links to the shared source do not rewrite that source\n'

home="$TEST_ROOT/successful-full-install"
run_install "$home"
grep -q 'Installation finished successfully' "$TEST_ROOT/install.log"
[[ -f "$home/.zshrc" && -f "$home/.p10k.zsh" && -d "$home/.oh-my-zsh/.git" ]] ||
	fail "Missing shell setup"
[[ -f "$home/.zsh/completions/_kubectl" && -f "$home/.zsh/completions/_helm" ]] ||
	fail "Missing completion files"
[[ -f "$home/.vim/autoload/pathogen.vim" && -d "$home/.tmux/plugins/tpm/.git" ]] ||
	fail "Missing Vim or tmux setup"
grep -q '^fzf --key-bindings --completion --no-update-rc$' "$TEST_LOG"
cp "$home/.zshrc" "$TEST_ROOT/merged-before"
run_install "$home"
cmp "$TEST_ROOT/merged-before" "$home/.zshrc" || fail "Repeat shell merge was not stable"
[[ -z "$(find "$home" -name '.zshrc.backup.*' -print)" ]] || fail "Unchanged file was backed up"
[[ -z "$(find "$TEST_ROOT/tmp" -mindepth 1 -print)" ]] || fail "Scratch directory not cleaned up"
for pattern in 'source "$ZSH/oh-my-zsh.sh"' 'source "$HOME/.p10k.zsh"' 'source "$HOME/.fzf.zsh"' 'alias ll='; do
	[[ "$(grep -F -c "$pattern" "$home/.zshrc")" == 1 ]] || fail "Duplicated startup command: $pattern"
done
printf 'PASS: complete successful installation, completion paths, and repeat-run stability\n'

home="$TEST_ROOT/multiple-failures"
mkdir -p "$home/.zsh/completions"
printf 'Keep existing completion\n' > "$home/.zsh/completions/_kubectl"
expect_failure "$home" "TEST_FAILURES=brew:fzf brew:helm sudo curl git:.oh-my-zsh kubectl"
for message in 'Installing fzf failed' 'Installing helm failed' 'Installing lnav failed' \
	'Vim pathogen failed' 'Oh My Zsh failed' 'kubectl completions failed' \
	'Configuring fzf skipped' 'Helm completions skipped' 'zsh autosuggestions skipped'; do
	grep -q "$message" "$TEST_ROOT/install.log" || fail "Missing failure output: $message"
done
grep -q 'brew install copilot-cli' "$TEST_LOG" || fail "Later packages were not attempted"
grep -q 'tmux-plugins/tpm' "$TEST_LOG" || fail "Independent later step was not attempted"
grep -q 'INFO: Merging .zshrc' "$TEST_ROOT/install.log" || fail "Shell merge was not attempted"
! grep -q '^fzf ' "$TEST_LOG" || fail "Failed fzf prerequisite was ignored"
! grep -q '^helm ' "$TEST_LOG" || fail "Failed Helm prerequisite was ignored"
! grep -q 'zsh-autosuggestions.git' "$TEST_LOG" || fail "Failed Oh My Zsh prerequisite was ignored"
! grep -q 'finished successfully' "$TEST_ROOT/install.log" || fail "Failures reported success"
grep -q '^Keep existing completion$' "$home/.zsh/completions/_kubectl" ||
	fail "Failed completion generation overwrote existing content"
check_defaults "$home"
printf 'PASS: multiple errors are explicit, dependent steps are skipped, later steps continue, and final status fails\n'

home="$TEST_ROOT/failed-homebrew"
expect_failure "$home" "TEST_FAILURES=homebrew"
grep -q 'ERROR: Homebrew failed' "$TEST_ROOT/install.log"
grep -q 'Homebrew packages and fzf configuration skipped' "$TEST_ROOT/install.log"
! grep -q '^brew install' "$TEST_LOG" || fail "Unavailable Homebrew was used to install packages"
! grep -q '^fzf ' "$TEST_LOG" || fail "Unavailable Homebrew prerequisite was ignored"
grep -q 'tmux-plugins/tpm' "$TEST_LOG" || fail "Homebrew failure blocked independent clones"
[[ -f "$home/.zshrc" && -f "$home/.zsh/completions/_kubectl" ]] ||
	fail "Homebrew failure blocked independent shell configuration"
check_defaults "$home"
printf 'PASS: failed Homebrew is flagged, its dependent steps are skipped, and independent setup continues\n'

home="$TEST_ROOT/destination-first"
mkdir -p "$home"
cat > "$home/.zshrc" <<'EOF'
# Custom code stays in this order.
typeset -x ZSH="$HOME/custom-omz"
export PATH="$HOME/custom-bin:$PATH"
typeset -a plugins=(
  docker
  git
)
alias k="kubectl --context custom"
alias ll="ls -al"
alias personal="echo personal"
if [[ -f "${ZSH}/oh-my-zsh.sh" ]]; then
  . "${ZSH}/oh-my-zsh.sh"
fi
. "${HOME}/.p10k.zsh";
touch "$HOME/do-not-execute"
EOF
cp "$home/.zshrc" "$TEST_ROOT/original-zshrc"
chmod 640 "$home/.zshrc"
run_install "$home"
[[ ! -e "$home/do-not-execute" ]] || fail "Installer executed the user configuration"
sed '/^# dotfiles:defaults:start$/,$d' "$home/.zshrc" > "$TEST_ROOT/preserved-zshrc"
cmp "$TEST_ROOT/original-zshrc" "$TEST_ROOT/preserved-zshrc" || fail "Destination order or content changed"
sed -n '/^# dotfiles:defaults:start$/,$p' "$home/.zshrc" > "$TEST_ROOT/new-defaults"
for pattern in 'export ZSH=' 'export PATH=' 'plugins=' 'alias k=' 'alias ll=' 'oh-my-zsh.sh' '.p10k.zsh'; do
	! grep -F "$pattern" "$TEST_ROOT/new-defaults" || fail "Conflicting default was added: $pattern"
done
grep -q "alias l='eza -la -g'" "$TEST_ROOT/new-defaults" || fail "Missing non-conflicting default alias"
backup="$(find "$home" -name '.zshrc.backup.*' -print)"
[[ -n "$backup" ]] || fail "Original configuration was not backed up"
cmp "$TEST_ROOT/original-zshrc" "$backup" || fail "Backup did not preserve the original"
[[ "$(LC_ALL=C ls -l "$home/.zshrc")" == -rw-r-----* ]] || fail "Shell file permissions changed"
cp "$home/.zshrc" "$TEST_ROOT/merged-before"
run_install "$home"
cmp "$TEST_ROOT/merged-before" "$home/.zshrc"
[[ "$(find "$home" -name '.zshrc.backup.*' -print | wc -l | tr -d ' ')" == 1 ]] ||
	fail "Repeat installation added unnecessary backups"
printf 'PASS: destination settings win across equivalent declarations and imports; order, aliases, permissions, and backup are preserved\n'

home="$TEST_ROOT/equivalent-path-array"
mkdir -p "$home"
cat > "$home/.zshrc" <<'EOF'
path=("$HOME/custom-bin" $path)
export FPATH="$HOME/custom-completions:$FPATH"
# source ~/.p10k.zsh
autoload -Uz compinit
compinit
if [[ -n "$CUSTOM_SHELL" ]]; then
  alias k="custom-kubectl"
fi
EOF
run_install "$home"
sed -n '/^# dotfiles:defaults:start$/,$p' "$home/.zshrc" > "$TEST_ROOT/new-defaults"
! grep -q '^export PATH=' "$TEST_ROOT/new-defaults" || fail "path array did not override PATH default"
! grep -q '^fpath=' "$TEST_ROOT/new-defaults" || fail "FPATH did not override the fpath default"
! grep -q '^alias k=' "$TEST_ROOT/new-defaults" || fail "Guarded destination alias was overridden"
[[ "$(grep -c '^compinit$' "$home/.zshrc")" == 1 ]] || fail "Existing compinit was duplicated"
grep -q 'source "$HOME/.p10k.zsh"' "$TEST_ROOT/new-defaults" || fail "Comment incorrectly suppressed a source command"
printf 'PASS: tied path variables, guarded declarations, existing initialization, and commented imports\n'

home="$TEST_ROOT/runtime-precedence"
mkdir -p "$home"
cat > "$home/.zshrc" <<'EOF'
typeset -x ZSH="$HOME/custom-omz"
path=("$HOME/custom-bin" $path)
plugins=(docker)
alias k="kubectl --context custom"
alias ll="ls -al"
EOF
run_install "$home"
printf ':\n' > "$home/.p10k.zsh"
HOME="$home" "$REAL_ZSH" -f -c '
	compinit() { :; }
	source "$HOME/.zshrc"
	[[ "$ZSH" == "$HOME/custom-omz" && "${plugins[*]}" == docker ]] || exit 1
	[[ "${aliases[k]}" == "kubectl --context custom" && "${aliases[ll]}" == "ls -al" ]] || exit 2
	[[ "${path[1]}" == "$HOME/custom-bin" && "${fpath[1]}" == "$HOME/.zsh/completions" ]] || exit 3
' || fail "Runtime settings did not retain destination precedence"
printf 'PASS: controlled zsh startup confirms destination variables, arrays, aliases, and PATH remain effective\n'

home="$TEST_ROOT/changed-user-default"
run_install "$home"
printf 'alias ll="my-list"\n' >> "$home/.zshrc"
run_install "$home"
[[ "$(grep -c '^alias ll=' "$home/.zshrc")" == 1 ]] || fail "New user override did not replace the managed default"
grep -q '^alias ll="my-list"$' "$home/.zshrc"
cp "$home/.zshrc" "$TEST_ROOT/merged-before"
run_install "$home"
cmp "$TEST_ROOT/merged-before" "$home/.zshrc"
printf 'PASS: later user overrides remove conflicting managed defaults on the next run\n'

home="$TEST_ROOT/invalid-zshrc"
mkdir -p "$home"
printf 'if broken\n' > "$home/.zshrc"
cp "$home/.zshrc" "$TEST_ROOT/original-zshrc"
expect_failure "$home"
cmp "$TEST_ROOT/original-zshrc" "$home/.zshrc"
printf 'PASS: invalid shell syntax is reported without replacing the existing file\n'

home="$TEST_ROOT/malformed-zshrc"
mkdir -p "$home"
printf '# dotfiles:defaults:start\nUnclosed\n' > "$home/.zshrc"
cp "$home/.zshrc" "$TEST_ROOT/original-zshrc"
expect_failure "$home"
cmp "$TEST_ROOT/original-zshrc" "$home/.zshrc"
printf 'PASS: malformed shell markers fail without replacing the existing file\n'

home="$TEST_ROOT/symlink-zshrc"
mkdir -p "$home"
printf 'export EDITOR=vim\n' > "$TEST_ROOT/shell-target"
ln -s "$TEST_ROOT/shell-target" "$home/.zshrc"
run_install "$home"
[[ -L "$home/.zshrc" ]] || fail "Shell configuration symlink was replaced"
grep -q '^export EDITOR=vim$' "$TEST_ROOT/shell-target"
printf 'PASS: shell configuration symlinks are preserved\n'
