# Agent Prompt Examples

This file contains example prompts showing how an AI Agent (Codex, Claude Code, OpenClaw) invokes
the `pharos-defi` skill to perform DeFi operations on Pharos.

---

## How Agents Use This Skill

When an Agent has `pharos-defi` installed, it reads `SKILL.md` and loads the capability
index. When the user mentions any DeFi-related task, the Agent matches it to a capability
and follows the detailed instructions in the corresponding `references/*.md` file.

All commands use Foundry ``cast``/``forge`` and follow the same patterns as the official
`pharos-skill-engine`.

---

## Swap Examples

### Basic Token Swap
> **User**: "Swap 10 PHRS for USDC on testnet"

**Agent Actions:**
1. Reads `SKILL.md` → matches to "Swap Token A → Token B"
2. Loads `references/swap.md#1-eth--token-swap`
3. Reads `assets/networks.json` for testnet RPC
4. Reads `assets/dex.json` for Router address
5. Reads `assets/tokens.json` for USDC address
6. Queries `getAmountsOut` for quote
7. Calculates `amountOutMin` with 0.5% slippage
8. Executes `swapExactETHForTokens` via cast
9. Verifies receipt and reports results

### Exact Output Swap
> **User**: "Buy exactly 100 USDC worth of PHRS on mainnet"

**Agent Actions:**
1. Matches to `references/swap.md#4-exact-output-swap`
2. Confirms mainnet operation with user
3. Uses `getAmountsIn` to calculate required PHRS
4. Uses `swapTokensForExactTokens` with 1% max slippage
5. Reports: TX hash, exact USDC received, rate

---

## Liquidity Examples

### Add Liquidity
> **User**: "Add 100 USDC and equivalent PHRS to the PHRS/USDC pool"

**Agent Actions:**
1. Loads `references/liquidity.md#1-add-liquidity-two-tokens`
2. Gets pool reserves to calculate optimal ratio
3. Checks allowances for both tokens
4. Calculates minimum amounts with 0.5% slippage
5. Approves Router for both tokens
6. Executes `addLiquidity`
7. Reports: LP tokens received, pool share %

### Check LP Position
> **User**: "How much LP do I have in PHRS/USDC?"

**Agent Actions:**
1. Loads `references/liquidity.md#5-lp-position-check`
2. Finds pair via Factory.getPair
3. Queries LP balance and total supply
4. Calculates share percentage
5. Reports current withdrawable amounts

---

## Portfolio Examples

### Full Portfolio
> **User**: "Show my DeFi portfolio"

**Agent Actions:**
1. Loads `references/portfolio.md`
2. Option 1: Runs `scripts/portfolio.sh atlantic-testnet`
3. Option 2: Executes step-by-step:
   - Queries native balance
   - Batch-queries all token balances from `tokens.json`
   - Auto-discovers LP positions by checking all pairs
   - Calculates LP share values
4. Reports formatted portfolio summary

### Specific Token Holdings
> **User**: "How much USDC and USDT do I have?"

**Agent Actions:**
1. Loads token addresses from `assets/tokens.json`
2. Queries `balanceOf` for each token
3. Reports human-readable balances

---

## Quote Examples

### Price Check
> **User**: "What''s the price of PHRS in USDC?"

**Agent Actions:**
1. Loads `references/quote.md#1-getamountsout`
2. Queries with 1 PHRS worth of input
3. Reports: "1 PHRS ≈ 0.38 USDC"

### Multi-Hop Quote
> **User**: "How much WBTC can I get for 10 PHRS?"

**Agent Actions:**
1. Checks: Factory.getPair(PHRS, WBTC)
2. If no direct pair, builds path: [PHRS, WPHRS, WBTC]
3. Queries getAmountsOut for full path
4. Reports expected output with each hop

---

## DCA Examples

### Setup DCA
> **User**: "Set up weekly DCA: buy $100 USDC worth of PHRS every Monday"

**Agent Actions:**
1. Loads `references/dca.md#1-dca-parameter-setup`
2. Confirms parameters: 100 USDC/week, PHRS
3. Generates swap command for single execution
4. Creates cron/systemd timer template
5. Saves DCA config to `dca_config.json`
6. Reminds: "DCA setup complete. Each Monday, $100 USDC → PHRS swap executes."

### Check DCA Performance
> **User**: "How is my DCA doing?"

**Agent Actions:**
1. Loads `references/dca.md#4-dca-pnl-calculation`
2. Reads `dca_log.csv` for execution history
3. Calculates total spent, total received, avg entry price
4. Gets current spot price
5. Reports PnL and comparison vs lump sum

---

## Yield Examples

### Compare Pools
> **User**: "Which pool has the best yield?"

**Agent Actions:**
1. Loads `references/yield.md#3-pool-comparison`
2. For each pool with LP: queries reserves, estimates APR
3. Factors in IL risk based on token pair type
4. Ranks by risk-adjusted yield
5. Reports: "USDC/USDT safest at ~3% APR. PHRS/USDC balanced at ~12%."

### LP Fee Tracking
> **User**: "How much have I earned in fees from my PHRS/USDC LP?"

**Agent Actions:**
1. Loads `references/yield.md#4-lp-fee-growth-check`
2. Compares current k-value vs deposit k-value
3. Extracts pure fee growth (excluding IL)
4. Reports fee earnings in both tokens

---

## Multi-Hop & Routing Example

> **User**: "Swap TOKEN_A for TOKEN_B but there''s no direct pair"

**Agent Actions:**
1. Loads `references/routing.md#1-path-construction`
2. Checks all intermediate tokens (WETH, USDC, USDT, WBTC)
3. Builds and validates alternative paths
4. Quotes each viable path
5. Selects best path by output amount
6. Executes multi-hop swap
7. Reports: "Routed via WETH. Output: 15.2 TOKEN_B (vs 14.8 via USDC)"

---

## Error Recovery Examples

### Insufficient Allowance
> **User**: "Swap 100 USDC for PHRS"

**Agent Actions:**
1. Attempts swap → fails: "transfer amount exceeds allowance"
2. Auto-checks: `USDC.allowance(user, Router)`
3. If insufficient: explains need for approval, prompts user
4. Executes `USDC.approve(Router, 100e6)`
5. Retries swap → succeeds

### Slippage Exceeded
> **Agent Output**: "Swap failed: INSUFFICIENT_OUTPUT_AMOUNT. Pool moved 1.2% against you. Retrying with 1.5% slippage..."

### Expired Transaction
> **Agent Output**: "Transaction expired (waited >20 min for confirmation). Regenerating with new deadline and retrying..."

---

## Security Scenarios

### Mainnet Warning
> **User**: "Swap 1000 PROS on mainnet"

**Agent Output:**
```
⚠ WARNING: This is a MAINNET transaction with real PROS.

  From:  0x1234...abcd
  Swap:  1,000 PROS → USDC
  Rate:  ~$380 per PROS
  Value: ~$380,000

  This is a significant transaction. Please:
  1. Double-check the recipient address
  2. Verify the Router contract is legitimate
  3. Consider splitting into smaller trades

Type "CONFIRM" to proceed:
```

### Approval Warning
> **Agent Output**: "Approving Router for 100 USDC (exact amount). Do NOT approve unlimited — this limits your exposure if the Router contract is compromised. Proceed?"
