# 🚀 dsh-migrate

> **DeepSeek Harness (DSH) 一键全量跨机迁移与环境备份工具**  
> *Seamless Cross-Machine Migration, Backup & Environment Cloning for DeepSeek Harness on Windows.*

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%2F11-0078D6.svg)]()
[![PowerShell: 5.1+|7+](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%207%2B-5391FE.svg)]()
[![Zero Dependency](https://img.shields.io/badge/Dependencies-Zero-brightgreen.svg)]()

[简体中文](#-为什么会有这个项目) | [English](#-why-dsh-migrate)

---

## 💡 为什么会有这个项目？

很多人刚换上了一台性能怪兽级的新电脑（比如 9950X3D + RTX 5090 这样的生产力工作站），满心欢喜准备大干一场。但当你打开旧电脑的 DeepSeek Harness 时，突然心头一凉：

- 过去几个月里积攒的几十个工作区与深度会话历史；
- 反复调优、凝聚了无数心血的全局规则与 Prompt 约束（`AGENTS.md`）；
- 自己魔改修复过的 `app.asar` 核心程序与手写的专属 `office-skills` 技能扩展；
- 还有那一堆已经配好的各种大模型 API Key 和离线语音模型……

如果你用官方安装包从零重装，上面的心血瞬间归零；  
如果你靠手工生硬地把文件夹拷过去，新电脑的 Windows 用户名一变、盘符一改，`workspace.json` 和会话缓存里的绝对路径全断了，打开满屏报错；甚至还会因为后台进程文件占用，连文件都覆盖不上。

**`dsh-migrate` 就是为了彻底终结这个痛点而生的**。零额外依赖、一个 PowerShell 脚本，在源电脑一键打包，在目标电脑一键无损落地并智能修复所有硬编码路径。

---

## ✨ 核心亮点

- ⚡ **零外部依赖**：纯 Windows 原生 PowerShell 实现（同时兼容系统自带的 5.1 与最新的 PowerShell 7），新电脑完全空白也能直接跑。
- 🧬 **100% 完整继承**：主程序魔改（`app.asar`）、自定义技能扩展（`office-skills`）、数据中枢（`~/.dsh`）、API 凭证与桌面偏好全部无损接管。
- 🗺️ **智能路径重映射**：自动检测旧主机的用户路径（例如 `C:\Users\OldUser`）并自动替换为新主机的对应路径，`workspace.json` 与会话缓存开箱即活。
- 🛡️ **严格的隐私与安全分级**：
  - **私有全量模式 (`Private`)**：自用迁移，包含密钥与会话（带强警告，防误传）。
  - **脱敏分享模式 (`Sanitize`)**：社区分享模板，自动剥离 API 密钥与私有对话，仅保留技能、规则与配置。
- 🤖 **Agent 友好生态**：自带原生 DSH 技能（`SKILL.md`）和一份专门写给新电脑 Agent 的《无脑盲操任务手册》，甚至可以让目标电脑里的 AI 替你全自动完成环境恢复。

---

## 🚦 三分钟快速上手

### 第一步：在旧电脑上（打包导出）

以普通用户或管理员身份打开 PowerShell，执行：

```powershell
# 1. 导出私有全量迁移包（包含会话与凭据，适合个人换电脑）
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 export -BundlePath D:\DSH_Backup.zip

# 或者：导出用于公开分享给朋友的脱敏纯净配置包（不含密钥和聊天记录）
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 export -Mode Sanitize -BundlePath .\dsh-template.zip
```

打包完成后，把生成的 `.zip` 压缩包（通过移动硬盘、局域网共享或内网传输）复制到你的新电脑上。

### 第二步：在新电脑上（解压与一键还原）

在新电脑上解压压缩包，打开 PowerShell 运行：

```powershell
# 一键还原：自动关闭冲突进程、安装底座、覆盖核心、重映射工作区路径
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 restore -BundlePath .\DSH_Backup.zip -Force
```

### 第三步：健康检查

运行内置的体检命令，确认一切就绪：

```powershell
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 doctor
```

启动 DeepSeek Harness，你所有熟悉的会话、技能、规则和工作区已经原封不动地回来了！🎉

---

## 📖 CLI 命令行参数说明

```text
USAGE:
    powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 <Command> [Options]

COMMANDS:
    export      打包源电脑的 DSH 程序魔改、.dsh 数据中枢及偏好设置
    restore     解包并还原到当前新电脑，自动执行路径智能重映射
    doctor      快速体检本地 DSH 运行环境与 Web GUI 端口状态
    help        显示帮助信息

OPTIONS:
    -BundlePath <path>       指定压缩包输出或输入路径（默认: .\dsh-bundle.zip）
    -Mode <Private|Sanitize> 导出安全模式：
                             - Private (默认): 全量备份，含密钥与聊天（严禁上传到公开仓库）
                             - Sanitize: 脱敏模板，剔除 API Key 与私密会话
    -DryRun                  预演/模拟运行，不实际写磁盘
    -Force                   自动关闭冲突进程，跳过确认提示
```

---

## 🤖 让新电脑的 AI Agent 替你盲操

本项目在 `docs/AGENT_HANDBOOK.md` 中准备了一套专门面向 AI Agent（如 Claude、GPT-4o、DeepSeek 等驱动的代码助手）的任务型约束提示词。  
把迁移包和手册扔给新电脑上的 Agent，它就能根据约束自检、处理互斥进程、调用还原引擎并闭环验收端口服务，全程不需要你亲自动手。

---

<br>

---

## 🌐 English Documentation

## 💡 Why dsh-migrate?

You just set up a brand-new, high-performance workstation (perhaps a beast like a 9950X3D with an RTX 5090). But as you look at your old machine's DeepSeek Harness, migration feels daunting:

- Months of historical conversation sessions and vector search indexes.
- Finely crafted system prompts and behavioral rules in `AGENTS.md`.
- Manually patched `app.asar` core routines and custom `office-skills`.
- Configured API keys across multiple LLM providers.

Reinstalling from scratch wipes out all your customization. Manually copying folders across machines breaks hardcoded workspace paths in `workspace.json` (due to different Windows usernames or drive letters) and causes file-lock collisions.

**`dsh-migrate` was built to solve this completely.** With a zero-dependency PowerShell engine, it exports your exact state on the source machine and seamlessly restores it on your target machine, auto-remapping paths along the way.

---

## ✨ Features

- **Zero External Dependencies**: Works out-of-the-box on Windows 10/11 with native PowerShell 5.1 and PowerShell 7+.
- **Complete Environment Cloning**: Transplants core mods (`app.asar`), custom runtime skills, user brain (`~/.dsh`), credentials, and desktop preferences.
- **Intelligent Path Remapping**: Automatically scans and converts old filesystem paths (e.g. `C:\Users\OldUser\...`) to the new host's `$env:USERPROFILE`.
- **Privacy & Security Control**:
  - `Private` Mode: Complete local backup with credentials and chats (heavily guarded against accidental sharing).
  - `Sanitize` Mode: Clean template stripping private keys and chats for community sharing.
- **Agent Handover Specification**: Includes `docs/AGENT_HANDBOOK.md` for hands-off deployment by AI agents on target workstations.

---

## ⚡ Quick Start

### 1. On Source Machine (Export)

```powershell
# Full private backup for personal migration:
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 export -BundlePath D:\DSH_Backup.zip

# Or clean sanitized template for sharing:
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 export -Mode Sanitize -BundlePath .\dsh-template.zip
```

### 2. On Target Machine (Restore)

```powershell
# One-command restoration:
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 restore -BundlePath .\DSH_Backup.zip -Force
```

### 3. Verify Health

```powershell
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 doctor
```

Launch DeepSeek Harness, and pick up right where you left off. 🚀

---

## 🔒 Security & Privacy Notice

> [!WARNING]
> Bundles exported in `Private` mode contain plaintext API keys stored in `.credentials.yaml` and confidential session records. **NEVER push private bundles to GitHub, Gitee, or public file shares.** The included `.gitignore` protects against accidental commits.

---

## 📄 License

Distributed under the [MIT License](LICENSE).
