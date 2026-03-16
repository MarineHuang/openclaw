最近这阵子，OpenClaw 的爆火不是偶然：一方面，大模型越来越能干；另一方面，大家突然意识到——真正的生产力不在模型的聊天框里，而在你每天用的、沉淀了大量信息的工作软件里。于是 OpenClaw 这种“把 AI 变成可扩展工具箱”的智能体编排框架就被点燃了：能接模型、能接工具、能接各种服务，装上去就像给自己雇了个不抱怨、技能极多，还7×24小时待命的数字同事。
所以，你或许早就把那只“小龙虾”接进了飞书里：它能帮你写东西、查资料、出方案。但它也经常会说，“我没有飞书文档/消息/日历权限，请把内容发给我”，你不得不反复复制粘贴。AI 在旁边疯狂进化，人却还在当搬运工：搬文档、搬群聊、搬日程，搬到怀疑人生。
为了解决大家的痛点，今天，飞书 OpenClaw 官方插件来了！
经由用户授权，OpenClaw 可以直接以“你的”身份看文档找资料、理解群聊上下文、核对日历看档期。你说一句话，它就能伸出“钳子”，在飞书里把活儿干了——少复制粘贴，多直接交付。
我们会用一篇文章把你最关心的事一次讲清：什么是 OpenClaw、飞书官方插件目前能做什么、如何安装与更新、常见问题怎么排查。
看完照着做，几分钟就能把插件装好开用，把“会聊天的 AI”升级成“能干活的飞书助手”！

一、什么是 OpenClaw？和其他 Agent 有什么不同？
OpenClaw 是一款开源的个人 AI Agent 系统，可以运行在你的个人电脑或服务器上。
相比以往的 AI Agent，OpenClaw 最大的不同在于：他是完全属于你的私人助理，拥有长期记忆、能力持续进化，拥有更高的权限，能直接操作你电脑、本地运行、还能 24 小时主动干活。
关于 OpenClaw 架构的更多介绍，请看这篇文章：《一文完全搞懂OpenClaw（Clawdbot）附飞书对接教程！》
二、什么是 OpenClaw 飞书官方插件？用起来能有多酷？
目前有大量用户主动将 OpenClaw 接入了飞书，得益于飞书各类协同工具和良好的开放能力，能够让你的 Agent 完成很多工作。但早期 OpenClaw 上的三方飞书插件，可能遇到服务不稳定、权限授权繁琐等问题。
此次飞书推出的 OpenClaw官方插件 能让你的 OpenClaw 以你的身份更好地调用飞书的各类能力，包括了解群聊和文档中的所有信息、写文档、改文档、帮你发消息、约日程、创建多维表格等。
你说一句话，它就能伸出“钳子”，直接在飞书里帮你把活儿干了！

具体能力包括：
做你真正的数字分身：以你的身份完成工作（回消息、写文档、生成多维表格、创建文档等）；
更懂你的工作：帮你获取飞书内的海量上下文（含消息、文档、会议纪要、多维表格、日程、任务等）；
更顺畅的和你的 Openclaw 沟通，如提供消息流式生成等。
完整能力一览：
类别
能力
💬 消息
消息读取（群聊/单聊历史、话题回复）、消息发送、消息回复、消息搜索、图片/文件下载
📄 文档
创建云文档、更新云文档、读取云文档内容
📊 多维表格
创建/管理多维表格、数据表、字段、记录（增删改查、批量操作、高级筛选）、视图
📅 日历日程
日历管理、日程管理（创建/查询/修改/删除/搜索）、参会人管理、忙闲查询
✅ 任务
任务管理（创建/查询/更新/完成）、清单管理、子任务、评论

此外，相比于 Telegram 等国外平台，飞书是国内的平台，有中文的界面、文档和客服，更容易上手；目前国内的 OpenClaw 用户，绝大多数都选择了接入飞书，使用人数更多，生态更好。
相比于国内的其他平台，飞书的开放能力更强，能带来更好的体验、获取更多工作中必要的上下文，玩法更多。
总而言之，飞书是国内接入 OpenClaw 的最佳选择！

三、重要安全与风险提示（使用前必读）
🔴 核心风险
这个插件通过飞书接口连接了你的工作数据——消息、文档、日历、联系人，AI 能读到的东西理论上就有泄露的可能。虽然我们做了安全防护，但 AI 系统本身还不够成熟稳定，不能保证万无一失。
🔴 强烈建议
作为机器人供多人使用或者通过公司飞书账号使用可能会导致数据安全和隐私风险，请注意使用时需要遵守企业内的数据安全和隐私要求，避免发生数据泄露、权限突破、侵犯隐私等后果。
📌 其他操作风险
AI 并不完美，可能存在“幻觉”： 它有时会误解您的意图，或者生成看似合理但不准确的内容。
部分操作不可逆转： 例如，AI 代发的飞书消息是以您的名义发出的，发出后即成事实。
应对建议： 对于涉及发送、修改、写入等重要操作，请务必做到“先预览，再确认”，切勿让 AI 处于完全脱离人工干预的“全自动驾驶”状态。
💡OpenClaw 使用建议
先拿个人账号安全地“玩”起来，等后续安全隔离能力更成熟了，再考虑接入真实工作环境。
使用过程中遇到任何问题或体验不佳的地方，随时向我们反馈，我们正在持续快速迭代中！

四、OpenClaw 飞书官方插件安装步骤
免安装自带飞书插件的平台
使用 Coze 编程、ArkClaw 平台安装的 OpenClaw 已自带飞书插件，无需阅读后续的安装步骤。

前置准备：装好了OpenClaw
https://openclaw.ai/
OpenClaw 版本限制：
Linux/MacOS：openclaw 2026.2.26 及以上；
Windows：openclaw 2026.3.2 及以上
可通过openclaw -v命令查看；如果低于该版本可能出现异常
执行这个命令升级：npm install -g openclaw
其它升级方式可参考：https://docs.openclaw.ai/install/development-channels#switching-channels

安装飞书插件
如果历史上已安装了其他飞书插件，在这一步安装过程中将会自动禁用其他飞书插件，无需额外处理；如果你所在的平台有辅助开发 Agent ，可以试试让Agent辅助安装执行指令：
npx -y @larksuite/openclaw-lark-tools install

提示：👆如果执行这一行命令行出错，可在命令行前 增加sudo 重新执行
执行过程中通过飞书客户端 扫描二维码，可以一键创建飞书机器人。（系统将自动申请所需的权限、事件、安全设置并提交发布。如遇权限问题，请查看使用指南第五条）
如果windows 设备中扫码无法成功，可能是因为终端的分辨率问题导致，建议更换终端，使用：Cmder

创建好后，在飞书中打开机器人即可使用：
在飞书中向机器人发送任意消息，即可开始对话
确认是否安装成功，可在与AI 的对话中发送：/feishu start；如果返回了版本号信息，则代表安装成功。
为了让龙虾能学会这些新技能并正确使用，请和龙虾说“学习一下我安装的新飞书插件，列出有哪些能力”
如果想要让小龙虾可以读写你的飞书数据（如云文档、日历、消息、多维表格），可以在对话框中输入 /feishu auth 来完成批量授权

五、OpenClaw飞书官方插件使用教程
如何切换到流式输出
切换到流式输出，可运行指令（如果你是本地部署，需要去终端输入；如果是云端部署，去云端的对话框输入）：
openclaw config set channels.feishu.streaming true

不用流式输出 可以通过运行指令：
openclaw config set channels.feishu.streaming false

流式输出卡片上支持显示更多内容
openclaw config set channels.feishu.footer.elapsed true // 开启耗时
openclaw config set channels.feishu.footer.status true // 开启状态展示

设置多任务并行、独立上下文
机器人可在话题群/消息群话题模式中，针对每个话题拥有独立上下文以及多任务并行。
如需开启该能力 可运行指令
openclaw config set channels.feishu.threadSession true

如需关闭，可运行指令
openclaw config set channels.feishu.threadSession false

如何修改飞书机器人在群内的回复方式
目前插件默认方式：可被拉进群，只有@ 机器人才可回复。

模式 1：只有 @机器人 才回复（最常用）
配置方法

# 设置需要 @ 才回复

openclaw config set channels.feishu.requireMention true --json# 重启生效sh /workspace/projects/scripts/restart.sh

完整配置示例
{"channels": {"feishu": {"enabled": true,"appId": "cli\_你的AppID","appSecret": "你的AppSecret","requireMention": true,"groupPolicy": "open"}}}

模式 2：不用 @，所有消息都回复
需要额外在开发者后台申请权限-应用身份权限：获取群组中所有消息（敏感权限）im:message.group_msg
配置方法

# 设置不需要 @ 也回复

openclaw config set channels.feishu.requireMention false --json# 重启生效sh /workspace/projects/scripts/restart.sh

{"channels": {"feishu": {"enabled": true,"appId": "cli\_你的AppID","appSecret": "你的AppSecret","requireMention": false,"groupPolicy": "open"}}}

⚠️ 注意：这个模式在大群里容易刷屏，谨慎使用！
模式 3：只有指定群 @机器人 才回复（高级）
效果
大部分群：不用 @ 也能回复（或者完全不回复）
特定群：必须 @ 才回复
适合：不同群不同规则，比如工作群严格一点，闲聊群随意一点
配置方法
第一步：获取群 ID；让机器人加入群后，发送任意消息，然后在日志里找群 ID，或者让机器人回复群 ID。或飞书群设置页面中有ID
第二步：配置特定群规则

# 先设置默认所有群都不需要 @

openclaw config set channels.feishu.requireMention open --json# 然后给特定群设置需要 @（这里群ID只是示例，你要替换成真实的）
openclaw config set channels.feishu.groups.oc_xxxxxxxx.requireMention true --json# 重启生效sh /workspace/projects/scripts/restart.sh

完整配置示例
{"channels": {"feishu": {"enabled": true,"appId": "cli*你的AppID","appSecret": "你的AppSecret","requireMention": "open","groupPolicy": "open","groups": {"oc_532044075a61d112f04fa63109c75e9b": {"requireMention": true},"oc*另一个群ID": {"requireMention": true}}}}}

常见诊断命令与问题修复
可在与AI 的对话中发送
/feishu start：确认是否安装成功；
/feishu doctor：可检查配置是否正常；
如果希望批量完成用户授权，/feishu auth 可批量完成用户授权；
插件中也内置了常见问题的解决方案，遇到问题 都可以先问问小龙虾了！
如果不行，则运行指令：
npx @larksuite/openclaw-lark-tools doctor

可以查看问题，自主修复：

运行 fix尝试自动修复
npx @larksuite/openclaw-lark-tools doctor --fix

如果仍然无法修复，可在反馈群里反馈信息
运行 info 查看版本信息，反馈问题时带上辅助排查
npx @larksuite/openclaw-lark-tools info

--all查看详细配置信息
npx @larksuite/openclaw-lark-tools info --all

如果在使用插件时出现权限不足，需要申请所需权限应该如何操作？
（1）打开 飞书开放平台，在左侧目录树选择“开发配置 > 权限管理”，单击“批量导入/导出权限”按钮。

在“导入”页签中，将如下权限替换原有示例，单击“下一步，确认新增权限”按钮。
{
"scopes": {
"tenant": [
"contact:contact.base:readonly",
"docx:document:readonly",
"im:chat:read",
"im:chat:update",
"im:message.group_at_msg:readonly",
"im:message.p2p_msg:readonly",
"im:message.pins:read",
"im:message.pins:write_only",
"im:message.reactions:read",
"im:message.reactions:write_only",
"im:message:readonly",
"im:message:recall",
"im:message:send_as_bot",
"im:message:send_multi_users",
"im:message:send_sys_msg",
"im:message:update",
"im:resource",
"application:application:self_manage",
"cardkit:card:write",
"cardkit:card:read"
],
"user": [
"contact:user.employee_id:readonly",
"offline_access","base:app:copy",
"base:field:create",
"base:field:delete",
"base:field:read",
"base:field:update",
"base:record:create",
"base:record:delete",
"base:record:retrieve",
"base:record:update",
"base:table:create",
"base:table:delete",
"base:table:read",
"base:table:update",
"base:view:read",
"base:view:write_only",
"base:app:create",
"base:app:update",
"base:app:read",
"sheets:spreadsheet.meta:read",
"sheets:spreadsheet:read",
"sheets:spreadsheet:create",
"sheets:spreadsheet:write_only",
"docs:document:export",
"docs:document.media:upload",
"board:whiteboard:node:create",
"board:whiteboard:node:read",
"calendar:calendar:read",
"calendar:calendar.event:create",
"calendar:calendar.event:delete",
"calendar:calendar.event:read",
"calendar:calendar.event:reply",
"calendar:calendar.event:update",
"calendar:calendar.free_busy:read",
"contact:contact.base:readonly",
"contact:user.base:readonly",
"contact:user:search",
"docs:document.comment:create",
"docs:document.comment:read",
"docs:document.comment:update",
"docs:document.media:download",
"docs:document:copy",
"docx:document:create",
"docx:document:readonly",
"docx:document:write_only",
"drive:drive.metadata:readonly",
"drive:file:download",
"drive:file:upload",
"im:chat.members:read",
"im:chat:read",
"im:message",
"im:message.group_msg:get_as_user",
"im:message.p2p_msg:get_as_user",
"im:message:readonly",
"search:docs:read",
"search:message",
"space:document:delete",
"space:document:move",
"space:document:retrieve",
"task:comment:read",
"task:comment:write",
"task:task:read",
"task:task:write",
"task:task:writeonly",
"task:tasklist:read",
"task:tasklist:write",
"wiki:node:copy",
"wiki:node:create",
"wiki:node:move",
"wiki:node:read",
"wiki:node:retrieve",
"wiki:space:read",
"wiki:space:retrieve",
"wiki:space:write_only"
]
}
}

在弹窗中确认权限无误后，单击“申请开通”按钮，完成操作。
相关权限的具体含义可查看飞书API权限列表。

（2）发布应用。
单击顶部的“创建版本”按钮。

（3）按需配置应用版本号、默认能力及更新说明等信息。了解更多。

（4）单击页面底部的“保存”按钮，创建版本。

（5）单击页面右上角的“确认发布”按钮，完成应用发布。

如何在飞书插件中配置OpenClaw 关联多个飞书机器人，对应不同Agent
操作手册：如何在飞书插件中配置 OpenClaw 关联多个飞书机器人，对应不同Agent
快捷方法：
创建新的飞书机器人，用于关联到新的账号上
一键创建一个OpenClaw 机器人：立即创建
告诉AI 你想创建一个怎样的新Agent，以及这个Agent 关联的飞书账号是什么，并将操作指南发给OpenClaw 请他自己完成对应配置。

六、OpenClaw飞书官方插件更新教程
插件能力实时更新，欢迎更新到插件最新版本体验最新能力
在「终端」中运行下面代码：
npx -y @larksuite/openclaw-lark-tools update

提示：👆如果执行这一行命令行出错，可在命令行前 增加sudo 重新执行
七、OpenClaw飞书官方插件安装常见问题
没有 OpenClaw 应该如何部署？
OpenClaw 是本次介绍的飞书插件的运行基础，请先选择符合自己需要的部署方案完成部署。
本地版建议使用 TRAE SOLO 等编程 Agent 辅助安装；
云端版如 Coze 编程、ArkClaw等可以一键部署，在后续使用中也可以提供开发Agent辅助你调试。

插件安装完毕运行后，报cannot find module xxx
原因是系统没有安装插件的依赖（可能是安装被中断or权限问题）
解决方法：进入插件安装目录，运行npm install

Coze上安装失败的处理方式
依次在终端执行以下命令，如果未能正常运行，请等待飞书插件和 Coze 的后续更新。
// 先执行
export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com

npx -y @larksuite/openclaw-lark-tools install

提示：👆如果执行这一行命令行出错，可在命令行前 增加sudo 重新执行检查一下老插件的配置，参考下图。如果为“true”需要改成“false”

升级到OpenClaw 3.2版本上无法正常调用工具
这个OpenClaw 版本默认把新 agent 的工具权限关闭。修复方式 在 openclaw.json 加上这段内容：
{
"tools": {
"profile": "full",
"sessions": {
"visibility": "all"
}
}
}
