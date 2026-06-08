#!/usr/bin/env bash
# ============================================================
# pharos-defi — Contract Discovery
# Checks which DEX contracts are deployed on the target network
# Usage: ./discover.sh [network]
# ============================================================
set -euo pipefail

GREEN='\''\033[0;32m'\'''
YELLOW='\''\033[1;33m'\'''
RED='\''\033[0;31m'\'''
CYAN='\''\033[0;36m'\'''
NC='\''\033[0m'\'''

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"

RPC_URL=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .rpcUrl" "$SKILL_DIR/assets/networks.json")
CHAIN_ID=$(jq -r ".networks[] | select(.name==\"$NETWORK\") | .chainId" "$SKILL_DIR/assets/networks.json")

echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "${CYAN}  Pharos DeFi — Contract Discovery${NC}"
echo -e "${CYAN}═══════════════════════════════════════════${NC}"
echo -e "  Network: ${GREEN}$NETWORK${NC} (chain $CHAIN_ID)"
echo ""

# ─── Check DEX contracts from dex.json ─────────────────────
echo -e "${CYAN}[DEX Contracts]${NC}"
echo "  Checking from assets/dex.json..."
echo ""

DEX_CONFIG=$(jq -r ".networks[\"$NETWORK\"]" "$SKILL_DIR/assets/dex.json")

check_contract() {
    local NAME=$1 ADDR=$2
    if [ "$ADDR" = "0x0000000000000000000000000000000000000000" ]; then
        printf "  %-20s ${YELLOW}Not configured (0x0)${NC}\n" "$NAME"
        return
    fi

    local CODE=$(cast code "$ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0x")
    if [ "$CODE" = "0x" ] || [ ${#CODE} -le 4 ]; then
        printf "  %-20s ${RED}Not deployed${NC}        %s\n" "$NAME" "$ADDR"
    else
        printf "  %-20s ${GREEN}✓ Deployed${NC}          %s (%d bytes)\n" "$NAME" "$ADDR" $((${#CODE} / 2 - 1))
    fi
}

check_contract "Factory" "$(echo "$DEX_CONFIG" | jq -r ''.factory'')"
check_contract "Router02" "$(echo "$DEX_CONFIG" | jq -r ''.router'')"
check_contract "WETH" "$(echo "$DEX_CONFIG" | jq -r ''.weth'')"
check_contract "Permit2" "$(echo "$DEX_CONFIG" | jq -r ''.permit2'')"
check_contract "Multicall" "$(echo "$DEX_CONFIG" | jq -r ''.multicall'')"

echo ""

# ─── Check tokens from tokens.json ─────────────────────────
echo -e "${CYAN}[Token Contracts]${NC}"
echo "  Checking from assets/tokens.json..."
echo ""

TOKENS=$(jq -c ".tokens[\"$NETWORK\"][]" "$SKILL_DIR/assets/tokens.json" 2>/dev/null)
echo "$TOKENS" | while read -r token; do
    SYMBOL=$(echo "$token" | jq -r ''.symbol'')
    TYPE=$(echo "$token" | jq -r ''.type'')
    ADDR=$(echo "$token" | jq -r ''.address'')

    if [ "$TYPE" = "native" ]; then
        printf "  %-12s ${CYAN}[native token]${NC}\n" "$SYMBOL"
        continue
    fi

    check_contract "$SYMBOL" "$ADDR"
done

echo ""

# ─── Check other useful contracts ──────────────────────────
echo -e "${CYAN}[Other Infrastructure]${NC}"
echo ""

# Common precompile/system addresses
declare -A SYSTEM_CONTRACTS=(
    ["WETH (standard)"]="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    ["WETH (L2 predeploy)"]="0x4200000000000000000000000000000000000006"
    ["UniversalRouter"]="0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD"
    ["Permit2"]="0x000000000022D473030F116dDEE9F6B43aC78BA3"
)

for name in "${!SYSTEM_CONTRACTS[@]}"; do
    check_contract "$name" "${SYSTEM_CONTRACTS[$name]}"
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}  Discovery Complete ✓${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"
echo ""
echo -e "  ${YELLOW}Tip:${NC} When new contracts are deployed, update assets/dex.json"
echo -e "  and assets/tokens.json, then rerun this script."
