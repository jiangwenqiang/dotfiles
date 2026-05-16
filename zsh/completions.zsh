# Setup completion for worktree
_worktree() {
    local -a repos branches
    local repo_root repo_name item gitdir_content

    # 从当前目录的任意 worktree 中找到实际仓库根目录
    for item in *(/); do
        if [[ -f "$item/.git" ]]; then
            gitdir_content=$(cat "$item/.git" 2>/dev/null | grep "^gitdir:" | cut -d' ' -f2)
            if [[ -n "$gitdir_content" ]]; then
                repo_root=$(dirname "$(dirname "$(dirname "$(dirname "$gitdir_content")")")")
                break
            fi
        elif [[ -d "$item/.git" ]]; then
            repo_root="$(pwd)/.."
            break
        fi
    done 2>/dev/null

    # 如果当前目录为空，向上查找包含多个 Git 仓库的目录
    if [[ -z "$repo_root" ]]; then
        local search_dir="$(pwd)"
        local max_depth=5
        for ((i=0; i<max_depth; i++)); do
            local repo_count=0
            for item in $search_dir/*(/N); do
                if [[ -d "$item/.git" || -f "$item/.git" ]]; then
                    ((repo_count++))
                fi
            done
            if [[ $repo_count -ge 2 ]]; then
                repo_root="$search_dir"
                break
            fi
            search_dir="$(dirname "$search_dir")"
        done
    fi

    case $CURRENT in
        2)
            if [[ -n "$repo_root" && -d "$repo_root" ]]; then
                repos=(${repo_root}/*(/N:t))
                _describe 'repository' repos
            else
                _message 'repo_name'
            fi
            ;;
        3)
            repo_name="$words[2]"
            if [[ -n "$repo_root" && -d "$repo_root/$repo_name" ]]; then
                branches=(${(f)"$(git -C "$repo_root/$repo_name" branch 2>/dev/null | sed 's/^[* ] //')"})
                _describe 'branch' branches
            else
                _message 'branch_name'
            fi
            ;;
    esac
}

compdef _worktree worktree
