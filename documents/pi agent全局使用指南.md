# Pi Agent 全局使用指南

> Pi 是全局 CLI 终端编码 Agent：装一次、配一次，任意目录直接使用。
> 本文档覆盖：快速上手、上下文管理、历史对话持久化、Skills 扩展、MCP 现状与替代。
> 源码依据（`main` 分支）：`package-manager.ts`、`harness/skills.ts`、`session-manager.ts`、`settings-manager.ts`、`model-resolver.ts`。

---

## 1. 快速上手（全局安装）

```bash
# 1. 全局安装发布版（一次）
npm install -g --ignore-scripts @earendil-works/pi-coding-agent

# 2. 配置认证（一次，所有项目通用）
export DEEPSEEK_API_KEY=sk-...      # 或 /login 订阅登录；建议写入 ~/.zshrc
# 注意：改完 ~/.zshrc 后必须【重开终端】才生效（source 不会清除旧环境变量）

# 3. 进入任意项目直接使用
cd 你的项目 && pi
```

关键机制：

- **认证与会话全局**（`~/.pi/agent/`），但会话按项目目录自动隔离；
- **模型选择五级优先级**（`model-resolver.ts:613`）：CLI 参数 → `--models` → 会话恢复 → settings 的 `defaultProvider/defaultModel`（需已认证）→ 内置默认表遍历（anthropic 排 deepseek 前）；
- **固化默认模型**（避免被残留环境变量干扰，任何目录生效）：
  ```json
  // ~/.pi/agent/settings.json
  { "defaultProvider": "deepseek", "defaultModel": "deepseek-v4-flash" }
  ```
- 发布版（npm 包，版本固定）与源码启动（`./pi-test.sh`，跟随 main 分支）互不干扰。

---

## 2. 上下文管理（Compaction）

**机制**：长对话自动触发 **compaction（上下文压缩）**——把早期对话摘要成小结，腾出上下文窗口，避免 token 溢出。实现：`packages/agent/src/harness/compaction/`、`packages/coding-agent/src/core/compaction/`。

**配置**（`settings-manager.ts` 的 `CompactionSettings`，默认值如下）：

```jsonc
// settings.json（全局或项目级）
{
  "compaction": {
    "enabled": true,          // 默认 true，开启自动压缩
    "reserveTokens": 16384,   // 为提示词+响应预留的 token
    "keepRecentTokens": 20000 // 保留最近对话的 token 数
  }
}
```

要点：

- 压缩只影响**发给模型**的内容，**不删除会话记录**（完整历史仍在 JSONL 里可回溯）；
- 可在会话内手动触发压缩（相关扩展/命令，如 `trigger-compact.ts` 示例）；
- 不同模型 context window 不同，模型目录里已内置（如 deepseek-v4-flash 为 1M token）。

---

## 3. 历史对话记录管理（持久化）

**存储**：append-only JSONL，路径 `~/.pi/agent/sessions/<编码的目录路径>/<时间戳>_<会话ID>.jsonl`（`session-manager.ts:845`："append-only trees stored in JSONL files"）。

**核心能力**：

| 能力 | 说明 |
|------|------|
| 按目录隔离 | 不同项目会话互不串扰，同目录历史全部保留 |
| 自动记录 | 每条消息/工具调用/压缩事件追加落盘 |
| 会话分支（fork） | 可从历史会话分叉出新会话 |
| 恢复 | 见下表 |

**恢复方式**（`main.ts:417-448`）：

| 命令 | 行为 |
|------|------|
| `pi --continue`（`-c`） | 直接继续**最近**会话（`continueRecent`） |
| `pi --resume`（`-r`） | 弹选择器，从当前目录/全部历史**挑选**会话恢复 |
| `pi --session <id>` | 按会话 ID 精确恢复 |
| 不带参数 | 默认开**新会话**（历史不丢，用上面命令找回） |

---

## 4. Skills 扩展（原生支持）

Skills = **带说明的指令包**（Markdown + YAML frontmatter），模型按描述自主调用。

**格式**（`agent/src/harness/skills.ts:138`）：

```markdown
---
name: my-skill
description: 做什么用的说明（模型据此触发）
# 可选：disable-model-invocation: true（只作为 /skill:name 命令，不让模型自动调）
---
正文：步骤说明
```

**三种安装方式**：

| 方式 | 做法 |
|------|------|
| A. 目录自动发现 | 放入 `~/.pi/agent/skills/`（全局）、`~/.agents/skills/`（Claude Code 兼容）、`<项目>/.pi/skills/` 或 `<项目>/.agents/skills/`（项目级） |
| B. settings 指定路径 | `{ "skills": ["~/my-skills/xxx", "/abs/path.md"] }` |
| C. Pi Packages | `{ "packages": ["npm包或git仓库"] }` 分发（含 skills/extensions/prompts/themes） |

**使用**：启动即加载；模型可自主调用（看 description），也注册 `/skill:<name>` 命令（`enableSkillCommands` 默认 true）；新增/修改后重启生效。

本项目自带示例：`.pi/skills/add-llm-provider.md`（给 packages/ai 加供应商的检查清单）。

---

## 5. MCP：现状与替代方案

**现状：官方不支持（设计使然）。** README Philosophy 明确 "No MCP"；全仓代码无 MCP 实现（搜索 `mcp` 仅出现在 Anthropic OAuth scope 里）。作者有专文：*What if you don't need MCP*。

**替代方案**：

| 方案 | 做法 | 适用 |
|------|------|------|
| Skills 化（推荐） | 把服务封装成 CLI 工具 + README，写成 skill | 有 CLI/HTTP 接口的取数/操作 |
| 扩展自建 MCP | TypeScript 扩展里实现 MCP client/server，挂到工具层 | 已有 MCP 生态、复杂双向交互 |
| 等生态 | 关注第三方 Pi Packages 是否提供 MCP 扩展 | 不想自己写 |

扩展开发起点：`packages/coding-agent/examples/extensions/`（`tools.ts`、`dynamic-tools.ts`）。

---

## 6. 配置速查

| 配置 | 位置 |
|------|------|
| 默认模型 | `settings.json`：`defaultProvider` + `defaultModel` + `enabledModels` |
| 上下文压缩 | `settings.json`：`compaction.{enabled,reserveTokens,keepRecentTokens}` |
| 模型目录缓存 | `~/.pi/agent/models-store.json`（ETag 增量自动刷新） |
| 认证凭证 | `~/.pi/agent/auth.json`（`/login` 写入）或环境变量 |
| 全局扩展资源 | `~/.pi/agent/{skills,prompts,themes,extensions}/` |
| 项目级扩展资源 | `<项目>/.pi/{skills,prompts,themes,extensions}/`（项目优先） |

---

*本文档整合自仓库源码分析，路径与行号为分析时 `main` 分支状态。*
