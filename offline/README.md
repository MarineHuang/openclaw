# OpenClaw 离线安装包 使用说明

## 快速开始

### Windows 用户

1. 将本压缩包解压到任意目录（如 `D:\openclaw`）
2. 双击 `start.bat` 或右键 `start.ps1` 选择"使用 PowerShell 运行"
3. 在浏览器中打开 http://127.0.0.1:18789

> 提示：如果 PowerShell 提示"无法加载文件...因为在此系统上禁止运行脚本"，
> 请以管理员身份打开 PowerShell 并执行：`Set-ExecutionPolicy RemoteSigned`

### Linux / macOS 用户

1. 解压压缩包：
   ```bash
   tar xzf openclaw-offline-*.tar.gz
   cd openclaw-offline-*
   ```
2. 运行启动脚本：
   ```bash
   ./start.sh
   ```
3. 在浏览器中打开 http://127.0.0.1:18789

## 说明

- 本离线包已包含 Node.js 运行时和所有依赖，**无需安装任何软件**
- 默认监听端口为 **18789**，如需修改请编辑启动脚本中的 `--port` 参数
- 数据存储在**启动脚本同目录**下的 `.openclaw` 文件夹中（便于移植和隔离）

## 常见问题

### 端口被占用

如果提示端口 18789 被占用，可以修改启动脚本中的端口号，例如改为 `--port 28789`。

### Linux 下提示权限不足

运行以下命令添加执行权限：

```bash
chmod +x start.sh node-runtime/bin/node
```

### macOS 提示无法验证开发者

首次运行时 macOS 可能提示"无法验证开发者"，请在 **系统设置 → 隐私与安全性** 中允许运行。

### 云服务器部署：start.sh 启动后本机以外无法访问

**现象**：在云服务器上直接运行 `./start.sh` 后，从本地浏览器访问 `http://<公网IP>:18789` 无响应或连接被拒绝；但在服务器本机访问 `http://127.0.0.1:18789` 正常。

**原因**：`start.sh` 启动 gateway 时没有指定 `--bind` 参数，默认行为是只绑定 loopback 地址（`127.0.0.1` 和 `::1`），不监听外部网卡，外部请求无法到达。

**解决**：不直接运行 `start.sh`，改为手动执行以下命令（在解压目录内）：

```bash
export OPENCLAW_STATE_DIR="$(pwd)/.openclaw"
export OPENCLAW_DEFAULT_LOCALE=zh-CN
export NODE_ENV=production

# 首次启动时初始化配置（可选，start.sh 会自动做，手动启动需手动补）
mkdir -p .openclaw
[ -f .openclaw/openclaw.json ] || cp openclaw-main.json .openclaw/openclaw.json
[ -f .openclaw/providers.json ] || cp openclaw-providers.json .openclaw/providers.json

./node-runtime/bin/node openclaw.mjs gateway --allow-unconfigured --port 18789 --bind lan
```

`--bind lan` 让 gateway 监听所有网卡（`0.0.0.0`），使公网/局域网可访问。

**原理**：OpenClaw gateway 的 `--bind` 参数控制监听范围，取值为：

- `loopback`（默认）：仅本机 127.0.0.1，最安全
- `lan`：所有本地网卡（0.0.0.0），适合局域网或云服务器
- `tailnet`：仅 Tailscale 网卡
- `auto`：自动选择

云服务器通常有公网/内网 IP 映射，`lan` 模式会同时监听这些地址，从外部即可访问。
**注意**：开放到公网前，确保云控制台安全组已放行对应端口（默认 18789）。

---

### 云服务器部署：Origin 校验失败（non-loopback Control UI requires allowedOrigins）

**现象**：在云服务器上使用 `--bind lan` 启动 gateway 后，服务启动报错并退出：

```
Gateway failed to start: non-loopback Control UI requires gateway.controlUi.allowedOrigins
(set explicit origins), or set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback=true
```

**原因**：OpenClaw 默认只允许 loopback（127.0.0.1）访问 Control UI。当绑定到非 loopback 地址（局域网或公网）时，为防止跨站请求伪造（CSRF），gateway 要求明确配置允许的 Origin，否则拒绝启动。

**解决**：在 `.openclaw/openclaw.json` 的 `gateway` 配置块中添加：

```json
"gateway": {
  "controlUi": {
    "dangerouslyAllowHostHeaderOriginFallback": true
  }
}
```

该选项启用 Host 头降级模式：gateway 将请求的 `Host` 头作为合法 origin 接受，无需列举固定 IP。
**注意**：此选项仅适合内网/测试环境。生产环境应配置 HTTPS 反向代理（如 Nginx + Let's Encrypt），并改用 `allowedOrigins` 列出具体域名。

---

### 通过 HTTP 公网访问时显示 "device identity required"

**现象**：浏览器通过 HTTP 访问 Dashboard UI，页面或控制台显示 `device identity required`，无法正常连接 gateway。

**原因（两层）**：

1. **浏览器安全上下文限制**：`crypto.subtle`（Web Crypto API）只在安全上下文（HTTPS 或 localhost）下可用。通过 HTTP 访问时，浏览器拒绝提供该 API，导致 UI 无法生成设备身份（Ed25519 密钥对及签名）。

2. **Gateway 拒绝无身份连接**：Gateway 的连接策略（`connect-policy.ts`）要求 Control UI 必须提供设备身份（device identity）或通过共享 token 认证（`sharedAuthOk=true`）才能建立连接。无设备身份且无 token 时，gateway 返回 `reject-device-required`。

**解决（两步都需要）**：

**步骤一**：在 `.openclaw/openclaw.json` 中禁用设备身份校验：

```json
"gateway": {
  "controlUi": {
    "dangerouslyAllowHostHeaderOriginFallback": true,
    "dangerouslyDisableDeviceAuth": true
  }
}
```

该选项让 gateway 跳过设备身份验证，仅依赖 token 认证。

**步骤二**：访问 Dashboard 时在 URL 中携带 gateway token：

```
http://<服务器IP>:18789?token=<gateway.auth.token 的值>
```

token 值见 `.openclaw/openclaw.json` 中的 `gateway.auth.token` 字段。UI 加载后会自动从 URL 中剥离 token，不会留在地址栏。

**原理**：携带 token 后，gateway 侧 `sharedAuthOk=true`，`roleCanSkipDeviceIdentity("operator", true)` 返回 `true`，连接被允许。

**注意**：`dangerouslyDisableDeviceAuth` 会削弱中间人攻击防护，仅适合内网/测试环境。生产环境应通过 HTTPS 反代解决，届时浏览器可正常访问 `crypto.subtle`，设备身份认证流程自动生效，无需此选项。

---

## 技术信息

- OpenClaw 版本：见 package.json 中的 version 字段
- Node.js 运行时：见 node-runtime/ 目录
- 项目主页：https://github.com/openclaw/openclaw
