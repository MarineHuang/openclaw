#!/bin/bash
cd "$(dirname "$0")"

# 默认端口
DEFAULT_PORT=18789
PORT="${1:-$DEFAULT_PORT}"

echo "============================================"
echo " OpenClaw 离线版"
echo "============================================"
echo ""
echo " 正在启动 OpenClaw Gateway..."
echo " 启动后请在浏览器中打开:"
echo ""
echo "   http://127.0.0.1:${PORT}/#token=<your token>"
echo ""
echo " 按 Ctrl+C 可停止服务"
echo "============================================"
echo ""

export OPENCLAW_STATE_DIR="$(pwd)/.openclaw"
export OPENCLAW_HOME="$(pwd)"
export OPENCLAW_DEFAULT_LOCALE=zh-CN
export NODE_ENV=production

# 首次启动时初始化默认配置
if [ ! -f ".openclaw/openclaw.json" ]; then
    mkdir -p ".openclaw"
    cp "openclaw-providers.json" ".openclaw/providers.json"
    cp "openclaw-main.json"      ".openclaw/openclaw.json"
    echo " 已初始化默认配置，请在 Dashboard 中选择提供商并填写 API Key"
    echo ""
fi

# 首次启动时安装预置的 QQ Bot 插件
if [ -d "plugins/openclaw-qqbot" ] && [ ! -d ".openclaw/extensions/openclaw-qqbot" ]; then
    mkdir -p ".openclaw/extensions"
    cp -r "plugins/openclaw-qqbot" ".openclaw/extensions/openclaw-qqbot"
    echo " 已安装 QQ Bot 插件，请在 Dashboard 中配置 QQ 频道"
    echo ""
fi

./node-runtime/bin/node openclaw.mjs gateway --allow-unconfigured --port "$PORT"
