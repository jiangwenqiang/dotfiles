# edit-command-line
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line

# ZOXIDE 
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

# Starship
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
