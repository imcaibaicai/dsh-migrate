# Security & Privacy Policy (安全与隐私说明)

## 1. 核心安全承诺 (Our Security Commitment)
`dsh-migrate` 设计的核心初衷是**零数据上报、零外联请求、完全离线本地运行**。所有的备份压缩、文件解压、路径重映射与自检逻辑均在你的本地 Windows 系统由 PowerShell 执行。

## 2. 导出模式与敏感数据隔离 (Export Modes)

在执行 `export` 时，工具严格区分两种使用场景：

| 模式 | 参数 | 包含的内容 | 适用场景与安全警示 |
| :--- | :--- | :--- | :--- |
| **私有全量模式 (默认)** | `-Mode Private` | 包含所有明文 API Key (`.credentials.yaml`)、全部历史对话、会话向量数据库、自定义技能与魔改 `app.asar`。 | ⚠️ **仅用于个人私有迁移**（如内网拷贝、移动硬盘传到自己的新电脑）。**严禁将生成的 zip 包上传到 GitHub、Gitee 或公开网盘！** |
| **脱敏分享模式** | `-Mode Sanitize` | 自动剔除 `.credentials.yaml`、会话记录 (`sessions/`) 与向量库，仅打包通用规则 (`AGENTS.md`)、自定义扩展技能与插件配置。 | ✅ **适合社区交流、团队模板分发**。 |

## 3. 防泄漏保障 (Leak Prevention)
本项目根目录下的 `.gitignore` 已将所有可能的凭据扩展名（`*.credentials.yaml`、`*.key`）以及压缩包产物（`*.zip`）加入最高级别过滤。在向 Git 仓库提交代码时，这些文件会被强制忽略。

如果你发现了任何潜在的安全盲区或路径漏洞，欢迎提交 Issue 协助改进！
