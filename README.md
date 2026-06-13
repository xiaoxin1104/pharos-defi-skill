# Pharos DeFi Skill

A comprehensive DeFi operations Skill for the [Pharos](https://www.pharos.xyz/) blockchain ? part of the **AI Agent Carnival** hackathon.

## What It Does

`pharos-defi` is a [Pharos Skill](https://www.pharos.xyz/agent-center) that enables AI Agents (Codex, Claude Code, OpenClaw) to execute DeFi operations on Pharos using Foundry `cast`/`forge`.

## Capabilities

| # | Capability | Script |
|---|-----------|--------|
| 1 | **Token Swap** ? ETH?Token, Token?Token, ExactOutput | `./scripts/swap.sh` |
| 2 | **Liquidity** ? Add/Remove, LP position check, IL risk | ? |
| 3 | **Price Quote** ? getAmountsOut/In, slippage, price impact | ? |
| 4 | **Multi-hop Routing** ? Path discovery, optimization | ? |
| 5 | **Portfolio Tracker** ? Native + tokens + LP auto-discovery | `./scripts/portfolio.sh` |
| 6 | **DCA Strategy** ? Dollar Cost Averaging with scheduling | `./scripts/dca.sh` |
| 7 | **Yield Analyzer** ? Pool scanning, APR, risk-adjusted yield | `./scripts/yield.sh` |
| 8 | **Contract Discovery** ? On-chain deployment verification | `./scripts/discover.sh` |
| 9 | **Anvita Flow Ready** ? Phase 2 Agent deployment guide | ? |

## Quick Start

```bash
# Install alongside pharos-skill-engine
npx skills add https://github.com/PharosNetwork/pharos-skill-engine
npx skills add https://github.com/xiaoxin1104/pharos-defi-skill

# Discover deployed contracts
chmod +x scripts/*.sh
./scripts/discover.sh atlantic-testnet

# Execute a swap
./scripts/swap.sh atlantic-testnet PHRS USDC 10.0

# View portfolio
./scripts/portfolio.sh atlantic-testnet
```

## Requirements

- Foundry (`cast`, `forge`) ? installed via `pharos-skill-engine`
- `jq`, `bc` ? for JSON parsing and calculations
- `pharos-skill-engine` ? for network config and basic chain operations

## Structure

```
pharos-defi-skill/
??? SKILL.md                     ? Agent capability index
??? AGENT_PROMPTS.md             ? Agent interaction examples
??? assets/
?   ??? networks.json            ? Network config
?   ??? dex.json                 ? DEX contract addresses
?   ??? tokens.json              ? Token registry
??? references/                  ? 9 detailed operation guides
??? scripts/                     ? 5 executable automation scripts
```

## Hackathon

Built for the **Pharos AI Agent Carnival** ? Skill-to-Agent Dual Cascade Hackathon (June 2026).

- **Phase 1**: Skill Hackathon submission
- **Phase 2**: Agent Arena via Anvita Flow (see `references/anvita-integration.md`)

## License

MIT-0 ? Free to use, modify, and redistribute. No attribution required.
