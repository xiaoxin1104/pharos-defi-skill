#!/usr/bin/env bash
# pharos-defi ? Contract Discovery
set -euo pipefail

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"
RPC_URL=$(jq -r '.networks[] | select(.name=="'"$NETWORK"'") | .rpcUrl' "$SKILL_DIR/assets/networks.json")
CHAIN_ID=$(jq -r '.networks[] | select(.name=="'"$NETWORK"'") | .chainId' "$SKILL_DIR/assets/networks.json")

echo -e "${CYAN}===========================================${NC}"
echo -e "${CYAN}  Pharos DeFi -- Contract Discovery${NC}"
echo -e "${CYAN}===========================================${NC}"
echo -e "  Network: ${GREEN}$NETWORK${NC} (chain $CHAIN_ID)"
echo ""

# --- DEX Contracts ---
echo -e "${CYAN}[DEX Contracts]${NC}"
echo "  Checking from assets/dex.json..."
echo ""

DEX_CONFIG=$(jq -r '.networks["'"$NETWORK"'"]' "$SKILL_DIR/assets/dex.json")

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
        printf "  %-20s ${GREEN}[OK] Deployed${NC}      %s (%d bytes)\n" "$NAME" "$ADDR" $((${#CODE} / 2 - 1))
    fi
}

check_contract "Factory" "$(echo "$DEX_CONFIG" | jq -r '.factory')"
check_contract "Router02" "$(echo "$DEX_CONFIG" | jq -r '.router')"
check_contract "WETH" "$(echo "$DEX_CONFIG" | jq -r '.weth')"
check_contract "Permit2" "$(echo "$DEX_CONFIG" | jq -r '.permit2')"
check_contract "Multicall" "$(echo "$DEX_CONFIG" | jq -r '.multicall')"

echo ""

# --- Token Contracts ---
echo -e "${CYAN}[Token Contracts]${NC}"
echo "  Checking from assets/tokens.json..."
echo ""

TOKENS=$(jq -c '.tokens["'"$NETWORK"'"]' "$SKILL_DIR/assets/tokens.json" 2>/dev/null)
echo "$TOKENS" | jq -c '.[]' 2>/dev/null | while read -r token; do
    SYMBOL=$(echo "$token" | jq -r '.symbol')
    TYPE=$(echo "$token" | jq -r '.type')
    ADDR=$(echo "$token" | jq -r '.address')

    if [ "$TYPE" = "native" ]; then
        printf "  %-12s ${CYAN}[native token]${NC}\n" "$SYMBOL"
        continue
    fi
    check_contract "$SYMBOL" "$ADDR"
done

echo ""

# --- Other Infrastructure ---
echo -e "${CYAN}[Other Infrastructure]${NC}"
echo ""

check_contract "Permit2" "0x000000000022D473030F116dDEE9F6B43aC78BA3"
check_contract "UniversalRouter" "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD"
check_contract "WETH (standard)" "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
check_contract "WETH (L2 predeploy)" "0x4200000000000000000000000000000000000006"

echo ""
echo -e "${GREEN}===========================================${NC}"
echo -e "${GREEN}  Discovery Complete [OK]${NC}"
echo -e "${GREEN}===========================================${NC}"
echo ""
echo -e "  ${YELLOW}Tip:${NC} When new contracts are deployed, update assets/dex.json"
echo -e "  and assets/tokens.json, then rerun this script."
