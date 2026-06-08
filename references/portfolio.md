# Portfolio & Position Tracking

Track token balances, LP positions, and DeFi portfolio performance across the Pharos DEX ecosystem.

> **Network Configuration**: Read `<rpc>` from `assets/networks.json`.
> **Factory Address**: Read `<factory>` from `assets/dex.json`.

---

## Operations Index

| Section | Operation | Description |
|---------|-----------|-------------|
| [1](#1-native-balance) | Native Balance | Query PHRS/PROS balance |
| [2](#2-token-balance-batch) | Token Balance Batch | Batch-query all tracked tokens |
| [3](#3-lp-position-discovery) | LP Position Discovery | Auto-discover all LP positions |
| [4](#4-lp-position-details) | LP Position Details | Decode share, reserves, value |
| [5](#5-pnl-tracking) | PnL Tracking | Track deposit vs current value |
| [6](#6-automated-portfolio-script) | Automated Script | Run `scripts/portfolio.sh` |

---

## Agent Guidelines (Portfolio)

1. Auto-discover: don''t require user to provide pair addresses — derive everything from Factory and token list
2. Human-readable: convert all raw wei/uint values to human decimals
3. Spot new tokens: if token list is incomplete, suggest querying unrecognized tokens
4. Summarize: show total protocol value (all LP positions + native + tokens)

---

## 1. Native Balance

```bash
RPC_URL=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .rpcUrl'' assets/networks.json)
NATIVE=$(jq -r ''.networks[] | select(.name=="atlantic-testnet") | .nativeToken'' assets/networks.json)

BALANCE_WEI=$(cast balance <user_address> --rpc-url $RPC_URL)
echo "$NATIVE: $(echo "scale=6; $BALANCE_WEI / 10^18" | bc)"
```

---

## 2. Token Balance Batch

Query all tokens from `assets/tokens.json` in one sweep:

```bash
TOKENS=$(jq -c ''.tokens["atlantic-testnet"][]'' assets/tokens.json)
TOTAL_TOKEN_COUNT=$(echo "$TOKENS" | wc -l)

echo "$TOKENS" | while read -r token; do
    SYMBOL=$(echo "$token" | jq -r ''.symbol'')
    TYPE=$(echo "$token" | jq -r ''.type'')
    ADDR=$(echo "$token" | jq -r ''.address'')
    DECIMALS=$(echo "$token" | jq -r ''.decimals'')

    # Skip native (handled separately)
    [ "$TYPE" = "native" ] && continue

    BAL=$(cast call "$ADDR" "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL 2>/dev/null || echo "0")
    BAL=$(echo "$BAL" | tr -d ''[:space:]'')

    if [ "$BAL" != "0" ] && [ -n "$BAL" ]; then
        HUMAN=$(echo "scale=6; $BAL / 10^$DECIMALS" | bc)
        printf "%-8s %s\n" "$SYMBOL" "$HUMAN"
    fi
done
```

---

## 3. LP Position Discovery

Auto-discover all LP tokens held by the user by checking every pair from the token list:

```bash
FACTORY=$(jq -r ''.networks["atlantic-testnet"].factory'' assets/dex.json)
WETH=$(jq -r ''.networks["atlantic-testnet"].weth'' assets/dex.json)

# Build token address list from tokens.json + WETH
TOKEN_ADDRS=($(jq -r ''.tokens["atlantic-testnet"][].address'' assets/tokens.json))
TOKEN_ADDRS+=("$WETH")

# Check all token pairs
for ((i=0; i<${#TOKEN_ADDRS[@]}; i++)); do
    for ((j=i+1; j<${#TOKEN_ADDRS[@]}; j++)); do
        TA="${TOKEN_ADDRS[$i]}"
        TB="${TOKEN_ADDRS[$j]}"

        # Skip if not full addresses
        [[ ! "$TA" =~ ^0x[a-fA-F0-9]{40}$ ]] && continue
        [[ ! "$TB" =~ ^0x[a-fA-F0-9]{40}$ ]] && continue
        [ "$TA" = "$TB" ] && continue

        PAIR=$(cast call "$FACTORY" "getPair(address,address)(address)" "$TA" "$TB" --rpc-url $RPC_URL 2>/dev/null)

        if [ "$PAIR" != "0x0000000000000000000000000000000000000000" ]; then
            LP_BAL=$(cast call "$PAIR" "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL 2>/dev/null)
            LP_BAL=$(echo "$LP_BAL" | tr -d ''[:space:]'')

            if [ -n "$LP_BAL" ] && [ "$LP_BAL" != "0" ]; then
                echo "LP Position: $PAIR (balance: $LP_BAL)"
            fi
        fi
    done
done
```

---

## 4. LP Position Details

For each discovered LP position, get full details:

```bash
PAIR="<pair_address>"

# LP Token
LP_BAL=$(cast call "$PAIR" "balanceOf(address)(uint256)" <user_address> --rpc-url $RPC_URL)
TOTAL_SUPPLY=$(cast call "$PAIR" "totalSupply()(uint256)" --rpc-url $RPC_URL)
SHARE_PCT=$(echo "scale=4; $LP_BAL * 100 / $TOTAL_SUPPLY" | bc)

# Reserves
RESERVES=$(cast call "$PAIR" "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC_URL)
R0=$(echo "$RESERVES" | sed -n ''1p'' | tr -d ''[:space:]'')
R1=$(echo "$RESERVES" | sed -n ''2p'' | tr -d ''[:space:]'')

# Tokens
T0=$(cast call "$PAIR" "token0()(address)" --rpc-url $RPC_URL)
T1=$(cast call "$PAIR" "token1()(address)" --rpc-url $RPC_URL)

# Your share of reserves
MY_R0=$(echo "scale=0; $R0 * $LP_BAL / $TOTAL_SUPPLY" | bc)
MY_R1=$(echo "scale=0; $R1 * $LP_BAL / $TOTAL_SUPPLY" | bc)

echo "Pool: $T0 / $T1"
echo "  Pair: $PAIR"
echo "  Share: $SHARE_PCT%"
echo "  Your Token0: $MY_R0"
echo "  Your Token1: $MY_R1"
echo "  Total LP: $LP_BAL"
```

### Report Format

When presenting a portfolio to the user:

```
═══ Pharos DeFi Portfolio ═══
Network: Atlantic Testnet
Address: 0x1234...abcd

[Native]
  PHRS: 10.500000

[Tokens]
  USDC:  5,000.000000
  USDT:  1,200.500000

[LP Positions]
  PHRS/USDC  (3.45% share)
    Pair:  0xaabb...1234
    PHRS:  2.500000
    USDC:  9,875.000000

  USDC/USDT  (1.20% share)
    Pair:  0xccdd...5678
    USDC:  500.000000
    USDT:  498.750000

[Summary]
  Total LP Value: ~$14,875
  Total Tokens:   ~$6,200
  Total Native:   ~$10.50
  ═════════════════════
  Total Portfolio: ~$21,085
```

---

## 5. PnL Tracking

Track profit/loss on LP positions by comparing current withdrawable amounts vs original deposit.

```bash
# Store deposit snapshot when adding liquidity:
# Save to a local file: deposits.json
echo ''{"pair":"$PAIR","token0Amount":"$AMT0","token1Amount":"$AMT1","timestamp":"$(date +%s)","blockNumber":"$BLOCK"}"'' >> deposits.json

# Later, compare:
CURRENT_T0=$(echo "scale=0; $(get_reserve0 $PAIR) * $LP_BAL / $TOTAL_SUPPLY" | bc)
CURRENT_T1=$(echo "scale=0; $(get_reserve1 $PAIR) * $LP_BAL / $TOTAL_SUPPLY" | bc)

DEPOSIT_T0=$(jq -r ''.token0Amount'' deposits.json)
DEPOSIT_T1=$(jq -r ''.token1Amount'' deposits.json)

# Calculate impermanent loss vs HODL
# IL = (current_value_as_held - current_value_as_lp) / current_value_as_held
```

> **⚠ Limitation**: True PnL requires price oracles. For hackathon scope, report LP share changes qualitatively:
> - If `MY_R0 + MY_R1` (at current price) < original deposit (at deposit price) → Impermanent Loss
> - If trading fees accumulated → pool share should increase over time (check LP balance vs initial)

---

## 6. Automated Portfolio Script

Use the bundled script for one-command portfolio overview:

```bash
# From the skill directory:
chmod +x scripts/portfolio.sh
./scripts/portfolio.sh atlantic-testnet 0xYourAddress

# Or auto-detect from PRIVATE_KEY:
export PRIVATE_KEY=<your_key>
./scripts/portfolio.sh atlantic-testnet
```
