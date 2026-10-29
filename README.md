# dotfiles

My super awesome · files

> [!IMPORTANT]
> I don't recommend you use this repo. This is a pretty messy setup that serves a very specific purpose.

## Install

```bash
./install
```

Every step runs even if an earlier one fails. Failed steps are listed at the end
and the script exits with status 1. Files that would be overwritten with
different content are first backed up as `<file>.backup.<timestamp>`.

### `.zshrc`

The repo's [`.zshrc`](.zshrc) holds defaults (Oh My Zsh, powerlevel10k, aliases).
The installer copies it to `~/.zshrc.dotfiles` and adds one line at the top of
`~/.zshrc` that loads it. Your existing `~/.zshrc` content stays below that line,
so on any conflict (same alias, variable, etc.) your setting wins.

If your `~/.zshrc` already loads Oh My Zsh, the defaults skip Oh My Zsh and
powerlevel10k, so your own plugins and theme are used. Oh My Zsh then replaces
the repo's `l` and `ll` aliases with its own.

### Agent instructions

[`AGENTS.md`](AGENTS.md) is copied to the user-level instruction file of each
agent, so it applies to every session:

- Copilot CLI: `~/.copilot/copilot-instructions.md`
- Codex: `~/.codex/AGENTS.md`
- Claude Code: `~/.claude/CLAUDE.md`
