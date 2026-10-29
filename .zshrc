# Enable Powerlevel10k instant prompt before interactive setup.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
plugins=(
  git
  z
  zsh-autosuggestions
)

[[ ! -f "$ZSH/oh-my-zsh.sh" ]] || source "$ZSH/oh-my-zsh.sh"
