# dotfiles

My super awesome · files

> [!IMPORTANT]
> I don't recommend you use this repo. This is a pretty messy setup that serves a very specific purpose.

## Shared agent instructions

[AGENTS.md](AGENTS.md) is the shared source for communication preferences. The
bootstrap (`./install`) installs it automatically. To install or refresh only
agent instructions, without installing software or changing shell settings, run:

```bash
bash ./install_agent_instructions
```

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

Run the focused installer checks with `bash tests/test_agent_instructions.sh`.
