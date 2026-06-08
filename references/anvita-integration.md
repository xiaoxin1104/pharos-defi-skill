# Anvita Flow Integration

How to convert `pharos-defi` Skill into a fully autonomous Agent using Anvita Flow.

---

## What is Anvita Flow?

Anvita Flow is Pharos''s one-click Skill-to-Agent conversion tool. It takes a Skill (like this one) and wraps it into an autonomous Agent that can:

- Execute DeFi operations autonomously on Pharos
- Respond to natural language commands from users
- Run scheduled tasks (DCA, yield harvesting)
- Compose with other Skills into multi-capability Agents

Anvita Flow is the deployment infrastructure for **Phase 2 (Agent Arena)** of the hackathon.

---

## How pharos-defi Fits the Anvita Flow Model

This Skill follows the standard Pharos Skill specification, making it directly compatible with Anvita Flow:

```
pharos-defi (Skill)
    │
    │  Anvita Flow: one-click conversion
    ▼
pharos-defi-agent (Agent)
    │
    ├── Reads SKILL.md for capability matching
    ├── Executes scripts/ for automated operations
    ├── Resolves assets/ for contract configuration
    └── Follows references/ for detailed operation instructions
```

---

## Agent Composition (Phase 2)

For Phase 2, combine `pharos-defi` with `pharos-skill-engine` to create a complete DeFi Agent:

### Architecture

```
┌─────────────────────────────────────────────┐
│            Pharos DeFi Agent                │
│                                             │
│  ┌──────────────┐    ┌──────────────────┐   │
│  │ pharos-skill │    │   pharos-defi    │   │
│  │   -engine    │    │                  │   │
│  │              │    │  ├── swap        │   │
│  │  ├─ balance  │◄──►│  ├── liquidity   │   │
│  │  ├─ tx       │    │  ├── quote       │   │
│  │  ├─ contract │    │  ├── routing     │   │
│  │  └─ network  │    │  ├── portfolio   │   │
│  └──────────────┘    │  ├── dca         │   │
│                       │  └── yield       │   │
│                       └──────────────────┘   │
│                                             │
│  User: "Swap 10 PHRS for USDC"              │
│     → pharos-skill-engine: balance check    │
│     → pharos-defi: get quote, execute swap  │
│     → pharos-skill-engine: verify tx        │
│     → pharos-defi: report PnL               │
└─────────────────────────────────────────────┘
```

### Agent Prompt Example

When this Skill is loaded into an Anvita Flow Agent, the end user interacts naturally:

```
User: "Buy $100 worth of USDC every Monday using PHRS"

Agent (via pharos-defi):
  1. Loads references/dca.md
  2. Checks balance (via pharos-skill-engine)
  3. Creates DCA config with ./scripts/dca.sh --setup
  4. Reports: "DCA configured: 100 USDC/week. First buy scheduled for next Monday."

User: "How''s my portfolio doing?"

Agent (via pharos-defi):
  1. Runs ./scripts/portfolio.sh
  2. Discovers LP positions
  3. Reports: "Portfolio value: ~$21,085. PHRS/USDC LP: 3.45% share. 
               DCA: 3/12 buys complete. Avg entry: 9.5 USDC/PHRS."
```

---

## Skill-to-Agent Conversion Checklist

For Phase 2 submission, ensure your Skill is Agent-ready:

| Requirement | pharos-defi Status | Notes |
|-------------|-------------------|-------|
| SKILL.md with YAML frontmatter | ✅ Done | name/description/version/requires |
| Capability index table | ✅ Done | 8 capabilities mapped to references |
| Clear operation references | ✅ Done | 7 reference files with step-by-step commands |
| Executable scripts | ✅ Done | swap.sh, portfolio.sh, dca.sh, yield.sh |
| Error handling documentation | ✅ Done | Per-operation error tables + recovery |
| Security pre-checks | ✅ Done | Allowance, slippage, deadline, network confirm |
| Agent prompt examples | ✅ Done | AGENT_PROMPTS.md with 15+ scenarios |
| Compatible with pharos-skill-engine | ✅ Done | Same toolchain (cast/forge), same config format |

---

## Anvita Flow Deployment Steps

### Prerequisites

1. Completed Phase 1 (Skill Hackathon) — this Skill
2. Access to Anvita Flow (provided to Phase 1 winners)
3. `pharos-skill-engine` installed alongside `pharos-defi`

### Deployment Flow

```
Step 1: Package Skill
  └── Ensure all files are in a GitHub repo
  └── Verify: npx skills add https://github.com/yourname/pharos-defi-skill

Step 2: Load into Anvita Flow
  └── Open Anvita Flow dashboard
  └── "Create Agent" → "Import Skill"
  └── Paste: https://github.com/yourname/pharos-defi-skill

Step 3: Compose with other Skills
  └── Add pharos-skill-engine as dependency
  └── Configure network preference (testnet/mainnet)
  └── Set private key (or connect wallet)

Step 4: Deploy Agent
  └── One-click deploy to Pharos
  └── Agent is now live and can serve users 24/7
  └── Users interact via natural language
```

### Expected Phase 2 Capabilities

With `pharos-defi` + `pharos-skill-engine` composed into an Anvita Flow Agent:

| User Command | Agent Behavior |
|-------------|----------------|
| "Swap 10 PHRS for USDC" | Quote → check balance → execute → report |
| "Add liquidity to PHRS/USDC" | Check allowances → calculate ratio → add LP → report share |
| "Show my portfolio" | Native balance → token balances → LP positions → summary |
| "Start DCA: 10 PHRS weekly" | Create DCA config → schedule cron → report |
| "Which pool is best for yield?" | Scan pools → assess risk → rank by risk-adjusted yield |
| "Check my PHRS/USDC LP position" | Get pair → query LP balance → calculate share → report IL |

---

## Notes for Hackathon Judging

- **Phase 1**: This Skill demonstrates readiness for Agent conversion with complete Anvita Flow compatibility
- **Phase 2**: Once deployed via Anvita Flow, this Skill becomes an autonomous DeFi Agent serving on-chain users
- **Key differentiator**: Unlike simple Skills, `pharos-defi` includes executable scripts and pre-built safety checks that make Agent conversion seamless
