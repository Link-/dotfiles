# Defaults from the dotfiles repo.
#
# The installer copies this file to ~/.zshrc.dotfiles and loads it from the
# first line of ~/.zshrc. zsh runs top to bottom, so anything further down in
# ~/.zshrc overrides these defaults.

# Powerlevel10k instant prompt. Must stay near the top.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin"
fpath=("$HOME/.zsh/completions" $fpath)

# Oh My Zsh (also sets up completions with compinit).
export ZSH="$HOME/.oh-my-zsh"
plugins=(
  git
  z
  zsh-autosuggestions
)
[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Load after Oh My Zsh so the theme and aliases below are not replaced.
[[ -f ~/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

alias dotfiles='cd /workspaces/.codespaces/.persistedshare/dotfiles'
alias k='kubectl'
alias ll='eza -la -g'
alias l='eza -la -g'
