---
name: dsh-migrate
description: DeepSeek Harness (DSH) 一键全量环境迁移与备份技能。当用户要求"将当前 DSH 环境打包迁移到新电脑"、"备份 DSH 全部会话与凭据"、"在新电脑上还原部署 DSH"或排查环境配置时调用。通过无额外依赖的 PowerShell 引擎，自动探测本地程序核心魔改（app.asar 与 office-skills）、用户数据中枢（.dsh）、API 凭据、会话历史与工作区，支持敏感数据脱敏导出、路径智能重映射与服务自检。
---

# DeepSeek Harness 环境迁移与备份技能 (dsh-migrate)

## 技能定位
本技能用于驱动底层 `dsh-migrate.ps1` 脚本，在 Windows 环境下实现 DeepSeek Harness 的无损跨机迁移、快速备份与环境健康诊断。

## 工作流与执行策略

### 场景 1：源主机导出迁移包（Export）
当用户要求备份当前环境或准备迁往新电脑时：

1. **向用户确认导出模式**：
   - **私有全量模式（默认）**：包含所有 API 凭据、聊天记录、魔改核心。适合个人迁往私有生产力电脑。
   - **脱敏分享模式 (`-Mode Sanitize`)**：自动剥离 `.credentials.yaml` 和历史对话记录，仅保留自定义技能、提示词规则与环境配置。适合社区分享。
2. **执行导出命令**：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 export -BundlePath D:\DSH_Migration_Bundle.zip
   ```
3. **安全提醒**：
   若使用私有模式导出，必须在完成汇报时重点提示用户：**切勿将生成的 zip 包上传到 GitHub 或公开网络**。

### 场景 2：目标主机还原部署（Restore）
当用户在新电脑上解压了迁移包，需要落地还原时：

1. **探测目标机环境并执行还原**：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 restore -BundlePath .\dsh-bundle.zip -Force
   ```
2. **检查路径重映射结果**：
   脚本会自动将旧电脑路径（包括用户名与盘符）智能重映射为当前新电脑的 `$env:USERPROFILE`。
3. **健康检查与验收**：
   运行环境体检：
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 doctor
   ```
   验证 DSH Web GUI 服务端口 `127.0.0.1:19387` 是否正常响应。
