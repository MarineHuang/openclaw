# QQ官宣接入openclaw，附详细教程

**发布时间**：2026年3月8日 17:29
**发布方**：搞机牛（广东）

近期腾讯在openclaw相关领域的热度持续走高，不仅在公司楼下推出免费的openclaw安装服务活动，openclaw多个相关词条也登上热搜，使其成为现象级产品。腾讯QQ也正式官宣接入openclaw，仅需3步即可完成创建，创建成功后就能通过QQ控制openclaw执行相关操作，以下是详细的操作教程。

## 第一步：进入QQ开放平台

1. 访问QQ开放平台专属登录地址：[https://q.qq.com/qqbot/openclaw/login.html](https://q.qq.com/qqbot/openclaw/login.html)
2. 使用QQ扫码完成登录，若未注册平台账号，扫码确认后将自动完成注册并登录
3. **操作建议**：推荐使用电脑端打开该页面，操作会更便捷

平台内的快速开始指南显示，使用QQ-BOT可通过“创建机器人-配置接入密钥-打开手Q开始对话”的流程，快速开启智能助手体验。

## 第二步：创建机器人

1. 登录成功后，在页面中找到「创建机器人」按钮并点击，**注意**：单个账号最多只能创建5个机器人
2. 机器人创建成功后，页面会显示对应的**AppID**和**AppSecret**，这两个信息是后续对接的核心凭证，需妥善保管
3. 机器人创建后，可在QQ聊天列表中看到该龙虾机器人，但此时无法进行对话，发送消息会收到「该机器人去火星了，请稍后再试」的提示，需完成后续对接步骤后才能使用

创建的机器人支持绑定至OpenClaw环境，绑定后可通过该机器人给OpenClaw下达指令，同时支持Markdown、图片、语音、文件等多媒体消息收发，手机端和桌面端QQ均可使用。

## 第三步：对接openclaw

对接分**已部署openclaw**和**未部署openclaw**两种情况，可根据自身实际选择对应方式：

### 情况一：已自行部署openclaw

在终端中依次执行以下三条命令，完成对接配置：

```bash
# 1. 安装QQbot插件
openclaw plugins install @tencent-connect/openclaw-qqbot@latest
# 2. 配置绑定，将引号内替换为实际的appid和appsecret
openclaw channels add --channel qqbot --token "你的appid:你的appsecret"
# 3. 重启openclaw服务
openclaw gateway restart
```

### 情况二：未部署openclaw（腾讯云一键部署）

腾讯官方提供了腾讯云一键部署方案，该方案需要购买服务器，具体操作可参考官方教程：[https://cloud.tencent.com/developer/article/2624003](https://cloud.tencent.com/developer/article/2624003)

1. 若需新购服务器，可前往腾讯云Lighthouse产品购买页，或参与腾讯云OpenClaw专属活动优惠下单
2. 若在2026年2月11日前使用OpenClaw应用模板创建了Lighthouse服务器，建议参考官方教程更新版本
3. 服务器部署成功后，进入腾讯云控制台，点击对应服务器卡片进入“管理实例”页面
4. 在页面的「应用管理」模块中，填入之前创建QQ机器人时获取的App ID和App Secret，完成配置

## 重要注意事项

1. 妥善保护API Key，避免信息泄漏造成额外损失
2. OpenClaw调用模型时会携带较多上下文信息，以保证任务连续性与准确性，因此Token消耗可能较高，使用时需关注Token用量与计费情况
3. 若在安装Skill时遇到限频等问题，建议根据官方教程手动安装
4. 为提升安全能力，强烈建议立即升级至OpenClaw最新版本

OpenClaw服务器配置完成后，可在后台看到模型、通道等配置模块，目前支持对接Moonshot AI(Kimi国内)等模型，也可在ClawHub中搜索并安装各类Skill（如tavily-search 1.0.0），丰富机器人功能。

## QQ机器人支持的消息类型

| QQ机器人支持的消息类型       | 是否支持 |
| ---------------------------- | -------- |
| 接收文本信息                 | 已支持   |
| 接收图片                     | 已支持   |
| 接收文件                     | 已支持   |
| 回复文本信息                 | 已支持   |
| 回复图片                     | 已支持   |
| 回复内容支持Markdown格式     | 已支持   |
| 主动发送消息(如定时发送提醒) | 已支持   |
| 语音消息                     | 已支持   |
| 回复文件                     | 即将支持 |
| 历史消息引用                 | 不支持   |
