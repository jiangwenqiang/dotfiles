# Backup proxy
function backup_proxy() {
    export _OLD_HTTP_PROXY="$http_proxy"
    export _OLD_HTTPS_PROXY="$https_proxy"
    export _OLD_NO_PROXY="$no_proxy"
}

# Unset proxy
function unset_proxy(){
    unset http_proxy
    unset https_proxy
    echo -e "the http_proxy has been reset!"
}

# Set proxy
function set_proxy() {
    # 备份可能存在的历史代理
    [[ -z "$_OLD_HTTP_PROXY" ]] && backup_proxy

    #  只在 ~/.noproxy 存在时设置 no_proxy
    if [[ -f "$HOME/.noproxy" ]]; then
        export no_proxy=$(paste -sd, "$HOME/.noproxy")
    fi

    export http_proxy="http://127.0.0.1:1087"
    export https_proxy=$http_proxy
}

# Add git worktree from source repositories
# Usage: worktree <repo_name> [branch_name]
#   repo_name: name of the repository in WORKTREE_ROOT_PATH
#   branch_name: branch to checkout (default: master)
function worktree() {
    local repo_name="$1"
    local branch_name="${2:-master}"
    local config_file=".workspace.config"

    # Check if repo_name is provided
    if [[ -z "$repo_name" ]]; then
        echo "Error: repo_name is required"
        echo "Usage: worktree <repo_name> [branch_name]"
        return 1
    fi

    # Check if .workspace.config exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: $config_file not found in current directory"
        return 1
    fi

    # Parse WORKTREE_ROOT_PATH from config file
    local WORKTREE_ROOT_PATH
    WORKTREE_ROOT_PATH=$(grep -E '^WORKTREE_ROOT_PATH\s*=' "$config_file" 2>/dev/null | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/^["'"'"']//;s/["'"'"']$//')

    # Check if WORKTREE_ROOT_PATH is set
    if [[ -z "$WORKTREE_ROOT_PATH" ]]; then
        echo "Error: WORKTREE_ROOT_PATH not defined in $config_file"
        return 1
    fi

    # Check if WORKTREE_ROOT_PATH directory exists
    if [[ ! -d "$WORKTREE_ROOT_PATH" ]]; then
        echo "Error: WORKTREE_ROOT_PATH directory does not exist: $WORKTREE_ROOT_PATH"
        return 1
    fi

    # Construct the source repository path
    local source_repo="$WORKTREE_ROOT_PATH/$repo_name"

    # Check if the source repository exists
    if [[ ! -d "$source_repo" ]]; then
        echo "Error: repository not found: $source_repo"
        return 1
    fi

    # Check if it's a valid git repository
    if [[ ! -d "$source_repo/.git" ]]; then
        echo "Error: not a valid git repository: $source_repo"
        return 1
    fi

    # Create worktree using git worktree add (in current directory)
    local worktree_path="$(pwd)/$repo_name"
    echo "Running: git -C \"$source_repo\" worktree add -b \"$worktree_path\" \"$branch_name\""
    git -C "$source_repo" worktree add -b "$branch_name" "$worktree_path"

    if [[ $? -eq 0 ]]; then
        echo "Worktree created: $repo_name (branch: $branch_name)"
    else
        echo "Error: failed to create worktree"
        return 1
    fi
}
