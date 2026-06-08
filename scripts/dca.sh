#!/usr/bin/env bash
# ============================================================
# pharos-defi --DCA Strategy Executor
# Usage: ./dca.sh <network> <token_in> <token_out> <amount> [--setup]
# ============================================================
set -euo pipefail

GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
RED=$'\033[0;31m'
NC=$'\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

NETWORK="${1:-atlantic-testnet}"
TOKEN_IN_SYMBOL="${2:-}"
TOKEN_OUT_SYMBOL="${3:-}"
AMOUNT_HUMAN="${4:-}"
MODE="${5:-}"

if [ "$MODE" = "--setup" ]; then
    echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
    echo -e "${CYAN}  Pharos DeFi --DCA Setup${NC}"
    echo -e "${CYAN}閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡鎰ㄦ櫜閳烘劏鏅查埡={NC}"
    echo ""
    echo -e "DCA (Dollar Cost Averaging) automates periodic buys."
    echo -e "This script will create a config file for cron/systemd."
    echo ""

    read -p "Token to spend (e.g., PHRS): " TOKEN_IN_SYMBOL
    read -p "Token to buy (e.g., USDC): " TOKEN_OUT_SYMBOL
    read -p "Amount per buy: " AMOUNT_HUMAN
    read -p "Frequency [daily/weekly/biweekly/monthly]: " FREQ
    read -p "Total number of buys: " TOTAL_BUYS
    read -p "Slippage % [0.5]: " SLIPPAGE
    SLIPPAGE="${SLIPPAGE:-0.5}"

    # Convert frequency to seconds
    case $FREQ in
        daily)    INTERVAL=86400 ;;
        weekly)   INTERVAL=604800 ;;
        biweekly) INTERVAL=1209600 ;;
        monthly)  INTERVAL=2592000 ;;
        *) echo "Unknown frequency: $FREQ"; exit 1 ;;
    esac

    # Calculate total spend
    TOTAL_SPEND=$(echo "scale=2; $AMOUNT_HUMAN * $TOTAL_BUYS" | bc)

    # Create DCA config
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
    echo -e "${GREEN}閳烘劏鏅查埡=DCA Configuration 閳烘劏鏅查埡={NC}"
    echo -e "  Buy:       ${YELLOW}$AMOUNT_HUMAN $TOKEN_IN_SYMBOL --$TOKEN_OUT_SYMBOL${NC}"
    echo -e "  Frequency: ${YELLOW}$FREQ${NC}"
    echo -e "  Total:     ${YELLOW}$TOTAL_BUYS buys${NC}"
    echo -e "  Total spend: ${YELLOW}$TOTAL_SPEND $TOKEN_IN_SYMBOL${NC}"
    echo ""
    echo -e "${CYAN}Config saved to dca_config.json${NC}"
    echo ""
    echo -e "To run a single DCA buy manually:"
    echo -e "  ${GREEN}cd $SKILL_DIR && ./scripts/dca.sh --execute${NC}"
    echo ""
    echo -e "To automate (cron):"
    echo -e "  ${GREEN}crontab -e${NC} then add:"
    echo -e "  ${GREEN}0 10 * * 1 cd $SKILL_DIR && ./scripts/dca.sh --execute >> dca.log 2>&1${NC}"
    echo ""

elif [ "$MODE" = "--execute" ] || [ "$MODE" = "--exec" ]; then
    # Execute a single DCA buy
    if [ ! -f "$SKILL_DIR/dca_config.json" ]; then
        echo -e "${RED}No DCA config found. Run: ./dca.sh --setup${NC}"
        exit 1
    fi

    TOKEN_IN_SYMBOL=$(jq -r ''.tokenIn'' "$SKILL_DIR/dca_config.json")
    TOKEN_OUT_SYMBOL=$(jq -r ''.tokenOut'' "$SKILL_DIR/dca_config.json")
    AMOUNT_HUMAN=$(jq -r ''.amountPerBuy'' "$SKILL_DIR/dca_config.json")
    NETWORK=$(jq -r ''.network'' "$SKILL_DIR/dca_config.json")
    SLIPPAGE=$(jq -r ''.slippage'' "$SKILL_DIR/dca_config.json")

    EXECUTIONS=$(jq -r ''.executions'' "$SKILL_DIR/dca_config.json")
    TOTAL=$(jq -r ''.totalBuys'' "$SKILL_DIR/dca_config.json")

    if [ "$EXECUTIONS" -ge "$TOTAL" ]; then
        echo -e "${GREEN}DCA complete! $TOTAL/$TOTAL buys executed.${NC}"
        exit 0
    fi

    echo -e "${CYAN}閳烘劏鏅查埡=DCA Buy #$((EXECUTIONS + 1))/$TOTAL 閳烘劏鏅查埡={NC}"
    echo -e "  $(date -Iseconds)"
    echo ""

    # Execute swap via swap.sh
    bash "$SCRIPT_DIR/swap.sh" "$NETWORK" "$TOKEN_IN_SYMBOL" "$TOKEN_OUT_SYMBOL" "$AMOUNT_HUMAN" "$SLIPPAGE"

    # Update execution count
    NEW_COUNT=$((EXECUTIONS + 1))
    jq ".executions = $NEW_COUNT" "$SKILL_DIR/dca_config.json" > "$SKILL_DIR/dca_config.tmp" && \
        mv "$SKILL_DIR/dca_config.tmp" "$SKILL_DIR/dca_config.json"

    echo -e "${GREEN}DCA buy $NEW_COUNT/$TOTAL completed 閴={NC}"

    if [ "$NEW_COUNT" -ge "$TOTAL" ]; then
        echo -e "${GREEN}閳烘劏鏅查埡=DCA Complete! 閳烘劏鏅查埡={NC}"
        echo -e "All $TOTAL buys executed."
        echo -e "Run ./scripts/portfolio.sh to see results."
    fi

elif [ "$MODE" = "--status" ]; then
    if [ ! -f "$SKILL_DIR/dca_config.json" ]; then
        echo -e "${YELLOW}No DCA config found. Run: ./dca.sh --setup${NC}"
        exit 0
    fi

    echo -e "${CYAN}閳烘劏鏅查埡=DCA Status 閳烘劏鏅查埡={NC}"
    TOKEN_IN_SYMBOL=$(jq -r ''.tokenIn'' "$SKILL_DIR/dca_config.json")
    TOKEN_OUT_SYMBOL=$(jq -r ''.tokenOut'' "$SKILL_DIR/dca_config.json")
    AMOUNT=$(jq -r ''.amountPerBuy'' "$SKILL_DIR/dca_config.json")
    FREQ=$(jq -r ''.frequency'' "$SKILL_DIR/dca_config.json")
    EXECUTIONS=$(jq -r ''.executions'' "$SKILL_DIR/dca_config.json")
    TOTAL=$(jq -r ''.totalBuys'' "$SKILL_DIR/dca_config.json")
    TOTAL_SPEND=$(jq -r ''.totalSpend'' "$SKILL_DIR/dca_config.json")
    CREATED=$(jq -r ''.created'' "$SKILL_DIR/dca_config.json")

    echo -e "  Buy:       $AMOUNT $TOKEN_IN_SYMBOL --$TOKEN_OUT_SYMBOL"
    echo -e "  Frequency: $FREQ"
    echo -e "  Progress:  ${GREEN}$EXECUTIONS/$TOTAL${NC} buys"
    echo -e "  Started:   $CREATED"
    echo -e "  Spent:     ~$(echo "scale=2; $AMOUNT * $EXECUTIONS" | bc) $TOKEN_IN_SYMBOL"

    # Show remaining
    REMAINING=$((TOTAL - EXECUTIONS))
    if [ "$REMAINING" -gt 0 ]; then
        echo -e "  Remaining: $REMAINING buys"
        SPENT_SO_FAR=$(echo "scale=2; $AMOUNT * $EXECUTIONS" | bc)
        REMAINING_VALUE=$(echo "scale=2; $AMOUNT * $REMAINING" | bc)
        echo -e "  Est. remaining spend: $REMAINING_VALUE $TOKEN_IN_SYMBOL"
    fi
else
    echo -e "${CYAN}Pharos DeFi --DCA Strategy${NC}"
    echo ""
    echo "Usage:"
    echo "  $0 --setup      Create a new DCA strategy"
    echo "  $0 --execute    Execute next DCA buy"
    echo "  $0 --status     Show DCA progress"
fi
