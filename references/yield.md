# Yield & APR Analysis

Analyze pool yields, compare APR across liquidity pools, and identify optimal yield opportunities on Pharos DEX.

> **Network Configuration**: Read `<rpc>` from `assets/networks.json`.
> **Factory Address**: Read `<factory>` from `assets/dex.json`.
> **⚠ IMPORTANT**: Yield calculation depends on accurate fee and volume data. For V2 pools, fees accrue to reserves over time. APR is derived from volume and fee rate assumptions.

---

## Operations Index

| Section | Operation | Description |
|---------|-----------|-------------|
| [1](#1-pool-volume--fees) | Pool Volume & Fees | Estimate pool fee generation |
| [2](#2-apr-calculation) | APR Calculation | Calculate estimated APR for LP |
| [3](#3-pool-comparison) | Pool Comparison | Rank pools by estimated yield |
| [4](#4-lp-fee-growth-check) | Fee Growth Check | Compare LP share over time |
| [5](#5-risk-adjusted-yield) | Risk-Adjusted Yield | Factor in IL risk and token volatility |

---

## Agent Guidelines (Yield)

1. APR estimates are **approximate** — based on current state, not historical data
2. Always include IL risk alongside yield numbers
3. Higher APR typically means higher risk (volatile tokens, more IL)
4. Stablecoin pairs (USDC/USDT) offer low but stable yield with near-zero IL
5. ETH-stablecoin pairs offer moderate yield with moderate IL risk

---

## 1. Pool Volume & Fees

For Uniswap V2 pools, LP fees are 0.3% per swap, distributed proportionally to LPs.

### Fee Estimation Formula

```
estimatedDailyFees = dailyVolume * 0.003
estimatedDailyYieldPerLP = estimatedDailyFees * (userLPShare / totalSupply)

Annualized = estimatedDailyFees * 365
APR = Annualized / totalLiquidity * 100
```

### Query Pool State

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)

PAIR="<pair_address>"

# Get reserves
RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
R0=$(echo "$RESERVES" | sed -n ''1p'' | tr -d ''[:space:]'')
R1=$(echo "$RESERVES" | sed -n ''2p'' | tr -d ''[:space:]'')
BLOCK_TS=$(echo "$RESERVES" | sed -n ''3p'' | tr -d ''[:space:]'')

# Get total LP supply
TOTAL_SUPPLY=$(cast call $PAIR "totalSupply()(uint256)" --rpc-url $RPC_URL)

echo "Pool: $PAIR"
echo "  Reserve0: $R0"
echo "  Reserve1: $R1"
echo "  Last block: $BLOCK_TS"
echo "  LP Supply: $TOTAL_SUPPLY"
```

---

## 2. APR Calculation

### Method 1: Reserve Growth Over Time

Track how reserves grow between two points in time:

```bash
# Snapshot 1 (now)
R1_T0_NOW=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL | sed -n ''1p'')

# Wait N seconds, then snapshot 2
sleep 3600  # 1 hour later
R1_T0_LATER=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL | sed -n ''1p'')

# Fee growth in 1 hour
GROWTH=$((R1_T0_LATER - R1_T0_NOW))
echo "Reserve0 growth in 1h: $GROWTH"
```

### Method 2: Volume-Based Estimate

```bash
# Approximate: totalLiquidity = reserve0 * price0 + reserve1 * price1
# Assume reserve0 = PHRS, reserve1 = USDC (stable)

# If we know or estimate daily swap volume (from explorer or external data):
DAILY_VOLUME_USD=100000  # $100k daily
FEE_RATE=0.003  # 0.3%
TOTAL_LIQUIDITY_USD=500000  # $500k TVL

DAILY_FEES=$(echo "scale=2; $DAILY_VOLUME_USD * $FEE_RATE" | bc)
ANNUAL_FEES=$(echo "scale=2; $DAILY_FEES * 365" | bc)
APR=$(echo "scale=2; $ANNUAL_FEES / $TOTAL_LIQUIDITY_USD * 100" | bc)

echo "═══ Estimated Pool Yield ═══"
echo "  Daily Volume:    $$DAILY_VOLUME_USD"
echo "  Daily Fees:     $$DAILY_FEES"
echo "  Annual Fees:    $$ANNUAL_FEES"
echo "  TVL:            $$TOTAL_LIQUIDITY_USD"
echo "  Estimated APR:  ${APR}%"
```

### Method 3: LP Token Supply Growth

Simplest check: if LP supply stays constant but reserves grow → fees accumulating:

```bash
# Check reserves at two known LP supply points
# If totalSupply is constant and reserves increase, LPs are earning
# This is a qualitative check, not quantitative
```

---

## 3. Pool Comparison

Compare all pools the user has LP in (or candidate pools) by estimated APR:

```bash
# For each pool, calculate:
# 1. TVL (in USD equivalent)
# 2. Estimated daily fees (if volume known)
# 3. Estimated APR
# 4. IL risk (volatility of underlying tokens)

echo "═══ Pool Yield Comparison ═══"
printf "%-15s %10s %10s %10s\n" "Pool" "TVL" "Est.APR" "IL Risk"
echo "-----------------------------------------------"
printf "%-15s %10s %10s %10s\n" "PHRS/USDC" "$500K" "12.5%" "Medium"
printf "%-15s %10s %10s %10s\n" "USDC/USDT" "$200K" "3.2%" "Low"
printf "%-15s %10s %10s %10s\n" "WBTC/USDC" "$150K" "8.7%" "Medium-High"
```

---

## 4. LP Fee Growth Check

Compare LP share value over time by checking reserves at different block heights:

```bash
# Get current reserves + block
RESERVES_NOW=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
R0_NOW=$(echo "$RESERVES_NOW" | sed -n ''1p'')

# Get historical reserves at deposit block (if known)
R0_DEPOSIT="<historical_reserve0>"

FEE_GROWTH=$(echo "scale=4; ($R0_NOW - $R0_DEPOSIT) / $R0_DEPOSIT * 100" | bc)

echo "Reserve0 growth since deposit: ${FEE_GROWTH}%"
echo "Note: This INCLUDES impermanent loss effects, not just fees"
```

### Pure Fee Tracking

To track only fees (excluding IL), compare `sqrt(reserve0 * reserve1)` before and after:

```bash
# k_before = R0_deposit * R1_deposit
# k_after = R0_now * R1_now
# fee_growth = sqrt(k_after / k_before) - 1

K_BEFORE=$(echo "scale=0; $R0_DEPOSIT * $R1_DEPOSIT" | bc)
K_NOW=$(echo "scale=0; $R0_NOW * $R1_NOW" | bc)
K_RATIO=$(echo "scale=10; $K_NOW / $K_BEFORE" | bc)
FEE_ONLY_GROWTH=$(echo "scale=4; (sqrt($K_RATIO) - 1) * 100" | bc)

echo "Pure fee growth (k-root): ${FEE_ONLY_GROWTH}%"
```

---

## 5. Risk-Adjusted Yield

Not all yield is equal. Factor in impermanent loss risk:

### Risk-Adjusted APR Formula

```
riskAdjustedAPR = baseAPR - estimatedIL

Where:
  baseAPR = expected annual fee yield
  estimatedIL = expected impermanent loss based on volatility
```

### IL Risk Table for Reference

| Token Pair Type | Volatility (annual) | Expected IL | Typical Fee APR | Risk-Adj APR |
|----------------|---------------------|-------------|-----------------|--------------|
| Stable/Stable | <5% | ~0.1% | 2-5% | 2-5% ✅ |
| ETH/Stable | 50-80% | ~5-10% | 10-25% | 5-15% |
| ETH/BTC | 40-60% | ~3-8% | 8-20% | 5-12% |
| Volatile/Stable | 80-150% | ~15-30% | 20-40% | ⚠ -10 to 25% |

### Recommendation Rules

The Agent should suggest:

- **Safe**: Stablecoin pairs → predictable low yield, near-zero IL
- **Balanced**: ETH/Stable pairs → moderate yield, manageable IL
- **Aggressive**: Volatile pairs → high potential yield, high IL risk
- **Avoid**: Pairs with low liquidity (<$10k TVL) regardless of APR

---

## Error Handling

| Error | Handling |
|-------|----------|
| Cannot estimate volume | Use reserve growth method, note uncertainty |
| Pool too new (< 7 days) | Warn that APR estimates are unreliable |
| Low liquidity | Warn of high slippage and entry/exit costs |
| Both tokens volatile | Emphasize IL risk, suggest stablecoin LP instead |
