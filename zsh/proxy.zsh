# 启动代理
set_proxy

alias start_corplink='sudo launchctl kickstart -k system/com.volcengine.corplink.service && open -a "/Applications/CorpLink.app"'

# 停止服务
alias stop_corplink='osascript -e '\''tell application "/Applications/CorpLink.app" to quit'\'' && sudo pkill -f corplink-service'
