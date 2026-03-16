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
- 默认监听端口为 **18789**，可通过启动脚本的命令行参数指定其他端口
- 数据存储在**启动脚本同目录**下的 `.openclaw` 文件夹中（便于移植和隔离）

### 启动参数

```bash
# 查看帮助
./start.sh --help

# Linux/macOS
./start.sh --port 28789                    # 指定端口
./start.sh --bind lan                      # 局域网访问
./start.sh --public                        # 公网访问模式 (推荐云服务器使用)

# Windows (PowerShell)
.\start.ps1 -Port 28789                    # 指定端口
.\start.ps1 -Bind lan                      # 局域网访问
.\start.ps1 -Public                        # 公网访问模式

# Windows (CMD)
start.bat --port 28789                     # 指定端口
start.bat --public                         # 公网访问模式
```

### 参数说明

| 参数                          | 说明                                                   |
| ----------------------------- | ------------------------------------------------------ |
| `--port <端口>` / `-Port`     | 监听端口，默认 18789                                   |
| `--bind <地址>` / `-Bind`     | 绑定地址：`loopback`（默认）、`lan`、`tailnet`、`auto` |
| `--public` / `-Public`        | 公网访问模式，等同于 `--bind lan --allow-http`         |
| `--allow-http` / `-AllowHttp` | 允许 HTTP 公网访问（自动配置安全选项）                 |
| `--help` / `-Help`            | 显示帮助信息                                           |

> ⚠️ `--public` 和 `--allow-http` 会降低安全性，仅适合内网/测试环境。生产环境请使用 HTTPS 反向代理。

## 常见问题

### 端口被占用

如果提示端口被占用，可以通过 `--port` 参数指定其他端口：

```bash
./start.sh --port 28789
```

### Linux 下提示权限不足

运行以下命令添加执行权限：

```bash
chmod +x start.sh node-runtime/bin/node
```

### macOS 提示无法验证开发者

首次运行时 macOS 可能提示"无法验证开发者"，请在 **系统设置 → 隐私与安全性** 中允许运行。

### 云服务器部署：公网访问配置

**快速方案**：使用 `--public` 参数一键配置公网访问：

```bash
./start.sh --public
# 或指定端口
./start.sh --public --port 8080
```

`--public` 参数会自动完成以下配置：

1. 绑定到所有网卡 (`--bind lan`)
2. 在配置文件中启用 HTTP 公网访问选项

**注意**：开放到公网前，确保云控制台安全组已放行对应端口（默认 18789）。

---

### 云服务器部署：手动配置（高级）

如果需要更精细的控制，可以手动配置：

**问题：本机以外无法访问**

默认只绑定 loopback 地址，外部请求无法到达。使用 `--bind lan` 监听所有网卡：

```bash
./start.sh --bind lan
```

**绑定地址说明**：

| 值                 | 说明                                          |
| ------------------ | --------------------------------------------- |
| `loopback`（默认） | 仅本机 127.0.0.1，最安全                      |
| `lan`              | 所有本地网卡（0.0.0.0），适合局域网或云服务器 |
| `tailnet`          | 仅 Tailscale 网卡                             |
| `auto`             | 自动选择                                      |

---

### 云服务器部署：Origin 校验失败

**现象**：使用 `--bind lan` 后报错：

```
Gateway failed to start: non-loopback Control UI requires gateway.controlUi.allowedOrigins
```

**解决**：使用 `--allow-http` 参数自动配置，或手动在 `.openclaw/openclaw.json` 中添加：

```json
"gateway": {
  "controlUi": {
    "dangerouslyAllowHostHeaderOriginFallback": true
  }
}
```

---

### 通过 HTTP 公网访问时显示 "device identity required"

**现象**：通过 HTTP 访问时显示 `device identity required`，无法连接。

**原因**：浏览器的 Web Crypto API 仅在 HTTPS 或 localhost 下可用，HTTP 下无法生成设备身份。

**解决**：使用 `--allow-http` 或 `--public` 参数自动配置，或在 `.openclaw/openclaw.json` 中添加：

```json
"gateway": {
  "controlUi": {
    "dangerouslyAllowHostHeaderOriginFallback": true,
    "dangerouslyDisableDeviceAuth": true
  }
}
```

然后访问时在 URL 中携带 token：

```
http://<服务器IP>:18789?token=<gateway.auth.token 的值>
```

token 值见 `.openclaw/openclaw.json` 中的 `gateway.auth.token` 字段。

> ⚠️ 以上配置会降低安全性，仅适合内网/测试环境。生产环境请使用 HTTPS 反向代理。

---

## 技术信息

- OpenClaw 版本：见 package.json 中的 version 字段
- Node.js 运行时：见 node-runtime/ 目录
- 项目主页：https://github.com/openclaw/openclaw
