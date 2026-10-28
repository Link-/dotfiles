#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-agents-test.XXXXXX")"
trap 'rm -r -- "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/source"
cp "$REPO_DIR/AGENTS.md" "$REPO_DIR/install_agent_instructions" "$TEST_ROOT/source/"
SOURCE_FILE="$TEST_ROOT/source/AGENTS.md"
INSTALLER="$TEST_ROOT/source/install_agent_instructions"
START_MARKER="<!-- dotfiles:agent-instructions:start -->"
END_MARKER="<!-- dotfiles:agent-instructions:end -->"

fail() {
	printf 'FAIL: %s\n' "$*" >&2
	exit 1
}

run_install() {
	local home="$1"
	shift
	HOME="$home" COPILOT_HOME="" CODEX_HOME="" CLAUDE_CONFIG_DIR="" \
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

# Stop the bootstrap immediately after its real instruction installation hook.
cat > "$TEST_ROOT/bootstrap-stubs" <<'EOF'
brew() { exit 91; }
zsh() { exit 91; }
bash() {
	[[ "$#" -eq 1 && "$1" == "$EXPECTED_INSTALLER" ]] || exit 92
	BASH_ENV="" command bash "$@"
	exit "$?"
}
EOF
home="$TEST_ROOT/bootstrap-home"
HOME="$home" COPILOT_HOME="" CODEX_HOME="" CLAUDE_CONFIG_DIR="" \
	BASH_ENV="$TEST_ROOT/bootstrap-stubs" EXPECTED_INSTALLER="$REPO_DIR/install_agent_instructions" \
	/bin/bash "$REPO_DIR/install" > "$TEST_ROOT/bootstrap.log" 2>&1
check_defaults "$home"
printf 'PASS: bootstrap invokes the real instruction installer before software installation\n'
