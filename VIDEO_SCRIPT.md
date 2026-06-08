# Demo 视频脚本 — Pharos DeFi Skill

**时长**: 2分30秒 | **语言**: 英文 | **形式**: 屏幕录制 + 画外音

---

## 拍摄准备

### 环境设置
1. VS Code 打开 `C:\Users\xiaox\Desktop\pharos-defi-skill`
2. 主题：浅色（Light+）
3. 终端字体：16pt
4. 关闭通知、关闭其他窗口
5. 提前打开两个终端 tab：
   - Tab 1: 项目根目录
   - Tab 2: 提前 `cat SKILL.md` 看一遍预热

### 录制工具
- Windows 自带：`Win + Alt + R`（Xbox Game Bar）
- 或 [OBS Studio](https://obsproject.com/)（免费，画质更好）
- 或 [Loom](https://loom.com/)（在线，免安装）

---

## 精炼脚本

### 段 1 — 开场 (0:00 – 0:20)
> 画面：仓库 README 全屏

"Hi, I''m building **pharos-defi** — a DeFi operations Skill for the Pharos AI Agent Carnival.

Pharos has one official skill for basic chain operations. But there''s no DeFi layer. That''s the gap I''m filling."

> 滚动 README 到 Capabilities 表格

"10 capabilities. 5 scripts. Agent-ready."

---

### 段 2 — 结构 (0:20 – 0:45)
> 画面：VS Code 侧边栏，逐层展开

"Same format as the official Skill Engine. SKILL.md — the agent entry point. assets — network config, contract registry, token list. 8 reference files covering every DeFi operation. 5 executable scripts that automate the full workflow. Plus AGENT_PROMPTS and an Anvita Flow integration guide for Phase 2."

> 高亮文件数：底部状态栏 21 files

---

### 段 3 — 脚本演示 (0:45 – 1:40)
> 切换到终端 Tab 1

**discover.sh (15s)**
```bash
./scripts/discover.sh atlantic-testnet
```
> 运行，展示输出

"Contract discovery — Permit2 confirmed deployed on Pharos testnet."

**portfolio.sh (15s)**
```bash
./scripts/portfolio.sh atlantic-testnet
```
> 运行

"One command. Native balance, all tokens, auto-discovered LP positions."

**swap.sh (15s)**
> 只展示帮助信息，不实际执行
```bash
./scripts/swap.sh
```
> 展示参数说明

"Swap handles the full lifecycle — token resolution, quote, slippage, allowance, execution, post-swap verification. One command."

**dca.sh (10s)**
```bash
./scripts/dca.sh --help
```

"DCA — dollar cost averaging with scheduling. Setup, execute, status tracking."

**yield.sh (10s)**
```bash
./scripts/yield.sh atlantic-testnet
```
> 展示池扫描 + IL 风险表

"Yield analysis. Pool scanning, risk grading, impermanent loss reference."

---

### 段 4 — Agent 集成 (1:40 – 2:05)
> 切回 VS Code，打开 AGENT_PROMPTS.md

"This is what makes it a **Skill**, not just a tool. AGENT_PROMPTS.md has 15 real scenarios showing how an AI agent reads this skill and executes DeFi operations autonomously."

> 滚动展示几个 prompt 示例

"User says 'Swap 10 PHRS for USDC' — the agent resolves tokens, checks pairs, gets quotes, executes, reports. All from instructions in this skill."

> 打开 references/anvita-integration.md

"And for Phase 2, the Anvita integration guide shows exactly how to compose pharos-defi with pharos-skill-engine into a fully autonomous DeFi agent. Architecture diagram, deployment checklist, prompt examples — ready to go."

---

### 段 5 — 收尾 (2:05 – 2:30)
> 切回 README

"Summary: 10 DeFi capabilities. 5 executable scripts. Full agent integration. Anvita Flow ready. All following Pharos skill standards.

**pharos-defi** — filling the DeFi gap in the Pharos AI Agent ecosystem. Thanks for watching."

---

## 录制清单

| # | 画面 | 操作 | 时长 |
|---|------|------|------|
| 1 | README | 开场旁白 | 20s |
| 2 | VS Code 侧边栏 | 展开目录 | 25s |
| 3 | 终端 | `./scripts/discover.sh` | 15s |
| 4 | 终端 | `./scripts/portfolio.sh` | 15s |
| 5 | 终端 | `./scripts/swap.sh` (help) | 15s |
| 6 | 终端 | `./scripts/dca.sh --help` | 10s |
| 7 | 终端 | `./scripts/yield.sh` | 10s |
| 8 | VS Code | AGENT_PROMPTS.md | 25s |
| 9 | VS Code | anvita-integration.md | 10s |
| 10 | README | 总结 | 25s |

---

## 提词卡（录屏时读）

```
段1: Hi, I'm building pharos-defi — a DeFi operations Skill for the Pharos AI Agent Carnival. Pharos has one official skill for basic chain operations. But there's no DeFi layer. That's the gap I'm filling. 10 capabilities. 5 scripts. Agent-ready.

段2: Same format as the official Skill Engine. SKILL.md — the agent entry point. assets — network config, contract registry, token list. 8 reference files covering every DeFi operation. 5 executable scripts. Plus AGENT_PROMPTS and Anvita Flow integration for Phase 2.

段3: Contract discovery — Permit2 confirmed. Portfolio — one command shows everything. Swap — full lifecycle automation. DCA — dollar cost averaging with scheduling. Yield — pool scanning with risk analysis.

段4: This is what makes it a Skill. AGENT_PROMPTS has 15 real scenarios showing how an AI agent reads this skill and executes DeFi operations autonomously. And for Phase 2 — complete Anvita Flow integration guide. Architecture, deployment, prompts — ready.

段5: 10 DeFi capabilities. 5 executable scripts. Full agent integration. Anvita Flow ready. pharos-defi — filling the DeFi gap in the Pharos AI Agent ecosystem. Thanks for watching.
```
