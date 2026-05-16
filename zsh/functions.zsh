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
#   repo_name: name of the repository (e.g., "ware-core")
#   branch_name: branch to checkout (default: master)
#
# 自动从当前目录的 worktree 中找到实际仓库位置，无需配置文件
function worktree() {
    local repo_name="$1"
    local branch_name="${2:-master}"
    local current_dir="$(pwd)"

    # 参数校验
    if [[ -z "$repo_name" ]]; then
        echo "Error: repo_name is required"
        echo "Usage: worktree <repo_name> [branch_name]"
        return 1
    fi

    # 检查当前目录下是否已存在同名目录/文件
    if [[ -e "$current_dir/$repo_name" ]]; then
        echo "Error: '$repo_name' 已存在于当前目录"
        if [[ -d "$current_dir/$repo_name/.git" || -f "$current_dir/$repo_name/.git" ]]; then
            echo "提示: 这是一个 Git 仓库，如需切换分支请使用: cd $repo_name && git checkout <branch>"
        else
            echo "提示: 请先删除或重命名现有文件/目录"
        fi
        return 1
    fi

    # 从当前目录的任意 worktree 中找到实际仓库根目录
    local repo_root=""
    for item in "$current_dir"/*; do
        if [[ -f "$item/.git" ]]; then
            # worktree 的 .git 文件内容: gitdir: /path/to/repo/.git/worktrees/<name>
            local gitdir_content
            gitdir_content=$(cat "$item/.git" 2>/dev/null | grep "^gitdir:" | cut -d' ' -f2)
            if [[ -n "$gitdir_content" ]]; then
                # 从 /path/to/repo/.git/worktrees/<name> 解析出 /path/to/
                repo_root=$(dirname "$(dirname "$(dirname "$(dirname "$gitdir_content")")")")
                break
            fi
        elif [[ -d "$item/.git" ]]; then
            # 普通 Git 仓库，使用当前目录的父目录
            repo_root="$(dirname "$current_dir")"
            break
        fi
    done

    # 如果当前目录为空，向上查找包含多个 Git 仓库的目录
    if [[ -z "$repo_root" ]]; then
        local search_dir="$current_dir"
        local max_depth=5
        for ((i=0; i<max_depth; i++)); do
            local repo_count=0
            for item in "$search_dir"/*; do
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

    if [[ -z "$repo_root" ]]; then
        echo "Error: 无法找到仓库根目录"
        echo "提示: 请确保当前目录包含 worktree，或位于包含多个 Git 仓库的目录下"
        return 1
    fi

    # 查找目标仓库
    local source_repo="$repo_root/$repo_name"

    # 验证目标仓库存在
    if [[ ! -d "$source_repo" ]]; then
        echo "Error: 仓库 '$repo_name' 不存在于 $repo_root"
        echo "可用的仓库:"
        for item in "$repo_root"/*; do
            if [[ -d "$item/.git" || -f "$item/.git" ]]; then
                echo "  - $(basename "$item")"
            fi
        done
        return 1
    fi

    # 验证是否为 Git 仓库
    if [[ ! -d "$source_repo/.git" && ! -f "$source_repo/.git" ]]; then
        echo "Error: '$source_repo' 不是有效的 Git 仓库"
        return 1
    fi

    # 分支冲突检测
    local existing_worktree
    existing_worktree=$(git -C "$source_repo" worktree list 2>/dev/null | grep "\[$branch_name\]" | awk '{print $1}')
    if [[ -n "$existing_worktree" ]]; then
        echo "Error: 分支 '$branch_name' 已在以下 worktree 中检出:"
        echo "  $existing_worktree"
        echo ""
        echo "解决方案:"
        echo "  1. 使用其他分支: worktree $repo_name <other-branch>"
        echo "  2. 先删除现有 worktree: git worktree remove <path>"
        return 1
    fi

    # 创建 worktree
    local worktree_path="$current_dir/$repo_name"
    echo "创建 worktree..."
    echo "  仓库: $source_repo"
    echo "  分支: $branch_name"
    echo "  目标: $worktree_path"
    echo ""

    git -C "$source_repo" worktree add -b "$branch_name" "$worktree_path"

    if [[ $? -eq 0 ]]; then
        echo "✅ Worktree 创建成功"
        echo "   位置: $worktree_path"
        echo "   分支: $branch_name"
        echo ""
        echo "当前 worktree 列表:"
        git -C "$source_repo" worktree list
    else
        echo "❌ Worktree 创建失败"
        return 1
    fi
}

# claude code
function claude() {
  command claude \
    --dangerously-skip-permissions \
    "$@"
}
