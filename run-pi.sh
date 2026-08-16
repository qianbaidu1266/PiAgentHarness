#!/usr/bin/env bash
# 项目内一键启动 Pi：加载本项目 .env 配置的模型 key 后运行 pi。
# 用法：./run-pi.sh [额外参数]
set -euo pipefail
cd "$(dirname "$0")"

# 1. 加载项目本地配置文件 .env（DEEPSEEK_API_KEY 等）
if [ -f .env ]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

# 2. 屏蔽 shell 环境里残留的 Anthropic 中转配置，避免 pi 误选 Anthropic 通道
unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_OAUTH_TOKEN 2>/dev/null || true

# 3. 启动 pi（项目 .pi/settings.json 已固定默认模型为 DeepSeek）
exec ./pi-test.sh "$@"
