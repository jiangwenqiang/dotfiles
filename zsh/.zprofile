# Homebrew —— ARM 前缀为 /opt/homebrew，Intel 为 /usr/local。
# 刻意不用 uname -m 判断：Apple Silicon 上经 Rosetta 启动的 shell 会报 x86_64，
# 但 brew 实际仍位于 /opt/homebrew。探测 brew 实际路径比探测架构可靠。
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
