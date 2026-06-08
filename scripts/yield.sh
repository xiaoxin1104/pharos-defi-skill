#!/usr/bin/env bash
# pharos-defi ? Pool Yield Analyzer
set -euo pipefail

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BLUE=$'\033[0;34m'
RED=$'\033[0;31m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"
PAIR_INPUT="${2:-}"

RPC_URL=$(jq -r '.networks[] | select(.name=="'"$NETWORK"'") | .rpcUrl' "$SKILL_DIR/assets/networks.json")
FACTORY=$(jq -r '.networks["'"$NETWORK"'"].factory' "$SKILL_DIR/assets/dex.json")
WETH=$(jq -r '.networks["'"$NETWORK"'"].weth' "$SKILL_DIR/assets/dex.json")

get_token_symbol() {
    jq -r '.tokens["'"$NETWORK"'"][] | select(.address=="'"$1"'") | .symbol' "$SKILL_DIR/assets/tokens.json" 2>/dev/null || echo "${1:0:6}..."
}

echo -e "${CYAN}===========================================${NC}"
echo -e "${CYAN}  Pharos DeFi -- Pool Yield Analyzer${NC}"
echo -e "${CYAN}===========================================${NC}"
echo -e "  Network: ${GREEN}$NETWORK${NC}"
echo ""

if [ -n "$PAIR_INPUT" ]; then
    PAIR_ADDR="$PAIR_INPUT"

    CODE=$(cast code "$PAIR_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$CODE" = "0x" ]; then
        echo -e "${RED}Address $PAIR_ADDR is not a contract${NC}"
        exit 1
    fi

    TOKEN0=$(cast call "$PAIR_ADDR" "token0()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    TOKEN1=$(cast call "$PAIR_ADDR" "token1()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    RESERVES=$(cast call "$PAIR_ADDR" "getReserves()(uint112,uint112,uint32)" --rpc-url "$RPC_URL" 2>/dev/null)
    R0=$(echo "$RESERVES" | sed -n '1p' | tr -d '[:space:]')
    R1=$(echo "$RESERVES" | sed -n '2p' | tr -d '[:space:]')
    TOTAL_SUPPLY=$(cast call "$PAIR_ADDR" "totalSupply()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null)

    T0_SYMBOL=$(get_token_symbol "$TOKEN0")
    T1_SYMBOL=$(get_token_symbol "$TOKEN1")

    echo -e "${CYAN}[Pool: $T0_SYMBOL/$T1_SYMBOL]${NC}"
    echo -e "  Pair:   ${BLUE}$PAIR_ADDR${NC}"
    echo -e "  Token0: $T0_SYMBOL"
    echo -e "  Token1: $T1_SYMBOL"
    echo -e "  Reserve0: $R0"
    echo -e "  Reserve1: $R1"
    echo -e "  LP Supply: $TOTAL_SUPPLY"
    echo ""

    echo -e "${CYAN}[Yield Analysis]${NC}"

    if [ "$R0" = "0" ] || [ "$R1" = "0" ]; then
        echo -e "  ${RED}[WARN] Pool is empty -- no liquidity${NC}"
        exit 0
    fi

    IS_STABLE_PAIR=false
    if [ "$T0_SYMBOL" = "USDC" ] || [ "$T0_SYMBOL" = "USDT" ]; then
        if [ "$T1_SYMBOL" = "USDC" ] || [ "$T1_SYMBOL" = "USDT" ]; then
            IS_STABLE_PAIR=true
        fi
    fi
    HAS_NATIVE=$(echo "$T0_SYMBOL $T1_SYMBOL" | grep -qE "PHRS|PROS|WPHRS|WPROS" && echo true || echo false)

    echo "  -------------------------------------------------"
    if $IS_STABLE_PAIR; then
        echo -e "  | ${GREEN}Pool Type:    Stable/Stable${NC}            |"
        echo -e "  | ${GREEN}IL Risk:      Very Low (<1%)${NC}           |"
        echo -e "  | ${GREEN}Est. APR:     2-5%${NC}                      |"
        echo -e "  | ${GREEN}Recommend:    Safe yield, low return${NC}   |"
    elif [ "$HAS_NATIVE" = "true" ]; then
        echo -e "  | ${YELLOW}Pool Type:    Native/Stable${NC}            |"
        echo -e "  | ${YELLOW}IL Risk:      Medium (5-15%)${NC}           |"
        echo -e "  | ${YELLOW}Est. APR:     10-25%${NC}                   |"
        echo -e "  | ${YELLOW}Recommend:    Balanced risk/reward${NC}     |"
    else
        echo -e "  | ${RED}Pool Type:    Volatile/Volatile${NC}          |"
        echo -e "  | ${RED}IL Risk:      High (15-30%+)${NC}             |"
        echo -e "  | ${RED}Recommend:    High risk -- caution${NC}       |"
    fi

    K_CURRENT=$(echo "scale=0; $R0 * $R1" | bc 2>/dev/null || echo "0")
    PRICE=$(echo "scale=4; $R1 / $R0" | bc 2>/dev/null || echo "0")
    echo -e "  | ${BLUE}Price:       1 $T0_SYMBOL = $PRICE $T1_SYMBOL${NC}"
    echo "  -------------------------------------------------"

    echo ""
    echo -e "${CYAN}[Impermanent Loss Reference]${NC}"
    echo "  Price Change     IL"
    echo "  ---------------------"
    echo "  1.25x            0.6%"
    echo "  1.50x            2.0%"
    echo "  2x               5.7%"
    echo "  3x              13.4%"
    echo "  5x              25.5%"
    echo "  10x             42.5%"

else
    echo -e "${CYAN}[Scanning all known pools...]${NC}"
    echo ""

    TOKEN_ADDRS=($(jq -r '.tokens["'"$NETWORK"'"][].address' "$SKILL_DIR/assets/tokens.json" 2>/dev/null))
    TOKEN_ADDRS+=("$WETH")

    POOL_COUNT=0
    for ((i=0; i<${#TOKEN_ADDRS[@]}; i++)); do
        for ((j=i+1; j<${#TOKEN_ADDRS[@]}; j++)); do
            TA="${TOKEN_ADDRS[$i]}"
            TB="${TOKEN_ADDRS[$j]}"
            [[ ! "$TA" =~ ^0x[a-fA-F0-9]{40}$ ]] && continue
            [[ ! "$TB" =~ ^0x[a-fA-F0-9]{40}$ ]] && continue
            [ "$TA" = "$TB" ] && continue

            PAIR=$(cast call "$FACTORY" "getPair(address,address)(address)" "$TA" "$TB" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x0")
            [ "$PAIR" = "0x0000000000000000000000000000000000000000" ] && continue

            POOL_COUNT=$((POOL_COUNT + 1))
            T0_SYM=$(get_token_symbol "$TA")
            T1_SYM=$(get_token_symbol "$TB")

            if [ "$T0_SYM" = "USDC" ] || [ "$T0_SYM" = "USDT" ]; then
                [ "$T1_SYM" = "USDC" ] || [ "$T1_SYM" = "USDT" ] && RISK="${GREEN}Low${NC}" || RISK="${YELLOW}Med${NC}"
            elif [[ "$T0_SYM" =~ PHRS|PROS|WPHRS|WPROS ]] || [[ "$T1_SYM" =~ PHRS|PROS|WPHRS|WPROS ]]; then
                RISK="${YELLOW}Med${NC}"
            else
                RISK="${RED}High${NC}"
            fi

            printf "  %2d. %-12s/%-12s risk=%-6b %s\n" "$POOL_COUNT" "$T0_SYM" "$T1_SYM" "$RISK" "$PAIR"
        done
    done

    if [ "$POOL_COUNT" -eq 0 ]; then
        echo -e "  ${YELLOW}No pools found from token registry.${NC}"
        echo -e "  ${YELLOW}Pools will appear once DEX contracts are deployed.${NC}"
        echo ""
        echo -e "  To analyze a specific pool: ${GREEN}$0 $NETWORK <pair_address>${NC}"
    else
        echo ""
        echo -e "${GREEN}Found $POOL_COUNT pool(s).${NC}"
        echo -e "For detailed analysis: ${GREEN}$0 $NETWORK <pair_address>${NC}"
    fi
fi

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  Yield Analysis Complete [OK]${NC}"
echo -e "${GREEN}===========================================${NC}"
