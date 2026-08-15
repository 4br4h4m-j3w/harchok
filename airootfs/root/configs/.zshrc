# Created by newuser for 5.9.2

# Aliases
alias ls='lsd'

# Starship
eval "$(starship init zsh)"

# Atuin
eval "$(atuin init zsh)"

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select

source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
