#!/usr/bin/env bash
# ============================================================
# pharos-defi 閳=Automated Token Swap
# Usage: ./swap.sh <network> <token_in> <token_out> <amount> [slippage]
# Example: ./swap.sh atlantic-testnet PHRS USDC 1.0 0.5
# ============================================================
set -euo pipefail

NETWORK="${1:-atlantic-testnet}"
TOKEN_IN_SYMBOL="${2:-}"
TOKEN_OUT_SYMBOL="${3:-}"
AMOUNT_HUMAN="${4:-}"
SLIPPAGE="${5:-0.5}"
RECIPIENT="${RECIPIENT_ADDR:-}"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# 閳光偓閳光偓閳光偓 Load Config 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
RPC_URL=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .rpcUrl" "$SKILL_DIR/assets/networks.json")
ROUTER=$(jq -r ".networks[\"$NETWORK\"].router" "$SKILL_DIR/assets/dex.json")
WETH=$(jq -r ".networks[\"$NETWORK\"].weth" "$SKILL_DIR/assets/dex.json")
FACTORY=$(jq -r ".networks[\"$NETWORK\"].factory" "$SKILL_DIR/assets/dex.json")
NATIVE=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .nativeToken" "$SKILL_DIR/assets/networks.json")
CHAIN_ID=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .chainId" "$SKILL_DIR/assets/networks.json")

# 閳光偓閳光偓閳光偓 Resolve Token Address 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
resolve_token() {
    local SYMBOL=$1
    # Check tokens.json for the symbol
    local ADDR=$(jq -r ".tokens[\"$NETWORK\"][] | select(.symbol==\"$SYMBOL\") | .address" "$SKILL_DIR/assets/tokens.json" 2>/dev/null || echo "")
    if [ -z "$ADDR" ] || [ "$ADDR" = "null" ]; then
        ADDR=$(jq -r ".tokens[\"$NETWORK\"][] | select(.symbol==\"$SYMBOL\") | .address" "$SKILL_DIR/assets/tokens.json")
    fi
    echo "$ADDR"
}

get_decimals() {
    local SYMBOL=$1
    if [ "$SYMBOL" = "$NATIVE" ]; then echo 18; return; fi
    jq -r ".tokens[\"$NETWORK\"][] | select(.symbol==\"$SYMBOL\") | .decimals" "$SKILL_DIR/assets/tokens.json"
}

to_wei() {
    local AMOUNT=$1 DECIMALS=$2
    echo "scale=0; $AMOUNT * 10^$DECIMALS / 1" | bc
}

from_wei() {
    local AMOUNT=$1 DECIMALS=$2
    echo "scale=6; $AMOUNT / 10^$DECIMALS" | bc
}

# 閳光偓閳光偓閳光偓 Validate Inputs 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
if [ -z "$TOKEN_IN_SYMBOL" ] || [ -z "$TOKEN_OUT_SYMBOL" ] || [ -z "$AMOUNT_HUMAN" ]; then
    echo -e "${RED}Usage: $0 <network> <token_in> <token_out> <amount> [slippage]${NC}"
    echo -e "${CYAN}Example: $0 atlantic-testnet PHRS USDC 10.0 0.5${NC}"
    exit 1
fi

echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
echo -e "${CYAN}  Pharos DeFi 閳=Token Swap${NC}"
echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
echo -e "  Network:  ${GREEN}$NETWORK${NC} (chain $CHAIN_ID)"
echo -e "  From:     ${YELLOW}$AMOUNT_HUMAN $TOKEN_IN_SYMBOL${NC}"
echo -e "  To:       ${YELLOW}$TOKEN_OUT_SYMBOL${NC}"
echo -e "  Slippage: ${YELLOW}$SLIPPAGE%${NC}"
echo ""

# 閳光偓閳光偓閳光偓 Resolve Addresses 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
TOKEN_IN=$(resolve_token "$TOKEN_IN_SYMBOL")
TOKEN_OUT=$(resolve_token "$TOKEN_OUT_SYMBOL")

# Handle native token
IS_NATIVE_IN=false
if [ "$TOKEN_IN_SYMBOL" = "$NATIVE" ] || [ "$TOKEN_IN_SYMBOL" = "ETH" ]; then
    IS_NATIVE_IN=true
    TOKEN_IN=$WETH
fi
IS_NATIVE_OUT=false
if [ "$TOKEN_OUT_SYMBOL" = "$NATIVE" ] || [ "$TOKEN_OUT_SYMBOL" = "ETH" ]; then
    IS_NATIVE_OUT=true
    TOKEN_OUT=$WETH
fi

DECIMALS_IN=$(get_decimals "$TOKEN_IN_SYMBOL")
DECIMALS_OUT=$(get_decimals "$TOKEN_OUT_SYMBOL")
AMOUNT_WEI=$(to_wei "$AMOUNT_HUMAN" "$DECIMALS_IN")

echo -e "  TokenIn:  $TOKEN_IN"
echo -e "  TokenOut: $TOKEN_OUT"
echo -e "  Amount:   $AMOUNT_WEI (wei)"
echo ""

# 閳光偓閳光偓閳光偓 Find Path 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
DIRECT=$(cast call "$FACTORY" "getPair(address,address)(address)" "$TOKEN_IN" "$TOKEN_OUT" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")

if [ "$DIRECT" != "0x0000000000000000000000000000000000000000" ]; then
    PATH="[$TOKEN_IN,$TOKEN_OUT]"
    echo -e "  ${GREEN}閴=Direct pair found${NC}"
else
    PATH="[$TOKEN_IN,$WETH,$TOKEN_OUT]"
    echo -e "  ${YELLOW}閳=No direct pair, routing via WETH${NC}"
fi

# 閳光偓閳光偓閳光偓 Get Quote 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
echo -e "  ${CYAN}Getting quote...${NC}"
QUOTE=$(cast call "$ROUTER" "getAmountsOut(uint256,address[])(uint256[])" "$AMOUNT_WEI" "$PATH" --rpc-url "$RPC_URL" 2>/dev/null)
EXPECTED_OUT=$(echo "$QUOTE" | sed -n '$p' | tr -d '[:space:]')

if [ -z "$EXPECTED_OUT" ] || [ "$EXPECTED_OUT" = "0" ]; then
    echo -e "${RED}閴=Quote failed 閳=pair may not exist or amount too large${NC}"
    exit 1
fi

EXPECTED_HUMAN=$(from_wei "$EXPECTED_OUT" "$DECIMALS_OUT")
echo -e "  Expected: ${GREEN}$EXPECTED_HUMAN $TOKEN_OUT_SYMBOL${NC}"

# 閳光偓閳光偓閳光偓 Calculate Slippage 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
AMOUNT_OUT_MIN=$(echo "scale=0; $EXPECTED_OUT * (100 - $SLIPPAGE) / 100" | bc)
MIN_HUMAN=$(from_wei "$AMOUNT_OUT_MIN" "$DECIMALS_OUT")
echo -e "  Min out:  ${YELLOW}$MIN_HUMAN $TOKEN_OUT_SYMBOL${NC} ($SLIPPAGE% slippage)"

# 閳光偓閳光偓閳光偓 Deadline 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
DEADLINE=$(($(date +%s) + 1200))

# 閳光偓閳光偓閳光偓 Get Recipient 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
if [ -z "$RECIPIENT" ]; then
    RECIPIENT=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)
fi

# 閳光偓閳光偓閳光偓 Pre-flight Checks 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
echo ""
echo -e "${CYAN}Pre-flight checks...${NC}"

# Check PRIVATE_KEY
if [ -z "${PRIVATE_KEY:-}" ]; then
    echo -e "${RED}閴=PRIVATE_KEY not set. Run: export PRIVATE_KEY=<your_key>${NC}"
    exit 1
fi

USER_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)

# Network warning
if [ "$NETWORK" = "mainnet" ]; then
    echo -e "${RED}閳=WARNING: Operating on MAINNET with real funds!${NC}"
    read -p "Type ''yes'' to confirm: " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then echo "Aborted."; exit 1; fi
else
    echo -e "  ${GREEN}閴=Testnet (safe)${NC}"
fi

# Balance check
if $IS_NATIVE_IN; then
    BALANCE=$(cast balance "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
else
    BALANCE=$(cast call "$TOKEN_IN" "balanceOf(address)(uint256)" "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
fi
BALANCE_HUMAN=$(from_wei "$BALANCE" "$DECIMALS_IN")
echo -e "  Balance:  ${GREEN}$BALANCE_HUMAN $TOKEN_IN_SYMBOL${NC}"

if [ "$BALANCE" -lt "$AMOUNT_WEI" ]; then
    echo -e "${RED}閴=Insufficient balance!${NC}"
    exit 1
fi

# 閳光偓閳光偓閳光偓 Allowance (ERC-20 only) 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
if ! $IS_NATIVE_IN; then
    ALLOWANCE=$(cast call "$TOKEN_IN" "allowance(address,address)(uint256)" "$USER_ADDR" "$ROUTER" --rpc-url "$RPC_URL" 2>/dev/null)
    if [ "$ALLOWANCE" -lt "$AMOUNT_WEI" ]; then
        echo -e "  ${YELLOW}Approving $TOKEN_IN for Router...${NC}"
        cast send "$TOKEN_IN" "approve(address,uint256)(bool)" "$ROUTER" "$AMOUNT_WEI" \
            --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --legacy 2>/dev/null
        echo -e "  ${GREEN}閴=Approved${NC}"
    fi
fi

# 閳光偓閳光偓閳光偓 Execute Swap 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
echo ""
echo -e "${CYAN}Executing swap...${NC}"

if $IS_NATIVE_IN && $IS_NATIVE_OUT; then
    echo -e "${RED}Cannot swap native to native${NC}"; exit 1
elif $IS_NATIVE_IN; then
    TX=$(cast send "$ROUTER" \
        "swapExactETHForTokens(uint256,address[],address,uint256)" \
        "$AMOUNT_OUT_MIN" "$PATH" "$RECIPIENT" "$DEADLINE" \
        --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --value "$AMOUNT_WEI" --legacy 2>&1)
elif $IS_NATIVE_OUT; then
    TX=$(cast send "$ROUTER" \
        "swapExactTokensForETH(uint256,uint256,address[],address,uint256)" \
        "$AMOUNT_WEI" "$AMOUNT_OUT_MIN" "$PATH" "$RECIPIENT" "$DEADLINE" \
        --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --legacy 2>&1)
else
    TX=$(cast send "$ROUTER" \
        "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
        "$AMOUNT_WEI" "$AMOUNT_OUT_MIN" "$PATH" "$RECIPIENT" "$DEADLINE" \
        --private-key "$PRIVATE_KEY" --rpc-url "$RPC_URL" --legacy 2>&1)
fi

TX_HASH=$(echo "$TX" | grep -oP 'transactionHash.*=\K0x[a-fA-F0-9]{64}' || echo "$TX" | grep -oP '0x[a-fA-F0-9]{64}' | head -1)

if [ -z "$TX_HASH" ]; then
    echo -e "${RED}閴=Swap failed:${NC}"
    echo "$TX"
    exit 1
fi

echo -e "${GREEN}閴=Swap executed!${NC}"
echo -e "  TX: ${CYAN}$TX_HASH${NC}"
echo ""

# 閳光偓閳光偓閳光偓 Post-Swap Report 閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓
echo -e "${CYAN}Post-swap report:${NC}"

# New balances
if $IS_NATIVE_IN; then
    NEW_NATIVE=$(cast balance "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
    echo -e "  $NATIVE:     $(from_wei "$NEW_NATIVE" 18)"
fi
if $IS_NATIVE_OUT; then
    NEW_NATIVE=$(cast balance "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
    echo -e "  $NATIVE:     $(from_wei "$NEW_NATIVE" 18)"
fi
if ! $IS_NATIVE_IN; then
    NEW_IN=$(cast call "$TOKEN_IN" "balanceOf(address)(uint256)" "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
    echo -e "  $TOKEN_IN_SYMBOL:      $(from_wei "$NEW_IN" "$DECIMALS_IN")"
fi
if ! $IS_NATIVE_OUT; then
    NEW_OUT=$(cast call "$TOKEN_OUT" "balanceOf(address)(uint256)" "$USER_ADDR" --rpc-url "$RPC_URL" 2>/dev/null)
    echo -e "  $TOKEN_OUT_SYMBOL:      $(from_wei "$NEW_OUT" "$DECIMALS_OUT")"
fi

echo ""
echo -e "${GREEN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
echo -e "${GREEN}  Swap Complete 閴={NC}"
echo -e "${GREEN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
