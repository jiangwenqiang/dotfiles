# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME="$HOME/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# use the latest python installed by uv as the global version
if command -v uv &> /dev/null; then
    LATEST_DIR=$(ls "$HOME/.local/share/uv/python" 2>/dev/null | grep "^cpython-[0-9]" | sort -V | tail -1)
    [ -n "$LATEST_DIR" ] && export PATH="$HOME/.local/share/uv/python/$LATEST_DIR/bin:$PATH"
fi
