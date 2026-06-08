# Liquidity Operations

Add and remove liquidity from Uniswap V2-compatible pools on Pharos DEX.

> **Network Configuration**: The `<rpc>` parameter is read from `assets/networks.json`.
> **Router Address**: Read `<router>` from `assets/dex.json`.
> **Private Key**: All write operations require `--private-key $PRIVATE_KEY`.
> **⚠️ IMPORTANT**: Liquidity provision involves multiple token approvals. Always check allowances for BOTH tokens before adding liquidity.

---

## Operations Index

| Section | Operation | Router Method |
|---------|-----------|---------------|
| [1](#1-add-liquidity-two-tokens) | Add Liquidity (two ERC-20) | `addLiquidity` |
| [2](#2-add-liquidity-eth--token) | Add Liquidity (ETH + Token) | `addLiquidityETH` |
| [3](#3-remove-liquidity-two-tokens) | Remove Liquidity (receive tokens) | `removeLiquidity` |
| [4](#4-remove-liquidity-eth--token) | Remove Liquidity (receive ETH) | `removeLiquidityETH` |
| [5](#5-lp-position-check) | LP Token Balance & Share | `balanceOf` + `getReserves` |
| [6](#6-impermanent-loss-awareness) | Impermanent Loss Check | Calculation |

---

## Agent Guidelines (Liquidity Operations)

### Pre-liquidity Flow (MANDATORY)

1. Verify pair exists (via `Factory.getPair`) — see `references/quote.md#6-pair-existence-check`
2. Query pool reserves to determine optimal ratio
3. Calculate token amounts (must match current pool ratio for optimal add)
4. Check allowances for BOTH tokens (ERC-20 pairs) or one token (ETH pairs)
5. Set deadline: `$(date +%s) + 1200`
6. Confirm with user:
   - Pool address and token pair
   - Amounts to deposit
   - Expected LP tokens to receive
   - Current pool ratio and price
   - Network confirmation

---

## 1. Add Liquidity (Two Tokens)

Deposit both tokens into an existing pool proportionally.

### Router Method
`addLiquidity(address tokenA, address tokenB, uint256 amountADesired, uint256 amountBDesired, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`

### Step-by-Step

```bash
# 1. Load config
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)

# 2. Get pool info
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
PAIR=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)

if [ "$PAIR" = "0x0000000000000000000000000000000000000000" ]; then
  echo "Pool does not exist. Pair must be created before adding liquidity."
  echo "The first liquidity provider sets the initial price ratio."
  exit 1
fi

# 3. Get reserves and calculate ratio
RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
RESERVE0=$(echo "$RESERVES" | head -1)
RESERVE1=$(echo "$RESERVES" | head -2 | tail -1)

# Determine which token is token0
TOKEN0=$(cast call $PAIR "token0()(address)" --rpc-url $RPC_URL)

# 4. Calculate optimal amounts based on pool ratio
# If TOKEN_A is token0: amountB = amountA * reserve1 / reserve0
# If TOKEN_A is token1: amountB = amountA * reserve0 / reserve1
if [ "$TOKEN_A" = "$TOKEN0" ]; then
  AMOUNT_B_OPTIMAL=$(echo "scale=0; <amount_a_in_wei> * $RESERVE1 / $RESERVE0" | bc)
else
  AMOUNT_B_OPTIMAL=$(echo "scale=0; <amount_a_in_wei> * $RESERVE0 / $RESERVE1" | bc)
fi

# 5. Set minimums with 0.5% slippage
AMOUNT_A_MIN=$(echo "scale=0; <amount_a_in_wei> * 995 / 1000" | bc)
AMOUNT_B_MIN=$(echo "scale=0; $AMOUNT_B_OPTIMAL * 995 / 1000" | bc)

# 6. Approve BOTH tokens
cast send $TOKEN_A "approve(address,uint256)(bool)" $ROUTER <amount_a_in_wei> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

cast send $TOKEN_B "approve(address,uint256)(bool)" $ROUTER $AMOUNT_B_OPTIMAL \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 7. Add liquidity
DEADLINE=$(($(date +%s) + 1200))
cast send $ROUTER \
  "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)" \
  $TOKEN_A $TOKEN_B <amount_a_in_wei> $AMOUNT_B_OPTIMAL $AMOUNT_A_MIN $AMOUNT_B_MIN <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Parameters

| Param | Type | Description |
|-------|------|-------------|
| tokenA | address | First token address |
| tokenB | address | Second token address |
| amountADesired | uint256 | Desired amount of tokenA |
| amountBDesired | uint256 | Desired amount of tokenB (should match pool ratio) |
| amountAMin | uint256 | Minimum tokenA (with slippage) |
| amountBMin | uint256 | Minimum tokenB (with slippage) |
| to | address | LP token recipient |
| deadline | uint256 | Unix timestamp |

---

## 2. Add Liquidity (ETH + Token)

Deposit native currency + ERC-20 token into a pool.

### Router Method
`addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) payable`

```bash
# 1. Resolve token address
TOKEN="<token_address>"

# 2. Get pool info (pool is [WETH, TOKEN])
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)
PAIR=$(cast call $FACTORY "getPair(address,address)(address)" $WETH $TOKEN --rpc-url $RPC_URL)

# 3. Get reserves and calculate ETH needed
RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
# WETH is always token0 if address < token, but verify
TOKEN0=$(cast call $PAIR "token0()(address)" --rpc-url $RPC_URL)

if [ "$TOKEN0" = "$WETH" ]; then
  ETH_OPTIMAL=$(echo "scale=0; <token_amount_wei> * $RESERVE0 / $RESERVE1" | bc)
else
  ETH_OPTIMAL=$(echo "scale=0; <token_amount_wei> * $RESERVE1 / $RESERVE0" | bc)
fi

# 4. Set minimums
TOKEN_MIN=$(echo "scale=0; <token_amount_wei> * 995 / 1000" | bc)
ETH_MIN=$(echo "scale=0; $ETH_OPTIMAL * 995 / 1000" | bc)

# 5. Approve token
cast send $TOKEN "approve(address,uint256)(bool)" $ROUTER <token_amount_wei> \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 6. Add liquidity (ETH sent via --value)
cast send $ROUTER \
  "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN <token_amount_wei> $TOKEN_MIN $ETH_MIN <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --value $ETH_OPTIMAL
```

---

## 3. Remove Liquidity (Two Tokens)

Withdraw tokens from a pool by burning LP tokens.

### Router Method
`removeLiquidity(address tokenA, address tokenB, uint256 liquidity, uint256 amountAMin, uint256 amountBMin, address to, uint256 deadline)`

### Step-by-Step

```bash
# 1. Check LP token balance
LP_BALANCE=$(cast call $PAIR "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL)
echo "LP balance: $LP_BALANCE"

# 2. Calculate share of pool
TOTAL_SUPPLY=$(cast call $PAIR "totalSupply()(uint256)" --rpc-url $RPC_URL)
SHARE=$(echo "scale=6; $LP_BALANCE / $TOTAL_SUPPLY" | bc)

# 3. Calculate expected outputs
EXPECTED_A=$(echo "scale=0; $RESERVE0 * $LP_BALANCE / $TOTAL_SUPPLY" | bc)
EXPECTED_B=$(echo "scale=0; $RESERVE1 * $LP_BALANCE / $TOTAL_SUPPLY" | bc)

# 4. Set minimums with slippage
MIN_A=$(echo "scale=0; $EXPECTED_A * 995 / 1000" | bc)
MIN_B=$(echo "scale=0; $EXPECTED_B * 995 / 1000" | bc)

# 5. Approve LP tokens for Router
cast send $PAIR "approve(address,uint256)(bool)" $ROUTER $LP_BALANCE \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 6. Remove liquidity
cast send $ROUTER \
  "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN_A $TOKEN_B $LP_BALANCE $MIN_A $MIN_B <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 4. Remove Liquidity (ETH + Token)

Receive native ETH instead of WETH.

### Router Method
`removeLiquidityETH(address token, uint256 liquidity, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline)`

```bash
# Same prep as two-token removal, but use:
cast send $ROUTER \
  "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN $LP_BALANCE $TOKEN_MIN $ETH_MIN <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 5. LP Position Check

Query the user''s current LP position in any pool.

```bash
# For each pool the user has LP in:
PAIR="<pair_address>"

# LP balance
LP_BALANCE=$(cast call $PAIR "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL)

if [ "$LP_BALANCE" -eq 0 ]; then
  echo "No LP position in this pool"
else
  TOTAL_SUPPLY=$(cast call $PAIR "totalSupply()(uint256)" --rpc-url $RPC_URL)
  SHARE_PCT=$(echo "scale=4; $LP_BALANCE * 100 / $TOTAL_SUPPLY" | bc)
  
  RESERVES=$(cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
  RESERVE0=$(echo "$RESERVES" | head -1)
  RESERVE1=$(echo "$RESERVES" | head -2 | tail -1)
  
  MY_TOKEN0=$(echo "scale=0; $RESERVE0 * $LP_BALANCE / $TOTAL_SUPPLY" | bc)
  MY_TOKEN1=$(echo "scale=0; $RESERVE1 * $LP_BALANCE / $TOTAL_SUPPLY" | bc)
  
  echo "LP Balance: $LP_BALANCE ($SHARE_PCT% of pool)"
  echo "Your share: $MY_TOKEN0 token0 + $MY_TOKEN1 token1"
fi
```

---

## 6. Impermanent Loss Awareness

The Agent MUST inform the user about impermanent loss (IL) risk when adding liquidity.

### IL Reference Table

| Price Change | Impermanent Loss |
|-------------|-----------------|
| 1.25x | 0.6% |
| 1.50x | 2.0% |
| 1.75x | 3.8% |
| 2x | 5.7% |
| 3x | 13.4% |
| 5x | 25.5% |
| 10x | 42.5% |

### IL Formula (for reference)

```
IL = 2 * sqrt(priceRatio) / (1 + priceRatio) - 1
```

### Warning Triggers

- **Always** mention IL when user adds liquidity
- If the pool contains volatile tokens or the pair is newly created, emphasize the risk
- Suggest that stablecoin pairs (e.g., USDC/USDT) have minimal IL risk

---

## Error Handling

| Error | Signature | Handling |
|-------|-----------|----------|
| Insufficient tokenA allowance | `transfer amount exceeds allowance` | Prompt to approve tokenA |
| Insufficient tokenB allowance | `transfer amount exceeds allowance` | Prompt to approve tokenB |
| Insufficient ETH | `msg.value < amountETHMin` | Show required ETH vs balance |
| Insufficient token balance | `transfer amount exceeds balance` | Show balance and shortfall |
| Output below minimum | `INSUFFICIENT_A_AMOUNT` / `INSUFFICIENT_B_AMOUNT` | Increase slippage tolerance |
| Pool not found | `0x0` from Factory | Pool must be created first |
| LP allowance missing | `transfer amount exceeds allowance` | Approve PAIR for Router |
