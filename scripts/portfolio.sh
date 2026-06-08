#!/usr/bin/env bash
# pharos-defi ? Portfolio Overview
set -euo pipefail

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"
TARGET_ADDR="${2:-}"

RPC_URL=$(jq -r '.networks[] | select(.name=="'"$NETWORK"'") | .rpcUrl' "$SKILL_DIR/assets/networks.json")
FACTORY=$(jq -r '.networks["'"$NETWORK"'"].factory' "$SKILL_DIR/assets/dex.json")
WETH=$(jq -r '.networks["'"$NETWORK"'"].weth' "$SKILL_DIR/assets/dex.json")
NATIVE=$(jq -r '.networks[] | select(.name=="'"$NETWORK"'") | .nativeToken' "$SKILL_DIR/assets/networks.json")

if [ -z "$TARGET_ADDR" ]; then
    if [ -n "${PRIVATE_KEY:-}" ]; then
        TARGET_ADDR=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null)
    else
        echo "Usage: $0 <network> <address>"
        echo "  Or set PRIVATE_KEY for automatic address"
        exit 1
    fi
fi

echo -e "${CYAN}===========================================${NC}"
echo -e "${CYAN}  Pharos DeFi -- Portfolio Overview${NC}"
echo -e "${CYAN}===========================================${NC}"
echo -e "  Network: ${GREEN}$NETWORK${NC}"
echo -e "  Address: ${BLUE}$TARGET_ADDR${NC}"
echo ""

# Native Balance
NATIVE_BALANCE=$(cast balance "$TARGET_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
NATIVE_HUMAN=$(echo "scale=6; $NATIVE_BALANCE / 1000000000000000000" | bc 2>/dev/null || echo "0")
echo -e "${CYAN}[Native]${NC} $NATIVE: ${GREEN}$NATIVE_HUMAN${NC}"
echo ""

# Token Balances
echo -e "${CYAN}[Tokens]${NC}"
TOKENS=$(jq -r '.tokens["'"$NETWORK"'"]' "$SKILL_DIR/assets/tokens.json" 2>/dev/null)
if [ "$TOKENS" != "null" ] && [ -n "$TOKENS" ]; then
    TOKEN_COUNT=$(echo "$TOKENS" | jq 'length')
    for ((i=0; i<TOKEN_COUNT; i++)); do
        SYMBOL=$(echo "$TOKENS" | jq -r ".[$i].symbol")
        TYPE=$(echo "$TOKENS" | jq -r ".[$i].type")
        ADDR=$(echo "$TOKENS" | jq -r ".[$i].address")
        DECIMALS=$(echo "$TOKENS" | jq -r ".[$i].decimals")

        [ "$TYPE" = "native" ] && continue

        BALANCE=$(cast call "$ADDR" "balanceOf(address)(uint256)" "$TARGET_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        BALANCE=$(echo "$BALANCE" | tr -d '[:space:]')
        [ -z "$BALANCE" ] || [ "$BALANCE" = "0" ] && continue

        BALANCE_HUMAN=$(echo "scale=6; $BALANCE / 10^$DECIMALS" | bc 2>/dev/null || echo "0")
        printf "  %-8s %18s\n" "$SYMBOL" "$BALANCE_HUMAN"
    done
fi
echo ""

# LP Positions
echo -e "${CYAN}[LP Positions]${NC}"
TOKEN_LIST=()
if [ "$TOKENS" != "null" ]; then
    while IFS= read -r addr; do
        TOKEN_LIST+=("$addr")
    done < <(echo "$TOKENS" | jq -r '.[].address')
fi
TOKEN_LIST+=("$WETH")

LP_FOUND=0
for ((i=0; i<${#TOKEN_LIST[@]}; i++)); do
    for ((j=i+1; j<${#TOKEN_LIST[@]}; j++)); do
        TA="${TOKEN_LIST[$i]}"
        TB="${TOKEN_LIST[$j]}"
        [ "$TA" = "$TB" ] && continue
        [ "$TA" = "null" ] || [ "$TB" = "null" ] && continue

        PAIR=$(cast call "$FACTORY" "getPair(address,address)(address)" "$TA" "$TB" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0000000000000000000000000000000000000000")
        [ "$PAIR" = "0x0000000000000000000000000000000000000000" ] && continue

        LP_BAL=$(cast call "$PAIR" "balanceOf(address)(uint256)" "$TARGET_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")
        LP_BAL=$(echo "$LP_BAL" | tr -d '[:space:]')
        [ -z "$LP_BAL" ] || [ "$LP_BAL" = "0" ] && continue

        TOTAL_SUPPLY=$(cast call "$PAIR" "totalSupply()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null || echo "1")
        SHARE=$(echo "scale=4; $LP_BAL * 100 / $TOTAL_SUPPLY" | bc 2>/dev/null || echo "0")
        TOKEN0_ADDR=$(cast call "$PAIR" "token0()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
        T0_SYMBOL=$(echo "$TOKENS" | jq -r ".[] | select(.address==\"$TOKEN0_ADDR\") | .symbol" 2>/dev/null || echo "${TOKEN0_ADDR:0:6}...")
        T1_SYMBOL="token1"
        
        echo -e "  ${GREEN}$T0_SYMBOL / $T1_SYMBOL${NC} (${BLUE}$SHARE%${NC} share)"
        echo -e "    Pair:  ${BLUE}$PAIR${NC}"
        LP_FOUND=$((LP_FOUND + 1))
    done
done

[ "$LP_FOUND" -eq 0 ] && echo "  (no LP positions found)"

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  Portfolio Overview Complete [OK]${NC}"
echo -e "${GREEN}===========================================${NC}"
