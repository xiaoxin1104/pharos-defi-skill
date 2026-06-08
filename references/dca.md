# DCA (Dollar Cost Averaging) Strategy

Automated periodic token purchases to reduce timing risk and build positions systematically.

> **Network Configuration**: Read `<rpc>` from `assets/networks.json`.
> **Router Address**: Read `<router>` from `assets/dex.json`.
> **⚠ IMPORTANT**: DCA is a time-based strategy. The Agent should set up the parameters but remind users that true automation requires a cron job, scheduler bot, or Anvita Flow Agent to execute periodically.

---

## Operations Index

| Section | Operation | Description |
|---------|-----------|-------------|
| [1](#1-dca-parameter-setup) | Parameter Setup | Define amount, frequency, token pair |
| [2](#2-single-dca-execution) | Single DCA Execution | Execute one DCA buy |
| [3](#3-dca-schedule-design) | Schedule Design | Plan execution frequency |
| [4](#4-dca-pnl-calculation) | DCA PnL | Calculate average cost vs current price |
| [5](#5-dca-vs-lump-sum) | DCA vs Lump Sum | Compare strategies |

---

## Agent Guidelines (DCA)

1. DCA is fundamentally: **buy fixed amount of TokenB using TokenA at regular intervals**
2. The Agent generates the swap command; the user sets up the scheduler (cron, systemd timer, or Anvita Flow Agent)
3. Always calculate and display average entry price vs current price
4. Warn if DCA amount is too small relative to gas cost (gas > 1% of trade)
5. Suggest reasonable defaults: weekly frequency, 1-5% of portfolio per buy

---

## 1. DCA Parameter Setup

### Key Parameters

| Param | Example | Description |
|-------|---------|-------------|
| `tokenIn` | PHRS | Token being spent |
| `tokenOut` | USDC | Token being accumulated |
| `amountPerBuy` | 10 PHRS | Amount per execution |
| `frequency` | 604800 (7 days) | Seconds between buys |
| `totalBuys` | 12 | Number of executions |
| `slippage` | 0.5% | Slippage tolerance |

### Interactive Setup (Agent → User)

The Agent should confirm with the user:
```
═══ DCA Strategy Setup ═══
  Buy:        10 PHRS worth of USDC
  Frequency:  Every 7 days
  Total buys: 12 (over 12 weeks)
  Total spend: 120 PHRS
  Slippage:   0.5%
  Network:    Atlantic Testnet

  Estimated gas per buy: ~0.001 PHRS
  Total gas cost:         ~0.012 PHRS
  Gas as % of trade:      0.01%

Start DCA? (y/n)
```

---

## 2. Single DCA Execution

Each DCA execution is a standard `swapExactETHForTokens` or `swapExactTokensForTokens` call.

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
ROUTER=$(jq -r ''.networks["atlantic-testnet"].router'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

# DCA parameters
AMOUNT_PER_BUY="<amount_in_wei>"
TOKEN_IN="<token_in_address>"
TOKEN_OUT="<token_out_address>"
SLIPPAGE="0.5"

# Build path
if [ "$TOKEN_IN" = "$WETH" ] || [ "$TOKEN_OUT" = "$WETH" ]; then
    PATH="[$TOKEN_IN,$TOKEN_OUT]"
else
    PATH="[$TOKEN_IN,$WETH,$TOKEN_OUT]"
fi

# Quote
QUOTE=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
    $AMOUNT_PER_BUY "$PATH" --rpc-url $RPC_URL)
EXPECTED_OUT=$(echo "$QUOTE" | tail -1)

# Slippage
AMOUNT_OUT_MIN=$(echo "scale=0; $EXPECTED_OUT * (100 - $SLIPPAGE) / 100" | bc)

# Deadline
DEADLINE=$(($(date +%s) + 1200))

# Execute (Token→Token)
cast send $ROUTER \
    "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
    $AMOUNT_PER_BUY $AMOUNT_OUT_MIN "$PATH" <recipient> $DEADLINE \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL --legacy

echo "$(date -Iseconds),$AMOUNT_PER_BUY,$EXPECTED_OUT,$TX_HASH" >> dca_log.csv
```

---

## 3. DCA Schedule Design

### Frequency Recommendations

| Profile | Frequency | Reason |
|---------|-----------|--------|
| **Aggressive** | Daily | Faster average, higher gas |
| **Standard** | Weekly | Balanced gas/cost |
| **Conservative** | Bi-weekly | Lower gas, slower avg |
| **Micro DCA** | Hourly | Only if gas < 0.01% of trade |

### Cron Setup (Linux/macOS)

```bash
# Weekly DCA — every Monday at 10:00 UTC
0 10 * * 1 cd /path/to/pharos-defi-skill && ./scripts/swap.sh atlantic-testnet PHRS USDC 10.0 >> dca.log 2>&1
```

### Systemd Timer (Linux)

```ini
# /etc/systemd/system/pharos-dca.service
[Service]
ExecStart=/path/to/pharos-defi-skill/scripts/swap.sh atlantic-testnet PHRS USDC 10.0
Environment=PRIVATE_KEY=%k
User=ubuntu
```

```ini
# /etc/systemd/system/pharos-dca.timer
[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

### For Anvita Flow Agents (Phase 2)

In Phase 2, the DCA skill can be composed into an Agent that autonomously executes swaps on schedule:

```
Agent Prompt: "Run DCA: buy 10 PROS worth of USDC every Monday at 10:00 UTC.
              Check balance first, get quote, execute swap with 0.5% slippage."
```

The Agent reads this skill''s reference files to execute the swap correctly.

---

## 4. DCA PnL Calculation

### Average Entry Price

```
avgEntryPrice = totalSpent / totalReceived

Example:
  Buy 1: 10 PHRS → 95 USDC  (rate: 9.5)
  Buy 2: 10 PHRS → 92 USDC  (rate: 9.2)
  Buy 3: 10 PHRS → 98 USDC  (rate: 9.8)
  
  Total spent:  30 PHRS
  Total received: 285 USDC
  Avg entry: 30/285 = 0.1053 PHRS/USDC (or 9.5 USDC/PHRS)
```

### PnL vs Current Price

```bash
# Read from DCA log
TOTAL_SPENT=0
TOTAL_RECEIVED=0
while IFS='','' read -r timestamp amountIn amountOut txhash; do
    TOTAL_SPENT=$((TOTAL_SPENT + amountIn))
    TOTAL_RECEIVED=$((TOTAL_RECEIVED + amountOut))
done < dca_log.csv

AVG_PRICE=$(echo "scale=6; $TOTAL_SPENT / $TOTAL_RECEIVED" | bc)

# Get current spot price
CURRENT_QUOTE=$(cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" \
    1000000000000000000 "[$TOKEN_IN,$TOKEN_OUT]" --rpc-url $RPC_URL | tail -1)

CURRENT_PRICE=$(echo "scale=6; 1000000000000000000 / $CURRENT_QUOTE" | bc)

# PnL
PL_PCT=$(echo "scale=2; ($CURRENT_PRICE - $AVG_PRICE) / $AVG_PRICE * 100" | bc)

echo "═══ DCA Performance ═══"
echo "  Total spent:    $TOTAL_SPENT"
echo "  Total received: $TOTAL_RECEIVED"
echo "  Avg entry:      $AVG_PRICE"
echo "  Current price:  $CURRENT_PRICE"
echo "  PnL:            $PL_PCT%"
```

---

## 5. DCA vs Lump Sum Comparison

The Agent should, when appropriate, compare DCA vs lump sum:

| Strategy | Best When | Risk |
|----------|-----------|------|
| **DCA** | High volatility, uncertain market | Lower timing risk, higher total gas |
| **Lump Sum** | Strong conviction, low gas, large amount | Timing risk, but lower fees |

### Quick Comparison

```bash
# For 120 PHRS total:
# Option A: DCA — 12 weekly buys of 10 PHRS
# Option B: Lump sum — 1 buy of 120 PHRS now

# Calculate DCA gas: 12 * ~120k gas * gasPrice
# Calculate Lump gas: 1 * ~120k gas * gasPrice

echo "DCA gas cost:    ~$(echo "12 * 120000 * $GAS_PRICE / 10^18" | bc) PHRS"
echo "Lump gas cost:   ~$(echo "1 * 120000 * $GAS_PRICE / 10^18" | bc) PHRS"
echo "DCA saves timing risk but costs $(echo "11 * 120000 * $GAS_PRICE / 10^18" | bc) PHRS extra in gas"
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| Gas too high (>1% of trade) | Warn user, suggest larger buy amount or less frequent execution |
| Insufficient balance on execution | Skip buy, log warning, notify user |
| Pair liquidity too low | Suggest alternative token pair or warn of high slippage |
| DCA log file lost | Recalculate from on-chain swap history |
