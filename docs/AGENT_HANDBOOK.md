# DeepSeek Harness 全量系统迁移与环境还原任务规范（面向新电脑端 Agent）

## 1. 任务背景与最高目标
你正在一台高性能 Windows AI 工作站（如 9950X3D + 5090）上执行 DeepSeek Harness 的全量环境接管任务。
你的任务是将提供的迁移资源包完全部署到当前宿主机中，必须达到以下绝对状态：
1. 完整保留源主机的官方注册表/快捷方式环境；
2. 100% 保留源主机对主程序核心所做的非插件化魔改（包括修改版 `app.asar` 和自定义 `office-skills` 技能）；
3. 完整继承全部历史会话、API 凭证、账号体系、离线运行时依赖与生态补丁；
4. 自动感知当前机器的用户名、路径与盘符，完成工作区绝对路径的自适应重映射，实现开箱即用。

---

## 2. 迁移资源包目录结构约定
假定迁移资源包已被解压至某临时工作目录（记为 `$BUNDLE_DIR`），其内容结构如下：
- `$BUNDLE_DIR/installer.exe`：官方安装包
- `$BUNDLE_DIR/ProgramFiles_DSH/`：已修改的核心程序全量目录（含 `resources/app.asar`）
- `$BUNDLE_DIR/DotDsh/`：源端完整 `.dsh` 用户数据中枢
- `$BUNDLE_DIR/bundle-manifest.json`：源机元数据与导出模式配置
- `$BUNDLE_DIR/AppData_Roaming/settings.json`（可选）：界面配置

---

## 3. 执行阶段与核心约束（Execution Phases & Constraints）

### 阶段一：宿主机环境探测与路径规划
1. **环境探测**：
   - 获取当前宿主机用户信息：`$env:USERPROFILE`、`$env:USERNAME`。
   - 确定用户配置目录位置：`$TARGET_DSH_HOME = Join-Path $env:USERPROFILE ".dsh"`。
2. **进程互斥检查**：
   - 执行前必须检查并终止任何现存的 DeepSeek Harness 进程，避免文件锁冲突：
     ```powershell
     Get-Process -Name "*DeepSeek*", "*dsh*" -ErrorAction SilentlyContinue | Stop-Process -Force
     ```

### 阶段二：自动化还原执行（推荐单行驱动）
直接调用随迁移包附带的自动化迁移引擎：
```powershell
powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 restore -BundlePath .\dsh-bundle.zip -Force
```

### 阶段三：关键文件还原与路径重映射核对
若执行自定义路径调整，确保以下关键存储文件已完成新机用户路径替换：
- `$TARGET_DSH_HOME\storages\workspace.json`（工作区列表）
- `$TARGET_DSH_HOME\storages\session_projcache\sessions\*.json`（会话工作区缓存映射）
- `$TARGET_DSH_HOME\profiles\desktop\cordis.patch.yml`（插件输出目录配置）
- `$TARGET_DSH_HOME\profiles\web\cordis.patch.yml`

---

## 4. 验收标准与自检门禁（Verification & Acceptance Criteria）

在宣布任务完成前，你必须逐一自检并通过以下指标：
- [ ] **核心完整性**：安装目录下 `resources\app.asar` 与自定义 skills 目录存在且非空。
- [ ] **凭据与规则**：`$TARGET_DSH_HOME\.credentials.yaml` 和 `$TARGET_DSH_HOME\AGENTS.md` 存在且完整。
- [ ] **路径有效性**：`workspace.json` 中定义的工作区路径在当前文件系统上真实存在（`Test-Path` 返回 True），无残留无效旧路径。
- [ ] **进程与服务验证**：
  - 启动 DeepSeek Harness 应用。
  - 运行 `powershell -ExecutionPolicy Bypass -File .\dsh-migrate.ps1 doctor` 确保全绿。
  - 验证本地 Web GUI 服务端口（默认 `127.0.0.1:19387`）能够正常监听并响应 HTTP 请求：
    ```powershell
    (Invoke-WebRequest -Uri "http://127.0.0.1:19387" -UseBasicParsing -TimeoutSec 10).StatusCode -eq 200
    ```
