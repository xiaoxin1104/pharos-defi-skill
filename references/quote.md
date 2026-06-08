# Quote & Price Operations

Price quotes, slippage calculation, and price impact estimation for Pharos DEX.

> **Network Configuration**: The `<rpc>` parameter is read from `assets/networks.json`.
> **Router Address**: Read `<router>` from `assets/dex.json`.
> **Token Addresses**: Resolve from `assets/tokens.json`.

---

## Operations Index

| Section | Operation | Router Method |
|---------|-----------|---------------|
| [1](#1-getamountsout--input--output) | Input → Expected Output | `getAmountsOut` |
| [2](#2-getamountsin--output--input) | Desired Output → Required Input | `getAmountsIn` |
| [3](#3-slippage-calculation) | Slippage Calculation | Formula |
| [4](#4-price-impact-estimation) | Price Impact Estimation | Formula |
| [5](#5-pool-reserve-query) | Pool Reserve Query | `getReserves` |
| [6](#6-pair-existence-check) | Pair Existence Check | `Factory.getPair` |

---

## Agent Guidelines (Quote Operations)

1. All quotes are **read-only** via `cast call` — no gas cost, no private key needed
2. Always validate pair existence before quoting (via `Factory.getPair`)
3. Display quotes in **human-readable format** (adjust for token decimals)
4. For large trades (>1% of pool reserves), warn about price impact
5. Quotes are estimates; actual fill price depends on block-time ordering

---

## 1. getAmountsOut — Input → Output

Given an input amount, calculate expected output through a token path.

### Parameters
| Param | Type | Description |
|-------|------|-------------|
| amountIn | uint256 | Input token amount (in smallest unit) |
| path | address[] | Token path: [tokenA, tokenB] or [tokenA, WETH, tokenB] |

### Command

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)

# Resolve token addresses
TOKEN_A="<address_from_tokens_json>"
TOKEN_B="<address_from_tokens_json>"

# Build path (check pair existence first)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
PAIR=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)

if [ "$PAIR" = "0x0000000000000000000000000000000000000000" ]; then
  PATH="[$TOKEN_A, $WETH, $TOKEN_B]"
else
  PATH="[$TOKEN_A, $TOKEN_B]"
fi

# Get quote — returns array of amounts at each hop
QUOTE=$(cast call $ROUTER \
  "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH" \
  --rpc-url $RPC_URL)

echo "$QUOTE"
# Output example: [1000000000000000000, 3950000000]
# [amountIn, amountOut1, amountOut2, ...]
# The last element is the final output amount
```

### Output Parsing

```bash
# Extract the last value (final output amount)
EXPECTED_OUT=$(echo "$QUOTE" | tail -1)
echo "Expected output: $EXPECTED_OUT (raw)"
```

### Human-Readable Display

```bash
# Adjust for token decimals
# e.g., USDC has 6 decimals: expectedOut / 10^6
echo "Expected: $(echo "scale=6; $EXPECTED_OUT / 1000000" | bc) USDC"
```

---

## 2. getAmountsIn — Output → Input

Given a desired output amount, calculate required input.

```bash
QUOTE_IN=$(cast call $ROUTER \
  "getAmountsIn(uint256,address[])(uint256[])" \
  <desired_output_wei> "$PATH" \
  --rpc-url $RPC_URL)

echo "$QUOTE_IN"
# Output example: [1002000000000000000, 3950000000]
# [amountIn, amountOut] (first element is required input)
```

---

## 3. Slippage Calculation

Slippage is the difference between expected output and minimum acceptable output.

### Formula

```
slippagePercentage = (expectedOutput - minOutput) / expectedOutput * 100
```

### Tiers

| Tier | Percentage | When to Use |
|------|-----------|-------------|
| **Standard** | 0.5% | Normal liquidity pools, moderate trade size |
| **Elevated** | 1.0% | Low liquidity pairs, volatile market conditions |
| **High** | 2.0% | Very low liquidity, large trade (>1% of reserves) |
| **Custom** | User-specified | User sets their own tolerance |

### Implementation

```bash
# Given expected output and slippage tier
EXPECTED_OUT=<value>
SLIPPAGE_PCT=0.5  # default

# Calculate minimum
# For 0.5%: multiply by (100 - 0.5) / 100 = 0.995
MIN_OUT=$(echo "scale=0; $EXPECTED_OUT * (100 - $SLIPPAGE_PCT) / 100" | bc)

echo "Expected: $EXPECTED_OUT"
echo "Min (${SLIPPAGE_PCT}% slippage): $MIN_OUT"
```

### Slippage Warning Triggers

The Agent MUST warn the user when:
- Trade amount > 1% of pool reserves (suggest 1-2% slippage)
- The token pair has existed for < 24 hours
- Pool TVL < $10,000 equivalent

---

## 4. Price Impact Estimation

Price impact measures how much the trade itself moves the market price. Based on constant product AMM formula.

### Formula

```
For a pool with reserves (rA, rB) and trade amount aIn:

newReserveA = rA + aIn
newReserveB = rA * rB / newReserveA
output = rB - newReserveB

priceImpact = 1 - (output / (aIn * rB / rA))
```

### Query Pool Reserves

```bash
# Get reserves for a pair
PAIR="<pair_address>"
RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
# Returns: [reserve0, reserve1, blockTimestampLast]

# Also check which token is token0
TOKEN0=$(cast call $PAIR "token0()(address)" --rpc-url $RPC_URL)
```

### Quick Check

```bash
# For a quick assessment: compare trade size to pool size
# If tradeAmount > reserveTokenIn * 0.01 (1%), warn user
if [ "$TRADE_AMOUNT" -gt "$((RESERVE_IN / 100))" ]; then
  echo "⚠️ WARNING: Trade size > 1% of pool reserves"
  echo "Expected price impact: significant"
  echo "Consider splitting the trade or using higher slippage"
fi
```

---

## 5. Pool Reserve Query

Query pair reserves and TVL from a Pair contract.

```bash
PAIR="<pair_address>"

# Get reserves
RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
RESERVE0=$(echo "$RESERVES" | head -1)
RESERVE1=$(echo "$RESERVES" | head -2 | tail -1)

# Get token addresses
TOKEN0=$(cast call $PAIR "token0()(address)" --rpc-url $RPC_URL)
TOKEN1=$(cast call $PAIR "token1()(address)" --rpc-url $RPC_URL)

# Get total supply (LP tokens)
TOTAL_SUPPLY=$(cast call $PAIR "totalSupply()(uint256)" --rpc-url $RPC_URL)

echo "Pool: $PAIR"
echo "Token0: $TOKEN0  Reserve: $RESERVE0"
echo "Token1: $TOKEN1  Reserve: $RESERVE1"
echo "LP Supply: $TOTAL_SUPPLY"
```

---

## 6. Pair Existence Check

Before quoting a swap, verify the trading pair exists.

```bash
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
TOKEN_A="<address>"
TOKEN_B="<address>"

PAIR=$(cast call $FACTORY \
  "getPair(address,address)(address)" \
  $TOKEN_A $TOKEN_B \
  --rpc-url $RPC_URL)

if [ "$PAIR" = "0x0000000000000000000000000000000000000000" ]; then
  echo "No direct pair exists for $TOKEN_A ↔ $TOKEN_B"
  echo "Use multi-hop routing via WETH (see references/routing.md)"
else
  echo "Pair address: $PAIR"
fi
```

---

## Error Handling

| Error | Signature | Handling |
|-------|-----------|----------|
| No pair exists | `0x0` from Factory.getPair | Suggest multi-hop via WETH |
| Path too long | Empty / malformed quote | Check path array is valid (2-3 addresses) |
| Zero reserves | `reserve0 == 0 OR reserve1 == 0` | Pool uninitialized / drained — do not trade |
| Over/underflow | Empty return from getAmountsOut | Input amount too large for pool |
