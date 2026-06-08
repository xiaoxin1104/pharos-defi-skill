# Swap Operation Instructions

Detailed instructions for token swap operations on Pharos DEX using Uniswap V2-compatible Router contracts.

> **Network Configuration**: The `<rpc>` parameter is read from `assets/networks.json`. Defaults to Atlantic testnet.
> **Router Address**: Read `<router>` from `assets/dex.json` for the target network.
> **Token Addresses**: Resolve token symbols via `assets/tokens.json`. If a symbol is not found, treat it as a raw address.
> **Private Key**: All write operations require `--private-key $PRIVATE_KEY` (from `pharos-skill-engine`).

---

## Operations Index

| Section | Operation | Router Method |
|---------|-----------|---------------|
| [1](#1-eth--token-swap) | ETH → Token swap | `swapExactETHForTokens` |
| [2](#2-token--eth-swap) | Token → ETH swap | `swapExactTokensForETH` |
| [3](#3-token--token-swap) | Token → Token swap | `swapExactTokensForTokens` |
| [4](#4-exact-output-swap) | Exact output swap | `swapTokensForExactETH` / `swapTokensForExactTokens` |
| [5](#5-post-swap-verification) | Post-swap verification | `cast receipt` + balance check |

---

## Agent Guidelines (Swap Operations)

### Pre-swap Flow (MANDATORY)

1. Resolve token addresses from `assets/tokens.json` (or treat input as raw address)
2. Get a quote via `getAmountsOut` (see `references/quote.md#getamountsout`)
3. Calculate `amountOutMin` with slippage (default 0.5%: `expectedOut * 0.995`)
4. Generate deadline: `$(date +%s) + 1200` (20 minutes)
5. Check token approval for ERC-20 tokens (NOT needed for native ETH)
6. Confirm swap details with user:
   - Input token + amount
   - Expected output token + minimum
   - Current price + slippage
   - Network (testnet/mainnet)
   - Gas estimate

---

## 1. ETH → Token Swap

Swap native currency (PHRS/PROS) for an ERC-20 token.

### Router Method
`swapExactETHForTokens(uint256 amountOutMin, address[] path, address to, uint256 deadline)`

### Step-by-Step

```bash
# 1. Load config
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

# 2. Resolve output token address (e.g., USDC from tokens.json)
TOKEN_OUT="<usdc_address>"

# 3. Get quote (see references/quote.md)
EXPECTED_OUT=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "[$WETH, $TOKEN_OUT]" --rpc-url $RPC_URL | tail -1)

# 4. Calculate min output with 0.5% slippage
AMOUNT_OUT_MIN=$(echo "$EXPECTED_OUT * 995 / 1000" | bc)

# 5. Set deadline (20 min from now)
DEADLINE=$(($(date +%s) + 1200))

# 6. Check ETH balance
NATIVE_TOKEN=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .nativeToken'' assets/networks.json)
BALANCE=$(cast balance <user_address> --rpc-url $RPC_URL)

# 7. Execute swap (value = amount_in_wei for native ETH)
cast send $ROUTER \
  "swapExactETHForTokens(uint256,address[],address,uint256)" \
  $AMOUNT_OUT_MIN "[$WETH, $TOKEN_OUT]" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL \
  --value <amount_in_wei>
```

### Parameters

| Param | Type | Description |
|-------|------|-------------|
| amountOutMin | uint256 | Minimum output tokens (with slippage) |
| path | address[] | Token path: [WETH, token_out] |
| to | address | Recipient address |
| deadline | uint256 | Unix timestamp deadline |

---

## 2. Token → ETH Swap

Swap an ERC-20 token for native currency.

### Router Method
`swapExactTokensForETH(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)`

### Step-by-Step

```bash
# 1. Load config (same as ETH→Token)

# 2. Check and set allowance FIRST
ALLOWANCE=$(cast call $TOKEN_IN "allowance(address,address)(uint256)" <user_address> $ROUTER --rpc-url $RPC_URL)

# 3. If allowance < amountIn, approve
if [ "$ALLOWANCE" -lt "<amount_in_wei>" ]; then
  cast send $TOKEN_IN "approve(address,uint256)(bool)" $ROUTER <amount_in_wei> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
fi

# 4. Get quote
EXPECTED_OUT=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "[$TOKEN_IN, $WETH]" --rpc-url $RPC_URL | tail -1)

# 5. Calculate min output with slippage
AMOUNT_OUT_MIN=$(echo "$EXPECTED_OUT * 995 / 1000" | bc)

# 6. Execute swap
cast send $ROUTER \
  "swapExactTokensForETH(uint256,uint256,address[],address,uint256)" \
  <amount_in_wei> $AMOUNT_OUT_MIN "[$TOKEN_IN, $WETH]" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 3. Token → Token Swap

Swap between two ERC-20 tokens. The path goes through WETH if no direct pair exists.

### Router Method
`swapExactTokensForTokens(uint256 amountIn, uint256 amountOutMin, address[] path, address to, uint256 deadline)`

### Path Construction

- **Direct pair exists**: `[tokenA, tokenB]` (verify via `Factory.getPair()`)
- **Via WETH**: `[tokenA, WETH, tokenB]` (always works since most tokens pair with WETH)

### Step-by-Step

```bash
# 1. Check if direct pair exists
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
PAIR=$(cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC_URL)

# 2. Build path
if [ "$PAIR" = "0x0000000000000000000000000000000000000000" ]; then
  # No direct pair, route via WETH
  PATH="[$TOKEN_A, $WETH, $TOKEN_B]"
else
  PATH="[$TOKEN_A, $TOKEN_B]"
fi

# 3. Check allowance & approve (same as Token→ETH)

# 4. Get quote
EXPECTED_OUT=$(cast call $ROUTER \
  "getAmountsOut(uint256,address[])(uint256[])" \
  <amount_in_wei> "$PATH" --rpc-url $RPC_URL | tail -1)

# 5. Calculate min with slippage
AMOUNT_OUT_MIN=$(echo "$EXPECTED_OUT * 995 / 1000" | bc)

# 6. Execute swap
cast send $ROUTER \
  "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
  <amount_in_wei> $AMOUNT_OUT_MIN "$PATH" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 4. Exact Output Swap

Swap the minimum input needed to receive an exact output amount. Useful for repaying debts or buying specific amounts.

### Token → ETH (exact output)

```bash
# Router: swapTokensForExactETH(uint256 amountOut, uint256 amountInMax, address[] path, address to, uint256 deadline)
cast send $ROUTER \
  "swapTokensForExactETH(uint256,uint256,address[],address,uint256)" \
  <exact_eth_out> <max_token_in> "[$TOKEN_IN, $WETH]" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

### Token → Token (exact output)

```bash
# Router: swapTokensForExactTokens(uint256 amountOut, uint256 amountInMax, address[] path, address to, uint256 deadline)
cast send $ROUTER \
  "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)" \
  <exact_token_out> <max_token_in> "$PATH" <recipient_address> $DEADLINE \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL
```

---

## 5. Post-Swap Verification

After every swap, verify the transaction and report results to the user.

```bash
# 1. Get transaction receipt
TX_HASH="<tx_hash_from_swap>"
cast receipt $TX_HASH --rpc-url $RPC_URL

# 2. Check new balances
NATIVE=$(cast balance <user_address> --rpc-url $RPC_URL)
TOKEN=$(cast call $TOKEN_OUT "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL)

# 3. Calculate actual rate
# actualRate = tokenReceived / tokenSpent (adjust for decimals)
```

### Verification Report Format

After each swap, report to the user:
- Transaction hash + explorer link
- Actual tokens received (human-readable, with decimals)
- Actual exchange rate (vs expected from quote)
- Gas used (from receipt)
- Remaining balances of affected tokens

---

## Error Handling (Swap Specific)

| Error | Signature | Handling |
|-------|-----------|----------|
| Insufficient allowance | `ds-math-sub-underflow` / `transfer amount exceeds allowance` | Prompt to approve Router |
| Slippage exceeded | `INSUFFICIENT_OUTPUT_AMOUNT` | Show expected vs min output, suggest higher slippage |
| Expired | `EXPIRED` | Regenerate deadline, retry |
| Same token | `IDENTICAL_ADDRESSES` | Check path — tokenA != tokenB |
| ETH sent with token swap | `msg.value > 0` for non-ETH method | Remove `--value` flag for token→token swaps |
| Missing `--value` | `msg.value < amount` for ETH swap | Add `--value <amount_in_wei>` for ETH→token swaps |
