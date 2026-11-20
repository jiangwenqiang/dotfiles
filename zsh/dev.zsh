# THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"  # This loads nvm
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

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

# Homebrew 安装的 rustup
if command -v brew >/dev/null 2>&1; then
    if brew list rustup &>/dev/null; then
        export PATH="$(brew --prefix rustup)/bin:$PATH"
    fi
fi

# Rust 工具链
if [[ -d "$HOME/.cargo/bin" ]]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi
