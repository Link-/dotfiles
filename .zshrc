# Defaults from the dotfiles repo.
#
# The installer copies this file to ~/.zshrc.dotfiles and loads it from the
# first line of ~/.zshrc. zsh runs top to bottom, so anything further down in
# ~/.zshrc overrides these defaults.

export PATH="$PATH:/home/linuxbrew/.linuxbrew/bin:$HOME/.local/bin"
fpath=("$HOME/.zsh/completions" $fpath)

# Oh My Zsh and powerlevel10k, unless ~/.zshrc loads Oh My Zsh itself. In
# that case its own plugins and theme are used instead.
if ! grep -qE '^[[:space:]]*[^#[:space:]].*oh-my-zsh\.sh' ~/.zshrc 2>/dev/null; then
  # Powerlevel10k instant prompt. Must come before anything that prints.
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi

  export ZSH="$HOME/.oh-my-zsh"
  plugins=(
    git
    z
    zsh-autosuggestions
  )
  [[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

  [[ -f ~/powerlevel10k/powerlevel10k.zsh-theme ]] && source ~/powerlevel10k/powerlevel10k.zsh-theme
  [[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
fi

[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# When ~/.zshrc loads Oh My Zsh after this file, its own l and ll aliases
# replace these two.
alias dotfiles='cd /workspaces/.codespaces/.persistedshare/dotfiles'
alias k='kubectl'
alias ll='eza -la -g'
alias l='eza -la -g'
