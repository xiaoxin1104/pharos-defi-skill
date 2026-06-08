#!/usr/bin/env bash
# ============================================================
# pharos-defi 閳=Pool Yield Analyzer
# Usage: ./yield.sh [network] [pair_address]
# ============================================================
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

RPC_URL=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .rpcUrl" "$SKILL_DIR/assets/networks.json")
FACTORY=$(jq -r ".networks[\"$NETWORK\"].factory" "$SKILL_DIR/assets/dex.json")
WETH=$(jq -r ".networks[\"$NETWORK\"].weth" "$SKILL_DIR/assets/dex.json")

get_token_symbol() {
    local ADDR=$1
    jq -r ".tokens[\"$NETWORK\"][] | select(.address==\"$ADDR\") | .symbol" "$SKILL_DIR/assets/tokens.json" 2>/dev/null || echo "${ADDR:0:6}..."
}

format_eth() {
    echo "scale=4; $1 / 1000000000000000000" | bc
}

echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳={NC}"
echo -e "${CYAN}  Pharos DeFi 閳=Pool Yield Analyzer${NC}"
echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳={NC}"
echo -e "  Network: ${GREEN}$NETWORK${NC}"
echo ""

if [ -n "$PAIR_INPUT" ]; then
    # Analyze specific pair
    PAIR_ADDR="$PAIR_INPUT"

    # Verify it''s a contract
    CODE=$(cast code "$PAIR_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$CODE" = "0x" ]; then
        echo -e "${RED}Address $PAIR_ADDR is not a contract${NC}"
        exit 1
    fi

    # Get pair info
    TOKEN0=$(cast call "$PAIR_ADDR" "token0()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    TOKEN1=$(cast call "$PAIR_ADDR" "token1()(address)" --rpc-url "$RPC_URL" 2>/dev/null)
    RESERVES=$(cast call "$PAIR_ADDR" "getReserves()(uint112,uint112,uint32)" --rpc-url "$RPC_URL" 2>/dev/null)
    R0=$(echo "$RESERVES" | sed -n ''1p'' | tr -d ''[:space:]'')
    R1=$(echo "$RESERVES" | sed -n ''2p'' | tr -d ''[:space:]'')
    TOTAL_SUPPLY=$(cast call "$PAIR_ADDR" "totalSupply()(uint256)" --rpc-url "$RPC_URL" 2>/dev/null)

    T0_SYMBOL=$(get_token_symbol "$TOKEN0")
    T1_SYMBOL=$(get_token_symbol "$TOKEN1")

    echo -e "${CYAN}[Pool: $T0_SYMBOL/$T1_SYMBOL]${NC}"
    echo -e "  Pair:   ${BLUE}$PAIR_ADDR${NC}"
    echo -e "  Token0: $TOKEN0 ($T0_SYMBOL)"
    echo -e "  Token1: $TOKEN1 ($T1_SYMBOL)"
    echo -e "  Reserve0: $R0"
    echo -e "  Reserve1: $R1"
    echo -e "  LP Supply: $TOTAL_SUPPLY"
    echo ""

    # Estimate APR (qualitative 閳=based on pool characteristics)
    echo -e "${CYAN}[Yield Analysis]${NC}"

    # Pool health check
    if [ "$R0" = "0" ] || [ "$R1" = "0" ]; then
        echo -e "  ${RED}閳=Pool is empty 閳=no liquidity${NC}"
        echo ""
        exit 0
    fi

    # Determine pool type for risk assessment
    IS_STABLE_PAIR=false
    if [ "$T0_SYMBOL" = "USDC" ] || [ "$T0_SYMBOL" = "USDT" ]; then
        if [ "$T1_SYMBOL" = "USDC" ] || [ "$T1_SYMBOL" = "USDT" ]; then
            IS_STABLE_PAIR=true
        fi
    fi

    HAS_NATIVE=$(echo "$T0_SYMBOL $T1_SYMBOL" | grep -qE "PHRS|PROS|WPHRS|WPROS" && echo true || echo false)

    # Risk and yield assessment
    echo "  閳瑰备鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞=
    if $IS_STABLE_PAIR; then
        echo -e "  閳=${GREEN}Pool Type:    Stable/Stable${NC}          閳=
        echo -e "  閳=${GREEN}IL Risk:      Very Low (<1%)${NC}         閳=
        echo -e "  閳=${GREEN}Est. APR:     2-5%${NC}                    閳=
        echo -e "  閳=${GREEN}Risk-Adj APR: 2-5% 閴={NC}                  閳=
        echo -e "  閳=${GREEN}Recommend:    Safe yield, low return${NC}  閳=
    elif [ "$HAS_NATIVE" = "true" ]; then
        echo -e "  閳=${YELLOW}Pool Type:    Native/Stable${NC}           閳=
        echo -e "  閳=${YELLOW}IL Risk:      Medium (5-15%)${NC}          閳=
        echo -e "  閳=${YELLOW}Est. APR:     10-25%${NC}                  閳=
        echo -e "  閳=${YELLOW}Risk-Adj APR: 5-15%${NC}                   閳=
        echo -e "  閳=${YELLOW}Recommend:    Balanced risk/reward${NC}    閳=
    else
        echo -e "  閳=${RED}Pool Type:    Volatile/Volatile${NC}         閳=
        echo -e "  閳=${RED}IL Risk:      High (15-30%+)${NC}            閳=
        echo -e "  閳=${RED}Est. APR:     20-40%${NC}                    閳=
        echo -e "  閳=${RED}Risk-Adj APR: -10 to 25%${NC}               閳=
        echo -e "  閳=${RED}Recommend:    High risk 閳=caution${NC}       閳=
    fi
    echo "  閳规壕鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞=

    # Fee tracking via k-value
    # k = reserve0 * reserve1
    K_CURRENT=$(echo "scale=0; $R0 * $R1" | bc)
    K_MILLIONS=$(echo "scale=2; $K_CURRENT / 1000000000000000000 / 1000000000000000000" | bc)

    echo -e "  閳=${BLUE}k-value:     $(echo "scale=2; sqrt($K_CURRENT) / 10^18" | bc)${NC}"
    echo -e "  閳=${BLUE}Price:       1 $T0_SYMBOL = $(echo "scale=4; $R1 / $R0" | bc) $T1_SYMBOL${NC}"

    # TVL approximation (rough)
    TVL_APPROX=$(echo "scale=0; sqrt($K_CURRENT) * 2" | bc)
    echo -e "  閳=${BLUE}TVL (approx):$(echo "scale=2; $TVL_APPROX / 10^18" | bc)${NC}"
    echo "  閳规柡鏀㈤埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞鈧埞=

    # IL reference
    echo ""
    echo -e "${CYAN}[Impermanent Loss Reference]${NC}"
    echo "  Price Change     IL"
    echo "  閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓閳光偓"
    echo "  1.25x            0.6%"
    echo "  1.50x            2.0%"
    echo "  2x               5.7%"
    echo "  3x              13.4%"
    echo "  5x              25.5%"
    echo "  10x             42.5%"

else
    # Scan all pools from token list
    echo -e "${CYAN}[Scanning all known pools...]${NC}"
    echo ""

    TOKEN_ADDRS=($(jq -r ".tokens[\"$NETWORK\"][].address" "$SKILL_DIR/assets/tokens.json" 2>/dev/null))
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

            if [ "$PAIR" != "0x0000000000000000000000000000000000000000" ] && [ -n "$PAIR" ]; then
                POOL_COUNT=$((POOL_COUNT + 1))

                # Quick analysis
                RESERVES=$(cast call "$PAIR" "getReserves()(uint112,uint112,uint32)" --rpc-url "$RPC_URL" 2>/dev/null)
                R0=$(echo "$RESERVES" | sed -n ''1p'' | tr -d ''[:space:]'')
                R1=$(echo "$RESERVES" | sed -n ''2p'' | tr -d ''[:space:]'')

                T0_SYM=$(get_token_symbol "$TA")
                T1_SYM=$(get_token_symbol "$TB")

                # Determine risk level
                if [ "$T0_SYM" = "USDC" ] || [ "$T0_SYM" = "USDT" ]; then
                    if [ "$T1_SYM" = "USDC" ] || [ "$T1_SYM" = "USDT" ]; then
                        RISK="${GREEN}Low${NC}"
                    else
                        RISK="${YELLOW}Med${NC}"
                    fi
                elif [[ "$T0_SYM" =~ PHRS|PROS|WPHRS|WPROS ]] || [[ "$T1_SYM" =~ PHRS|PROS|WPHRS|WPROS ]]; then
                    RISK="${YELLOW}Med${NC}"
                else
                    RISK="${RED}High${NC}"
                fi

                K_VAL=$(echo "scale=2; sqrt($R0 * $R1) / 10^18" | bc)
                printf "  %2d. %-12s/%-12s   k=%-10s risk=%-6b %s\n" \
                    "$POOL_COUNT" "$T0_SYM" "$T1_SYM" "$K_VAL" "$RISK" "$PAIR"
            fi
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
echo -e "${GREEN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳={NC}"
echo -e "${GREEN}  Yield Analysis Complete 閴={NC}"
echo -e "${GREEN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳={NC}"
