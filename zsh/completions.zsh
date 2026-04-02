# Setup completion for worktree
autoload -U compinit && compinit -i

_worktree() {
    local -a repos branches
    local config_file=".workspace.config"
    local source_root repo_name

    # Get WORKTREE_ROOT_PATH from config file
    if [[ -f "$config_file" ]]; then
        source_root=$(grep -E '^WORKTREE_ROOT_PATH\s*=' "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/^["'"'"']//;s/["'"'"']$//')
    fi

    case $CURRENT in
        2) # First argument: repo names
            if [[ -n "$source_root" && -d "$source_root" ]]; then
                repos=("$source_root"/*(/N:t))
                _describe 'repository' repos
            else
                _message 'repo_name'
            fi
            ;;
        3) # Second argument: branch names
            repo_name="$words[2]"
            if [[ -n "$source_root" && -d "$source_root/$repo_name/.git" ]]; then
                branches=("${(@f)$(git -C "$source_root/$repo_name" branch 2>/dev/null | sed 's/^[* ] //')}")
                _describe 'branch' branches
            else
                _message 'branch_name'
            fi
            ;;
    esac
}

# Register completion
compdef _worktree worktree
