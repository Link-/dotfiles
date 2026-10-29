# dotfiles

My super awesome · files

> [!IMPORTANT]
> I don't recommend you use this repo. This is a pretty messy setup that serves a very specific purpose.

## Installation

Run the existing installer from this checkout:

```bash
./install
```

You can also invoke its absolute path from another working directory.

Each step reports errors and stops its own dependent work, while independent steps
continue. The installer exits nonzero if any step failed or was skipped because a
prerequisite failed. Existing Git-based tools are kept rather than cloned again.

The `.zshrc` merge keeps existing content in its original order, then adds a marked
block of missing defaults. Destination settings win for common variable
assignments (one declaration per line, including `export`, `typeset`, and multiline
arrays), aliases, and equivalent `source`/`.` commands with common quoting and
home-path forms. Tied variables (`path`/`PATH` and `fpath`/`FPATH`) share keys.
This is a text merge, not a shell interpreter: recognized declarations reserve
their keys even inside conditions or functions. Computed paths and side effects of imported
scripts still need manual review. New defaults run after existing code.

The installer does not execute `.zshrc`; it checks the merged file with `zsh -n`
before writing it. A changed existing file is backed up as
`~/.zshrc.backup.<unique suffix>`, keeping earlier backups. Existing symlinks and
file permissions are preserved. Put personal changes outside the managed block so
repeat installations keep them. Completions use `~/.zsh/completions`, not Bash's
unavailable zsh `fpath` array.

## Shared agent instructions

[AGENTS.md](AGENTS.md) remains the shared source for communication preferences,
installed directly by `./install`.

The installer copies the source into a marked section of each tool's documented
user-level instruction file. It keeps existing instructions outside that section,
preserves existing symlinks, and replaces the section on repeat runs. The section
comes first so Codex's instruction size limit does not cut it off behind a large
existing file. Edit `AGENTS.md`, then rerun the installer to update installed copies.

| Tool | Default user-level file | Configuration directory override |
| --- | --- | --- |
| [Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions) | `~/.copilot/copilot-instructions.md` | `COPILOT_HOME` |
| [Codex](https://developers.openai.com/codex/guides/agents-md/) | `~/.codex/AGENTS.md` | `CODEX_HOME` |
| [Claude Code](https://code.claude.com/docs/en/memory) | `~/.claude/CLAUDE.md` | [`CLAUDE_CONFIG_DIR`](https://code.claude.com/docs/en/env-vars.md) |

These files apply across repositories for that user and configuration directory.
Use absolute paths for directory overrides, with the same values when installing
and launching the tools. Codex reads a nonblank `AGENTS.override.md` instead of
`AGENTS.md`, so the installer also updates an existing nonblank global override.
Rerun after creating a new override or changing configuration directories.

Start a new session after installing. Explicitly disabled instruction files,
tool-specific limits, conflicting project instructions, or managed policies can
affect what is loaded or followed. This configures the named local tools, not
Copilot's IDE/cloud surfaces or remote environments; install separately on each
machine. Other agents can use the repository's standard `AGENTS.md` where they
support it, but there is no universal user-level instruction path.

Run the isolated installer checks with `bash tests/test_install.sh`. They use
temporary home directories and mocked external commands, without installing
software or changing live configuration.
