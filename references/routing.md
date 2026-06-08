# Multi-Hop Routing

Multi-hop token swaps and path optimization for Pharos DEX when no direct trading pair exists.

> **Network Configuration**: The `<rpc>` parameter is read from `assets/networks.json`.
> **Router Address**: Read `<router>` from `assets/dex.json`.
> **Core Concept**: Uniswap V2 Router supports up to N-hop swaps using a token path array `[tokenA, hop1, hop2, ..., tokenB]`.

---

## Operations Index

| Section | Operation | Description |
|---------|-----------|-------------|
| [1](#1-path-construction) | Path Construction | Build optimal multi-hop paths |
| [2](#2-two-hop-swap-via-weth) | Two-Hop via WETH | Most common: [tokenA, WETH, tokenB] |
| [3](#3-three-hop-swap) | Three-Hop Swap | [tokenA, WETH, intermediate, tokenB] |
| [4](#4-path-validation) | Path Validation | Check all pairs exist before swap |
| [5](#5-path-optimization) | Path Optimization | Compare routes by expected output |
| [6](#6-complex-routing-with-cast) | Complex Routing with cast | Execute multi-hop swaps |

---

## Agent Guidelines (Routing)

1. **Default strategy**: Route through WETH when no direct pair exists
2. **Validate each hop**: Check that every adjacent pair in the path exists
3. **Compare alternatives**: If multiple paths are possible, quote all and pick the best
4. **Gas consideration**: Each additional hop adds ~50-70k gas; 3 hops is the practical maximum
5. **Path encoding**: Encoded as `[address1, address2, address3, ...]` in cast

---

## 1. Path Construction

### Decision Flow

```
User wants to swap TokenA → TokenB

1. Check: Factory.getPair(TokenA, TokenB)
   ├── Exists → Direct path: [TokenA, TokenB]
   └── Zero address → Continue to step 2

2. Check: Factory.getPair(TokenA, WETH) AND Factory.getPair(WETH, TokenB)
   ├── Both exist → Two-hop: [TokenA, WETH, TokenB]
   └── One missing → Continue to step 3

3. Find intermediate: Check common tokens (USDC, USDT, WBTC)
   Check: Factory.getPair(TokenA, INTERMEDIATE) AND Factory.getPair(INTERMEDIATE, TokenB)
   ├── Both exist → Three-hop: [TokenA, INTERMEDIATE, TokenB]
   │   OR if INTERMEDIATE is not WETH but WETH works:
   │   [TokenA, INTERMEDIATE, WETH, TokenB] (four-hop, consider gas)
   └── No path found → Inform user: no viable route
```

### Path Discovery Script

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

TOKEN_A="<address>"
TOKEN_B="<address>"

# 1. Check direct pair
DIRECT=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)
if [ "$DIRECT" != "0x0000000000000000000000000000000000000000" ]; then
  echo "PATH: [$TOKEN_A, $TOKEN_B]  (direct)"
  exit 0
fi

# 2. Check via WETH
PAIR_AWETH=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $WETH --rpc-url $RPC_URL)
PAIR_WETHB=$(cast call $FACTORY "getPair(address,address)(address)" $WETH $TOKEN_B --rpc-url $RPC_URL)

if [ "$PAIR_AWETH" != "0x0000000000000000000000000000000000000000" ] && \
   [ "$PAIR_WETHB" != "0x0000000000000000000000000000000000000000" ]; then
  echo "PATH: [$TOKEN_A, $WETH, $TOKEN_B]  (via WETH)"
  exit 0
fi

# 3. Check via common intermediates
for INTERMEDIATE in $USDC $USDT $WBTC; do
  PAIR_AI=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $INTERMEDIATE --rpc-url $RPC_URL)
  PAIR_IB=$(cast call $FACTORY "getPair(address,address)(address)" $INTERMEDIATE $TOKEN_B --rpc-url $RPC_URL)
  if [ "$PAIR_AI" != "0x0000000000000000000000000000000000000000" ] && \
     [ "$PAIR_IB" != "0x0000000000000000000000000000000000000000" ]; then
    echo "PATH: [$TOKEN_A, $INTERMEDIATE, $TOKEN_B]  (via intermediate)"
    exit 0
  fi
done

echo "No viable route found for $TOKEN_A → $TOKEN_B"
```

---

## 2. Two-Hop Swap via WETH

The most common multi-hop: TokenA → WETH → TokenB.

### Command

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

# Path: [TOKEN_A, WETH, TOKEN_B]
PATH="[$TOKEN_A, $WETH, $TOKEN_B]"

# 1. Get quote for full path
QUOTE=$(cast call $ROUTER \
  "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH" \
  --rpc-url $RPC_URL)

echo "$QUOTE"
# Output: [amountIn, amountWethReceived, amountTokenBReceived]
# The LAST value is the final output

EXPECTED_OUT=$(echo "$QUOTE" | tail -1)

# 2. Calculate slippage
AMOUNT_OUT_MIN=$(echo "scale=0; $EXPECTED_OUT * 995 / 1000" | bc)

# 3. Check and set allowance for TokenA
ALLOWANCE=$(cast call $TOKEN_A "allowance(address,address)(uint256)" <user_address> $ROUTER --rpc-url $RPC_URL)
if [ "$ALLOWANCE" -lt "<amount_in_wei>" ]; then
  cast send $TOKEN_A "approve(address,uint256)(bool)" $ROUTER <amount_in_wei> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi

# 4. Execute multi-hop swap
DEADLINE=$(($(date +%s) + 1200))
cast send $ROUTER \
  "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
  <amount_in_wei> $AMOUNT_OUT_MIN "$PATH" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Gas Note

Two-hop swaps use ~150k-200k gas (vs ~100k-150k for direct). Warn the user if the trade value is small relative to gas cost.

---

## 3. Three-Hop Swap

For tokens where even WETH doesn''t bridge directly: TokenA → Intermediate → WETH → TokenB.

```bash
# Path: [TOKEN_A, INTERMEDIATE, WETH, TOKEN_B]
INTERMEDIATE="<intermediate_token_address>"
PATH="[$TOKEN_A, $INTERMEDIATE, $WETH, $TOKEN_B]"

# Get quote
QUOTE=$(cast call $ROUTER \
  "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH" \
  --rpc-url $RPC_URL)

echo "$QUOTE"
# Output: [amountIn, hop1Out, hop2Out, finalOut]

EXPECTED_OUT=$(echo "$QUOTE" | tail -1)
AMOUNT_OUT_MIN=$(echo "scale=0; $EXPECTED_OUT * 995 / 1000" | bc)

# Execute
cast send $ROUTER \
  "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
  <amount_in_wei> $AMOUNT_OUT_MIN "$PATH" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 4. Path Validation

Before executing any multi-hop swap, validate that EVERY pair in the path exists.

```bash
validate_path() {
  local PATH_STR=$1
  # Parse path array: [addr0, addr1, addr2, ...]
  local ADDRS=($(echo "$PATH_STR" | tr -d ''[]'' | tr '','' '' ''))
  
  for ((i=0; i<${#ADDRS[@]}-1; i++)); do
    local TOKEN_A=${ADDRS[$i]}
    local TOKEN_B=${ADDRS[$i+1]}
    
    local PAIR=$(cast call $FACTORY \
      "getPair(address,address)(address)" \
      $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)
    
    if [ "$PAIR" = "0x0000000000000000000000000000000000000000" ]; then
      echo "❌ Hop $i: No pair for $TOKEN_A ↔ $TOKEN_B"
      return 1
    else
      echo "✅ Hop $i: $TOKEN_A → $TOKEN_B  (pair: $PAIR)"
    fi
  done
  return 0
}
```

---

## 5. Path Optimization

When multiple routes exist, compare their expected output to find the best one.

```bash
# Compare two paths
PATH1="[$TOKEN_A, $WETH, $TOKEN_B]"
PATH2="[$TOKEN_A, $USDC, $TOKEN_B]"

QUOTE1=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH1" --rpc-url $RPC_URL | tail -1)

QUOTE2=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH2" --rpc-url $RPC_URL | tail -1)

echo "Path 1 (via WETH):  $QUOTE1"
echo "Path 2 (via USDC):  $QUOTE2"

# Pick best output
if [ "$QUOTE1" -gt "$QUOTE2" ]; then
  echo "✅ Best: Path 1 (via WETH)"
else
  echo "✅ Best: Path 2 (via USDC)"
fi
```

### Optimization Factors

| Factor | Priority | Notes |
|--------|----------|-------|
| **Output amount** | Highest | Pick path with best expected output |
| **Hop count** | High | Fewer hops = less gas, fewer failure points |
| **Pool liquidity** | Medium | Deeper pools = less slippage and price impact |
| **Gas cost** | Low | Only relevant when trade value is small |

---

## 6. Complex Routing with Cast

For complex multi-hop trades, use cast with properly encoded path array.

### Path Array Encoding

In cast, the path is an ABI-encoded `address[]`:

```bash
# For a path [0xA, 0xB, 0xC]:
# The encoded form is: [0xA, 0xB, 0xC]
# 3-element path with 3 addresses

# Cast expects the format: [addr1, addr2, addr3]
PATH="[0xAAAA, 0xBBBB, 0xCCCC]"
```

### All-In-One Multi-Hop Swap Script

```bash
#!/bin/bash
# Multi-hop swap: TokenA → TokenB with automatic path finding

RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

TOKEN_A=$1
TOKEN_B=$2
AMOUNT_IN=$3
RECIPIENT=$4

# Find best path (simplified: try direct, then via WETH)
DIRECT=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)

if [ "$DIRECT" != "0x0000000000000000000000000000000000000000" ]; then
  PATH="[$TOKEN_A, $TOKEN_B]"
else
  PATH="[$TOKEN_A, $WETH, $TOKEN_B]"
fi

echo "Using path: $PATH"

# Quote
QUOTE=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" $AMOUNT_IN "$PATH" --rpc-url $RPC_URL)
EXPECTED_OUT=$(echo "$QUOTE" | tail -1)
echo "Expected output: $EXPECTED_OUT"

# Slippage
AMOUNT_OUT_MIN=$(echo "scale=0; $EXPECTED_OUT * 995 / 1000" | bc)

# Allowance
ALLOWANCE=$(cast call $TOKEN_A "allowance(address,address)(uint256)" $RECIPIENT $ROUTER --rpc-url $RPC_URL)
if [ "$ALLOWANCE" -lt "$AMOUNT_IN" ]; then
  echo "Approving Router for token..."
  cast send $TOKEN_A "approve(address,uint256)(bool)" $ROUTER $AMOUNT_IN \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi

# Swap
DEADLINE=$(($(date +%s) + 1200))
TX=$(cast send $ROUTER \
  "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
  $AMOUNT_IN $AMOUNT_OUT_MIN "$PATH" $RECIPIENT $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL)

echo "Swap executed: $TX"
```

---

## Error Handling

| Error | Signature | Handling |
|-------|-----------|----------|
| No route exists | All Factory.getPair return 0x0 | Inform user, suggest bridging |
| Hop pair not found | `PAIR_NOT_FOUND` during swap | Validate path before swap |
| Gas too high for value | Gas > 5% of trade value | Warn user, suggest larger trade or direct pair |
| Path too long | Gas out of gas | Maximum 4 hops; prefer 2-3 |
| Circular path | `IDENTICAL_ADDRESSES` somewhere in path | Check path has no duplicates |
