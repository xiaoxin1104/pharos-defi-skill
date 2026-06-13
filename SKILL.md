---
name: pharos-defi
description: >
  REQUIRED for any Pharos DeFi task. This skill contains DEX contract configurations, token registries, and comprehensive command templates for swap, liquidity management, price quotes, multi-hop routing, portfolio tracking, DCA strategies, yield analysis, cross-chain bridging, and Anvita Flow Agent integration on Pharos. Invoke whenever the user wants to swap tokens, add/remove liquidity, check token prices, route multi-hop trades, view their DeFi portfolio, set up automated DCA, analyze pool yields, discover on-chain contracts, or prepare a Skill for Anvita Flow Agent deployment. Works with Uniswap V2-compatible DEX contracts and uses Foundry cast/forge. Must be used together with pharos-skill-engine for network config and basic on-chain operations. Do not attempt Pharos DeFi operations without this skill.
version: 0.4.0
requires:
  anyBins:
  - cast
  - forge
  - jq
  - bc
---

# Pharos DeFi Skill

Complete DeFi operations toolkit for the Pharos blockchain. Execute token swaps, manage liquidity positions, query prices, discover optimal trade routes, track portfolio performance, run DCA strategies, analyze pool yields, discover on-chain contracts, bridge tokens cross-chain, and prepare for Anvita Flow Agent deployment ? all through standard Uniswap V2-compatible DEX contracts using Foundry (`cast`/`forge`) CLI commands.

> **IMPORTANT**: This skill depends on `pharos-skill-engine` for network configuration, private key setup, Foundry installation, and basic on-chain utility operations (balance checks, transaction verification). The Agent MUST consult `pharos-skill-engine` for any underlying chain operations not covered here.

---

## Prerequisites

> **Delegate to `pharos-skill-engine`**: Foundry installation, private key configuration, network RPC setup, and balance checks are handled by `pharos-skill-engine`. This skill assumes those prerequisites are satisfied.

1. **DEX Contract Addresses**: All DEX contract addresses are stored in `assets/dex.json`. Run `./scripts/discover.sh` to check which contracts are currently deployed.
2. **Token Addresses**: Common token addresses are stored in `assets/tokens.json`. Read this file to resolve token symbols to addresses.
3. **Network Configuration**: Network RPC URLs and chain IDs are stored in `assets/networks.json` (same format as `pharos-skill-engine`).
4. **Contract Discovery**: Before any operation, run `./scripts/discover.sh` to verify contract availability on-chain.

```bash
# Quick start: discover what''s deployed
chmod +x scripts/*.sh
./scripts/discover.sh atlantic-testnet
```

---

## Capability Index

| User Need | Capability | Reference | Quick Script |
|-----------|-----------|-----------|-------------|
| Swap Token A ? Token B | Exact-input swap (ETH/Token/Token) | ? `references/swap.md` | `./scripts/swap.sh` |
| Get swap price / quote | getAmountsOut / getAmountsIn | ? `references/quote.md` | ? |
| Add liquidity to a pool | addLiquidity / addLiquidityETH | ? `references/liquidity.md` | ? |
| Remove liquidity | removeLiquidity / removeLiquidityETH | ? `references/liquidity.md` | ? |
| Multi-hop token routing | Path discovery + multi-hop swap | ? `references/routing.md` | ? |
| **Check DeFi portfolio** | **Native, tokens, LP positions** | ? `references/portfolio.md` | `./scripts/portfolio.sh` |
| **Set up DCA strategy** | **Periodic automated buys** | ? `references/dca.md` | `./scripts/dca.sh --setup` |
| **Execute DCA buy** | **Run next scheduled DCA buy** | ? `references/dca.md` | `./scripts/dca.sh --execute` |
| **Check DCA status** | **Progress and PnL tracking** | ? `references/dca.md` | `./scripts/dca.sh --status` |
| **Analyze pool yields** | **APR, fee tracking, IL risk** | ? `references/yield.md` | `./scripts/yield.sh` |
| **Bridge tokens cross-chain** | **Deposit/withdraw + status + fees** | ? `references/bridge.md` | ? |
| **Discover on-chain contracts** | **Auto-detect deployed DEX contracts** | ? `assets/dex.json` | `./scripts/discover.sh` |
| **Bridge tokens cross-chain** | **Deposit/withdraw + status + fees** | ? `references/bridge.md` | ? |
| **Prepare for Anvita Flow** | **Skill-to-Agent deployment guide** | ? `references/anvita-integration.md` | ? |

---

## Quick Start

```bash
# 1. Discover deployed contracts
./scripts/discover.sh atlantic-testnet

# 2. One-command swap
./scripts/swap.sh atlantic-testnet PHRS USDC 10.0 0.5

# 3. Check portfolio
./scripts/portfolio.sh atlantic-testnet

# 4. Set up DCA (dollar cost averaging)
./scripts/dca.sh --setup

# 5. Analyze pool yields
# 6. Bridge tokens
./scripts/discover.sh atlantic-testnet
./scripts/yield.sh atlantic-testnet
```

---

## Project Structure

```
pharos-defi-skill/
??? SKILL.md                         ? Capability index + security rules
??? AGENT_PROMPTS.md                 ? 15+ Agent interaction scenarios
??? assets/
?   ??? networks.json                ? Pharos testnet + mainnet config
?   ??? dex.json                     ? DEX contract addresses + verification
?   ??? tokens.json                  ? Token registry (PHRS/USDC/USDT/WBTC)
??? references/
?   ??? swap.md                      ? Swap operations (4 swap types)
?   ??? liquidity.md                 ? LP management + IL awareness
?   ??? quote.md                     ? Price quotes + slippage + impact
?   ??? routing.md                   ? Multi-hop path optimization
?   ??? portfolio.md                 ? Full DeFi portfolio analytics
?   ??? dca.md                       ? DCA strategy + scheduling
?   ??? yield.md                     ? Pool yield + risk analysis
?   ??? anvita-integration.md        ? Anvita Flow Agent deployment guide
??? scripts/
    ??? swap.sh                      ? Automated swap with safety checks
    ??? portfolio.sh                 ? One-command portfolio overview
    ??? dca.sh                       ? DCA setup/execute/status
    ??? yield.sh                     ? Pool scanning + risk analysis
    ??? discover.sh                  ? On-chain contract discovery
```

**18 files, 11 capabilities, 5 executable scripts.**

---

## Write Operation Pre-checks (Required for All DeFi Write Operations)

> The Agent MUST also complete the standard pre-checks from `pharos-skill-engine` (private key check, address derivation, network confirmation, balance check).

### 1. Token Approval Check

```bash
cast call <token> "allowance(address,address)(uint256)" <user> <router> --rpc-url $RPC_URL
```

**? SECURITY**: Always approve the exact amount needed. Never approve `type(uint256).max`.

### 2. Slippage Protection

- **Default**: 0.5% ? multiply expected output by 0.995
- **High volatility / low liquidity**: warn user, suggest 1-2%

### 3. Deadline

```bash
DEADLINE=$(($(date +%s) + 1200))  # 20 minutes
```

---

## Anvita Flow Agent Integration

This Skill is designed for immediate Anvita Flow Agent conversion in Phase 2.
See `references/anvita-integration.md` for:

- Skill ? Agent conversion steps
- Multi-skill composition architecture (pharos-defi + pharos-skill-engine)
- Agent prompt examples and expected behaviors
- Phase 2 deployment checklist

### Key Integration Points

| Anvita Flow Requirement | pharos-defi Support |
|------------------------|---------------------|
| Standardized SKILL.md | ? v0.3.0, full YAML frontmatter |
| Agent-readable references | ? 8 reference files |
| Executable operations | ? 5 scripts with safety checks |
| Error handling | ? Per-operation error tables |
| Multi-skill compatible | ? Same toolchain (cast/forge/jq/bc) |
| User-facing prompts | ? AGENT_PROMPTS.md (15+ scenarios) |

---

## General Error Handling

| Error | Handling |
|-------|----------|
| Insufficient allowance | Prompt to approve Router for exact amount |
| Insufficient balance | Show current balance and shortfall |
| Slippage exceeded | `INSUFFICIENT_OUTPUT_AMOUNT` ? suggest higher slippage |
| Expired deadline | `EXPIRED` ? regenerate + retry |
| Pair not found | `0x0` from Factory ? suggest multi-hop via WETH |
| Contract not deployed | Run `./scripts/discover.sh` to check status |

---

## Security Reminders

- **Approval**: Exact amounts only. No unlimited approvals.
- **Slippage & MEV**: Always set `amountOutMin`. Unprotected trades are sandwich-attack targets.
- **Deadline**: 20 minutes default. Never `0` or far future.
- **Network**: Confirm testnet vs mainnet before every write operation.
- **IL Risk**: Always warn before liquidity provision. See `references/liquidity.md#6`.
- **DCA Gas**: Warn if per-trade gas exceeds 1% of trade amount.

---

## Contract Address Notes

DEX contracts (Router/Factory/WETH) are not yet deployed on Pharos as of June 2026.
Permit2 (`0x000000000022D473030F116dDEE9F6B43aC78BA3`) is confirmed deployed on testnet.

- Run `./scripts/discover.sh` to detect newly deployed contracts
- Update `assets/dex.json` when addresses become available
- The skill uses standard Uniswap V2 interfaces ? works immediately upon deployment
