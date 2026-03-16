#!/bin/bash
cd "$(dirname "$0")"

# ── 默认配置 ──────────────────────────────────────────────────────
DEFAULT_PORT=18789
DEFAULT_BIND="loopback"

# ── 帮助信息 ──────────────────────────────────────────────────────
show_help() {
    cat << 'EOF'
OpenClaw 离线版启动脚本

用法:
  ./start.sh [选项]

选项:
  --port <端口>      监听端口 (默认: 18789)
  --bind <地址>      绑定地址: loopback, lan, tailnet, auto (默认: loopback)
  --public           公网访问模式 (等同于 --bind lan --allow-http)
  --allow-http       允许 HTTP 公网访问 (禁用设备身份校验)
  -h, --help         显示此帮助信息

示例:
  ./start.sh                           # 默认端口 18789，仅本机访问
  ./start.sh --port 8080               # 使用端口 8080
  ./start.sh --public                  # 公网访问模式
  ./start.sh --bind lan --port 8080    # 局域网访问，端口 8080

注意:
  --public 和 --allow-http 选项会降低安全性，仅适合内网/测试环境。
  生产环境请使用 HTTPS 反向代理。

EOF
    exit 0
}

# ── 解析参数 ──────────────────────────────────────────────────────
PORT="$DEFAULT_PORT"
BIND="$DEFAULT_BIND"
ALLOW_HTTP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)   PORT="$2"; shift 2 ;;
        --bind)   BIND="$2"; shift 2 ;;
        --public) BIND="lan"; ALLOW_HTTP=true; shift ;;
        --allow-http) ALLOW_HTTP=true; shift ;;
        -h|--help) show_help ;;
        *) echo "未知参数: $1"; echo "使用 --help 查看帮助"; exit 1 ;;
    esac
done

echo "============================================"
echo " OpenClaw 离线版"
echo "============================================"
echo ""
echo " 正在启动 OpenClaw Gateway..."
echo " 启动后请在浏览器中打开:"
echo ""
echo "   http://127.0.0.1:${PORT}/#token=<your token>"
echo ""
if [[ "$BIND" != "loopback" ]]; then
    echo " 绑定地址: $BIND"
fi
if [[ "$ALLOW_HTTP" == true ]]; then
    echo " ⚠️  HTTP 公网访问已启用 (安全性降低)"
fi
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

# 应用公网访问配置
if [[ "$ALLOW_HTTP" == true ]]; then
    CONFIG_FILE=".openclaw/openclaw.json"
    if command -v node &>/dev/null; then
        # 使用 Node.js 合并配置
        node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
cfg.gateway = cfg.gateway || {};
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
"
        echo " 已启用公网 HTTP 访问配置"
        echo ""
    else
        echo " ⚠️  无法自动配置公网访问，请手动编辑 .openclaw/openclaw.json"
        echo ""
    fi
fi

./node-runtime/bin/node openclaw.mjs gateway --allow-unconfigured --port "$PORT" --bind "$BIND"