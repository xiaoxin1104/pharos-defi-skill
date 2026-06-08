#!/usr/bin/env bash
# pharos-defi -- DCA Strategy Executor
set -euo pipefail

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
RED=$'\033[0;31m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"
MODE="${2:-}"

echo_header() { echo -e "${CYAN}$1${NC}"; }
echo_ok()    { echo -e "${GREEN}$1${NC}"; }
echo_warn()  { echo -e "${YELLOW}$1${NC}"; }
echo_err()   { echo -e "${RED}$1${NC}"; }

if [ "$MODE" = "--setup" ]; then
    echo_header "==========================================="
    echo_header "  Pharos DeFi -- DCA Setup"
    echo_header "==========================================="
    echo ""
    echo "DCA (Dollar Cost Averaging) automates periodic buys."
    echo ""

    read -p "Token to spend (e.g., PHRS): " TOKEN_IN_SYMBOL
    read -p "Token to buy (e.g., USDC): " TOKEN_OUT_SYMBOL
    read -p "Amount per buy: " AMOUNT_HUMAN
    read -p "Frequency [daily/weekly/biweekly/monthly]: " FREQ
    read -p "Total number of buys: " TOTAL_BUYS
    read -p "Slippage % [0.5]: " SLIPPAGE
    SLIPPAGE="${SLIPPAGE:-0.5}"

    case $FREQ in
        daily)    INTERVAL=86400 ;;
        weekly)   INTERVAL=604800 ;;
        biweekly) INTERVAL=1209600 ;;
        monthly)  INTERVAL=2592000 ;;
        *) echo "Unknown frequency: $FREQ"; exit 1 ;;
    esac

    TOTAL_SPEND=$(echo "scale=2; $AMOUNT_HUMAN * $TOTAL_BUYS" | bc)

    cat > "$SKILL_DIR/dca_config.json" << EOF
{
  "network": "$NETWORK",
  "tokenIn": "$TOKEN_IN_SYMBOL",
  "tokenOut": "$TOKEN_OUT_SYMBOL",
  "amountPerBuy": "$AMOUNT_HUMAN",
  "frequency": "$FREQ",
  "intervalSeconds": $INTERVAL,
  "totalBuys": $TOTAL_BUYS,
  "slippage": $SLIPPAGE,
  "totalSpend": "$TOTAL_SPEND",
  "executions": 0,
  "created": "$(date -Iseconds)"
}
EOF

    echo ""
    echo_header "=== DCA Configuration ==="
    echo "  Buy:       $AMOUNT_HUMAN $TOKEN_IN_SYMBOL -> $TOKEN_OUT_SYMBOL"
    echo "  Frequency: $FREQ"
    echo "  Total:     $TOTAL_BUYS buys"
    echo "  Total spend: $TOTAL_SPEND $TOKEN_IN_SYMBOL"
    echo ""
    echo "Config saved to dca_config.json"
    echo ""
    echo "To run a single DCA buy:"
    echo "  ./scripts/dca.sh atlantic-testnet --execute"
    echo ""
    echo "To check status:"
    echo "  ./scripts/dca.sh atlantic-testnet --status"

elif [ "$MODE" = "--execute" ] || [ "$MODE" = "--exec" ]; then
    if [ ! -f "$SKILL_DIR/dca_config.json" ]; then
        echo_err "No DCA config found. Run: ./scripts/dca.sh atlantic-testnet --setup"
        exit 1
    fi

    TOKEN_IN_SYMBOL=$(jq -r '.tokenIn' "$SKILL_DIR/dca_config.json")
    TOKEN_OUT_SYMBOL=$(jq -r '.tokenOut' "$SKILL_DIR/dca_config.json")
    AMOUNT_HUMAN=$(jq -r '.amountPerBuy' "$SKILL_DIR/dca_config.json")
    SLIPPAGE=$(jq -r '.slippage' "$SKILL_DIR/dca_config.json")
    EXECUTIONS=$(jq -r '.executions' "$SKILL_DIR/dca_config.json")
    TOTAL=$(jq -r '.totalBuys' "$SKILL_DIR/dca_config.json")

    if [ "$EXECUTIONS" -ge "$TOTAL" ]; then
        echo_ok "DCA complete! $TOTAL/$TOTAL buys executed."
        exit 0
    fi

    echo_header "=== DCA Buy #$((EXECUTIONS + 1))/$TOTAL ==="
    echo "  $(date -Iseconds)"
    echo ""

    bash "$SCRIPT_DIR/swap.sh" "$NETWORK" "$TOKEN_IN_SYMBOL" "$TOKEN_OUT_SYMBOL" "$AMOUNT_HUMAN" "$SLIPPAGE"

    NEW_COUNT=$((EXECUTIONS + 1))
    jq ".executions = $NEW_COUNT" "$SKILL_DIR/dca_config.json" > "$SKILL_DIR/dca_config.tmp" && \
        mv "$SKILL_DIR/dca_config.tmp" "$SKILL_DIR/dca_config.json"

    echo_ok "DCA buy $NEW_COUNT/$TOTAL completed [OK]"

    if [ "$NEW_COUNT" -ge "$TOTAL" ]; then
        echo_header "=== DCA Complete! ==="
        echo "All $TOTAL buys executed."
    fi

elif [ "$MODE" = "--status" ]; then
    if [ ! -f "$SKILL_DIR/dca_config.json" ]; then
        echo_warn "No DCA config found. Run: ./scripts/dca.sh atlantic-testnet --setup"
        exit 0
    fi

    echo_header "=== DCA Status ==="
    TOKEN_IN_SYMBOL=$(jq -r '.tokenIn' "$SKILL_DIR/dca_config.json")
    TOKEN_OUT_SYMBOL=$(jq -r '.tokenOut' "$SKILL_DIR/dca_config.json")
    AMOUNT=$(jq -r '.amountPerBuy' "$SKILL_DIR/dca_config.json")
    FREQ=$(jq -r '.frequency' "$SKILL_DIR/dca_config.json")
    EXECUTIONS=$(jq -r '.executions' "$SKILL_DIR/dca_config.json")
    TOTAL=$(jq -r '.totalBuys' "$SKILL_DIR/dca_config.json")
    CREATED=$(jq -r '.created' "$SKILL_DIR/dca_config.json")

    echo "  Buy:       $AMOUNT $TOKEN_IN_SYMBOL -> $TOKEN_OUT_SYMBOL"
    echo "  Frequency: $FREQ"
    echo "  Progress:  $EXECUTIONS/$TOTAL buys"
    echo "  Started:   $CREATED"
    echo "  Spent:     ~$(echo "scale=2; $AMOUNT * $EXECUTIONS" | bc) $TOKEN_IN_SYMBOL"

    REMAINING=$((TOTAL - EXECUTIONS))
    if [ "$REMAINING" -gt 0 ]; then
        REMAINING_VALUE=$(echo "scale=2; $AMOUNT * $REMAINING" | bc)
        echo "  Remaining: $REMAINING buys (est. $REMAINING_VALUE $TOKEN_IN_SYMBOL)"
    fi
else
    echo_header "Pharos DeFi -- DCA Strategy"
    echo ""
    echo "Usage:"
    echo "  $0 <network> --setup      Create a new DCA strategy"
    echo "  $0 <network> --execute    Execute next DCA buy"
    echo "  $0 <network> --status     Show DCA progress"
    echo ""
    echo "Example:"
    echo "  $0 atlantic-testnet --setup"
fi
