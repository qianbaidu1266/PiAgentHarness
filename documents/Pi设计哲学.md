# Pi 设计哲学：最小内核，激进可扩展

> 本文档基于 `packages/coding-agent/README.md` 的 Philosophy 章节、源码结构与社区讨论整理，
> 旨在回答三个问题：Pi 为什么这样做、它拒绝了什么、以及怎么理解这种取舍。

---

## 1. 一句话哲学

**Pi 是 aggressively extensible（激进可扩展）的：它不替你做决定，让你塑形 Pi，而不是让 Pi 塑形你。**

核心是"**最小特权内核 + 生态装配**"：

- 内核只给模型 4 个工具：`read` / `write` / `edit` / `bash`；
- 其他一切能力（plan mode、sub-agent、权限确认、MCP、todo……）**默认不内置**；
- 需要什么，用扩展装什么：**Skills / Extensions / Prompt Templates / Themes / Pi Packages** 五类扩展机制，全部 TypeScript，无需 fork 仓库。

## 2. 官方"六不内置"清单

Pi 明确拒绝六个"主流 agent 标配"功能，并为每个提供了替代方案（这是设计哲学最直接的体现）：

| 不内置 | 官方理由 | 替代方案 |
|--------|----------|----------|
| **MCP** | 见作者文章 *What if you don't need MCP* | 用 Skills（带 README 的 CLI 工具），或用扩展自行加 MCP |
| **Sub-agents** | 实现方式太多，不应由内核定死 | tmux 起多个 pi 实例，或扩展自建 |
| **权限弹窗** | 安全模型应与环境/需求匹配 | 容器/沙箱隔离，或扩展自建确认流程 |
| **Plan mode** | 计划是内容不是模式 | 把计划写进文件 |
| **内置 todo** | "todo 会误导模型" | 用 TODO.md 文件 |
| **后台 bash** | 要完全可观测、可交互 | 用 tmux |

配套工程理念：`--ignore-scripts` 安装、依赖精确钉死、lockfile 唯一事实源、供应链审计——内核必须"小到可以信任"。

## 3. 设计决策背后的逻辑

### 3.1 为什么要拒绝内建功能

- **功能膨胀绑架工作流**：主流 coding agent 不断内置新功能，用户的习惯被迫跟随工具升级而改变；Pi 认为工具应当适应人，而非人适应工具。
- **"内置"即"定死"**：一旦内建 sub-agent 或 MCP，就锁定了实现方式。而这类能力的需求千差万别，内核不应该替用户选择。
- **最小可审计**：极简内核意味着每一行核心代码都可被审查、可被信任，供应链安全才有意义。

### 3.2 为什么是"扩展"而不是"插件市场"

Pi 的扩展本质是**代码与约定**（TypeScript 扩展 + 目录约定），而非封闭的插件 ABI：

- Skills = 带 README 的 CLI 工具，模型按说明调用；
- Extensions = 在 hooks（`BeforeToolCall` / `AfterToolCall` / `PrepareNextTurn` 等）上挂 TypeScript 代码；
- Pi Packages = 把扩展打包通过 npm/git 分发。

这让扩展的边界跟随真实需求生长，而不是被框架预设的"插件形态"约束。

### 3.3 内核仍然有特权

与"一切皆插件"的激进路线不同，Pi 保留了一个**特权内核**：agent loop、工具执行、会话/压缩、事件流在 `packages/agent` 中是第一公民，扩展挂接在内核之上而非替代内核。这是 Pi 与 DeepSeek Harness（无特权核心、全部可替换）的本质区别。

## 4. 与主流路线的对比

| 路线 | 代表 | 赌注 |
|------|------|------|
| 大而全 | Claude Code / Codex | 开箱即用，内置一切，用户按工具的习惯工作 |
| 最小内核 + 扩展 | **Pi** | 内核特权、生态补全，面向重度定制用户 |
| 一切皆插件 | DeepSeek Harness (v0.1) | 连内核都可替换，比 Pi 更激进一层 |

Pi 的取舍是明确的：**它不为"大多数人的默认体验"优化，而为"少数人的深度定制"优化。**

## 5. 与 DeepSeek Harness（DSH）的区别

DeepSeek Harness（2026-08-13 发布 v0.1 开发者预览版，MIT）是同一物种（agent harness），但路线比 Pi 更激进。核心差异：

### 5.1 哲学差异：内核特权 vs 无特权核心

- **Pi**：保留一个**特权内核**（agent loop、工具执行、会话/压缩、事件流是第一公民），扩展挂接在内核之上，不替代内核；
- **DSH**：**"Everything is a plugin"（一切皆插件）**——模型、工具、技能、会话、沙箱、文件系统、agent loop、调度、UI **全部**是插件，默认部署 159 个插件，可单独开关、自由替换。Pi 的内核在 DSH 里也只是"默认插件"之一。

### 5.2 插件底座

- **Pi**：自研扩展机制（TypeScript hooks + 目录约定 + Pi Packages），无插件运行时依赖；
- **DSH**：基于 **Cordis** 插件系统（Koishi 聊天机器人生态已运行 4 年，并配套北大论文给出数学基础）。插件通过稳定 context key 暴露服务（`ctx.sessions` / `ctx.tools` / `ctx.llm` 等），换一个 provider 实现即可全局生效。

### 5.3 形态与 UI

| 维度 | Pi | DSH |
|------|-----|-----|
| UI | 终端 TUI（无 Web） | **Web UI**：`npx @deepseek-ai/dsh web` → http://127.0.0.1:3080；另有 headless 模式 |
| 运行模式 | 4 种：TUI / Print-JSON / RPC / SDK | 4 种：标准 / PTC（模型写代码组合工具调用）/ 极简（仅 shell+edit，用于模型评测）/ 创造（内存中试验插件） |
| 可追溯性 | 会话 + compaction 压缩 | **Trajectory 视图**：append-only 事件日志，模型看到的一切（提示词/思维链/工具调用/子 agent 调度）可恢复、分叉、检索、回放 |
| 分发 | npm 包 / 源码 | npm（`npx` 即用）/ GitHub |
| 背景 | 社区个人项目（Mario Zechner，libGDX 作者） | **DeepSeek 官方**，模型厂商下场，对标 Claude Code/Codex |
| 成熟度 | 已迭代 v0.84，生产可用 | v0.1 预览版，官方明示将有破坏性变更；发布即 72.6k stars |

### 5.4 一句话概括差异

- **Pi** 说："内核很小，且是特权层；扩展补全其余"；
- **DSH** 说："**没有特权核心，连内核本身都是插件**"；
- 共同的敌人是同一批"大而全"工具（Claude Code 等），但 Pi 走"极简+生态"，DSH 走"全插件化+官方背书"，DSH 是 Pi 理念在"更激进方向"上的延伸。

## 6. 如何理解（精髓速览）

1. 记住"六不内置"清单——每条都是一种立场；
2. 看 `packages/agent/src/agent-loop.ts`（内核循环）和 `packages/coding-agent/src/core/extensions/`（扩展机制），理解"内核小、接口稳定"；
3. 实际跑一次：`./run-pi.sh`，试 `/model`、`!` bash 命令，体会"够用但克制"；
4. 读作者博客（README Philosophy 章节末尾链接）了解完整论证。

## 7. 客观评价：精简的代价

- **收益**：不绑架工作流、可 hack、可审计、升级不破坏习惯；
- **代价**：新手开箱体验差，sub-agent/plan 等能力需要自己装配；生态决定上限——没有社区扩展，精简就退化为简陋；
- **结论**：精简不是"更好"，而是一种**有意识的取舍**，赌的是"开发者的定制需求 > 开箱即用"。

---

*Pi 是 earendil-works 的开源项目（MIT），作者 Mario Zechner（libGDX 作者）。*
