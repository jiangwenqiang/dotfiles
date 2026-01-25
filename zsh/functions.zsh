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
