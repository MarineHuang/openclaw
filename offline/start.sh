#!/bin/bash
cd "$(dirname "$0")"

# ── 默认配置 ──────────────────────────────────────────────────────
DEFAULT_PORT=18789
DEFAULT_BIND="loopback"
DAEMON_MODE=false
ACTION=""
PID_FILE=".openclaw/gateway.pid"
LOG_FILE=".openclaw/logs/gateway.log"

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
  -d, --daemon       后台运行模式
  --stop             停止后台运行的服务
  --status           查看服务状态
  -h, --help         显示此帮助信息

示例:
  ./start.sh                           # 默认端口 18789，仅本机访问
  ./start.sh --port 8080               # 使用端口 8080
  ./start.sh --public                  # 公网访问模式
  ./start.sh --bind lan --port 8080    # 局域网访问，端口 8080
  ./start.sh --daemon                  # 后台运行
  ./start.sh --status                  # 查看状态
  ./start.sh --stop                    # 停止服务

注意:
  --public 和 --allow-http 选项会降低安全性，仅适合内网/测试环境。
  生产环境请使用 HTTPS 反向代理。

EOF
    exit 0
}

# ── 检查服务状态 ──────────────────────────────────────────────────────
check_status() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "服务状态: 运行中 (PID: $PID)"
            echo "日志文件: $LOG_FILE"
            echo ""
            echo "最近的日志:"
            if [ -f "$LOG_FILE" ]; then
                tail -n 5 "$LOG_FILE"
            else
                echo "  (日志文件不存在)"
            fi
            exit 0
        else
            echo "服务状态: 已停止 (PID 文件存在但进程未运行)"
            rm -f "$PID_FILE"
            exit 1
        fi
    else
        echo "服务状态: 未运行"
        exit 1
    fi
}

# ── 停止服务 ──────────────────────────────────────────────────────
stop_service() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "正在停止 OpenClaw Gateway (PID: $PID)..."
            kill "$PID"
            sleep 2
            if kill -0 "$PID" 2>/dev/null; then
                echo "进程未响应，强制终止..."
                kill -9 "$PID" 2>/dev/null
            fi
            rm -f "$PID_FILE"
            echo "服务已停止"
            exit 0
        else
            echo "服务未运行 (PID 文件过期，已清理)"
            rm -f "$PID_FILE"
            exit 1
        fi
    else
        echo "服务未运行 (无 PID 文件)"
        exit 1
    fi
}

# ── 解析参数 ──────────────────────────────────────────────────────
PORT="$DEFAULT_PORT"
BIND="$DEFAULT_BIND"
ALLOW_HTTP=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "错误: --port 需要指定端口号"
                echo "使用 --help 查看帮助"
                exit 1
            fi
            PORT="$2"; shift 2 ;;
        --bind)
            if [[ -z "$2" || "$2" == --* ]]; then
                echo "错误: --bind 需要指定地址"
                echo "使用 --help 查看帮助"
                exit 1
            fi
            BIND="$2"; shift 2 ;;
        --public) BIND="lan"; ALLOW_HTTP=true; shift ;;
        --allow-http) ALLOW_HTTP=true; shift ;;
        -d|--daemon) DAEMON_MODE=true; shift ;;
        --stop) ACTION="stop"; shift ;;
        --status) ACTION="status"; shift ;;
        -h|--help) show_help ;;
        *) echo "未知参数: $1"; echo "使用 --help 查看帮助"; exit 1 ;;
    esac
done

# 处理独立操作
case "$ACTION" in
    stop) stop_service ;;
    status) check_status ;;
esac

# 后台运行模式启动
if [[ "$DAEMON_MODE" == true ]]; then
    # 检查是否已在运行
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "服务已在运行中 (PID: $PID)"
            echo "使用 ./start.sh --status 查看状态"
            echo "使用 ./start.sh --stop 停止服务"
            exit 0
        else
            rm -f "$PID_FILE"
        fi
    fi

    # 创建日志目录
    mkdir -p ".openclaw/logs"

    echo "============================================"
    echo " OpenClaw 离线版 (后台模式)"
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
    echo " 日志文件: $LOG_FILE"
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
        echo " 已初始化默认配置"
    fi

    # 首次启动时安装预置的 QQ Bot 插件
    if [ -d "plugins/openclaw-qqbot" ] && [ ! -d ".openclaw/extensions/openclaw-qqbot" ]; then
        mkdir -p ".openclaw/extensions"
        cp -r "plugins/openclaw-qqbot" ".openclaw/extensions/openclaw-qqbot"
        echo " 已安装 QQ Bot 插件"
    fi

    # 应用公网访问配置
    if [[ "$ALLOW_HTTP" == true ]]; then
        CONFIG_FILE=".openclaw/openclaw.json"
        if command -v node &>/dev/null; then
            node -e "
const fs = require('fs');
const cfg = JSON.parse(fs.readFileSync('$CONFIG_FILE', 'utf8'));
cfg.gateway = cfg.gateway || {};
cfg.gateway.controlUi = cfg.gateway.controlUi || {};
cfg.gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback = true;
cfg.gateway.controlUi.dangerouslyDisableDeviceAuth = true;
fs.writeFileSync('$CONFIG_FILE', JSON.stringify(cfg, null, 2));
" 2>/dev/null
            echo " 已启用公网 HTTP 访问配置"
        fi
    fi

    # 后台启动
    nohup ./node-runtime/bin/node openclaw.mjs gateway --allow-unconfigured --port "$PORT" --bind "$BIND" >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    sleep 1
    if kill -0 $(cat "$PID_FILE") 2>/dev/null; then
        echo "服务已启动 (PID: $(cat $PID_FILE))"
        echo ""
        echo "命令:"
        echo "  查看日志: tail -f $LOG_FILE"
        echo "  查看状态: ./start.sh --status"
        echo "  停止服务: ./start.sh --stop"
    else
        echo "启动失败，请查看日志: $LOG_FILE"
        exit 1
    fi
    exit 0
fi

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