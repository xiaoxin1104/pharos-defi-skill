# Cross-Chain Bridge Operations

Bridge tokens between Pharos and external chains using the official Pharos Bridge.

> **Network Configuration**: Read `<rpc>` from `assets/networks.json`.
> **Bridge Contract**: Read `<bridge>` from `assets/dex.json`. If not yet deployed, use placeholder ? the interface follows standard EVM bridge patterns (deposit on source, mint/claim on destination).
> **? IMPORTANT**: Bridge operations involve two chains. The Agent MUST confirm the source chain, destination chain, and token before executing. Cross-chain finality can take minutes to hours.

---

## Operations Index

| Section | Operation | Description |
|---------|-----------|-------------|
| [1](#1-bridge-tokens-to-pharos) | Bridge to Pharos | Deposit on external chain ? receive on Pharos |
| [2](#2-bridge-tokens-from-pharos) | Bridge from Pharos | Burn on Pharos ? claim on destination chain |
| [3](#3-check-bridge-status) | Check Bridge Status | Query deposit status, confirmations, claimability |
| [4](#4-bridge-fee-estimation) | Fee Estimation | Estimate bridge fees and finality time |

---

## Agent Guidelines (Bridge)

1. **Always confirm both chains** before any bridge operation
2. **Warn about finality time** ? bridges are not instant (typically 2-30 minutes)
3. **Check token support** ? not all tokens are bridgeable; verify against bridge registry
4. **Estimate total cost** ? gas on source chain + gas on destination chain + bridge fee
5. **Verify after bridging** ? check balance on destination chain after finality

---

## 1. Bridge Tokens to Pharos

Deposit tokens on an external chain (Ethereum, BSC, etc.) to receive wrapped tokens on Pharos.

### Standard Bridge Flow

```
Source Chain (Ethereum)          Bridge Relay          Destination (Pharos)
?????????????????????          ??????????????          ?????????????????????
User: approve(token, bridge)
User: bridge.deposit(token, amount, pharosRecipient)
                                    ?
                              Validators observe
                              event, sign message
                                    ?
                                                User: bridge.claim(proof)
                                                User receives wrapped token
```

### Command (Source Chain)

```bash
# On source chain (e.g., Ethereum mainnet)
SOURCE_RPC="<ethereum_rpc>"
BRIDGE_SRC="<bridge_contract_on_source>"
TOKEN_SRC="<token_on_source>"
AMOUNT="<amount_in_wei>"
PHAROS_RECIPIENT="<your_pharos_address>"

# 1. Approve bridge contract
cast send $TOKEN_SRC "approve(address,uint256)(bool)" $BRIDGE_SRC $AMOUNT \
    --private-key $PRIVATE_KEY --rpc-url $SOURCE_RPC

# 2. Deposit to bridge
cast send $BRIDGE_SRC "deposit(address,uint256,address)" \
    $TOKEN_SRC $AMOUNT $PHAROS_RECIPIENT \
    --private-key $PRIVATE_KEY --rpc-url $SOURCE_RPC
```

### Command (Pharos ? Claim)

```bash
# After finality (wait for confirmations), claim on Pharos
RPC_URL=$(jq -r '.networks[] | select(.name=="mainnet") | .rpcUrl' assets/networks.json)
BRIDGE_DST="<bridge_contract_on_pharos>"

cast send $BRIDGE_DST "claim(bytes32,address,uint256,address)" \
    <deposit_tx_hash> $TOKEN_SRC $AMOUNT $PHAROS_RECIPIENT \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

---

## 2. Bridge Tokens from Pharos

Burn wrapped tokens on Pharos to receive original tokens on the destination chain.

```bash
# On Pharos
RPC_URL=$(jq -r '.networks[] | select(.name=="mainnet") | .rpcUrl' assets/networks.json)
BRIDGE_PHAROS="<bridge_contract_on_pharos>"
TOKEN_WRAPPED="<wrapped_token_on_pharos>"
AMOUNT="<amount_in_wei>"
DEST_CHAIN_RECIPIENT="<recipient_on_destination_chain>"

# 1. Approve bridge on Pharos
cast send $TOKEN_WRAPPED "approve(address,uint256)(bool)" $BRIDGE_PHAROS $AMOUNT \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# 2. Initiate withdrawal
cast send $BRIDGE_PHAROS "withdraw(address,uint256,address,uint256)" \
    $TOKEN_WRAPPED $AMOUNT $DEST_CHAIN_RECIPIENT <destination_chain_id> \
    --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

---

## 3. Check Bridge Status

Query whether a deposit has been finalized and is ready to claim.

```bash
# Check deposit status by transaction hash
BRIDGE_PHAROS="<bridge_contract>"
DEPOSIT_TX="<source_chain_deposit_tx>"

# Query if deposit is claimable
IS_CLAIMABLE=$(cast call $BRIDGE_PHAROS \
    "isClaimable(bytes32)(bool)" \
    $DEPOSIT_TX --rpc-url $RPC_URL)

if [ "$IS_CLAIMABLE" = "true" ]; then
    echo "Deposit ready to claim on Pharos"
else
    echo "Waiting for finality..."
fi

# Check required confirmations
REQUIRED=$(cast call $BRIDGE_PHAROS "requiredConfirmations()(uint256)" --rpc-url $RPC_URL)
CURRENT=$(cast call $BRIDGE_PHAROS "getConfirmations(bytes32)(uint256)" $DEPOSIT_TX --rpc-url $RPC_URL)

echo "Confirmations: $CURRENT / $REQUIRED"
```

---

## 4. Bridge Fee Estimation

### Standard Fee Structure

| Fee Type | Typical Range | Notes |
|----------|--------------|-------|
| **Source gas** | Variable | Gas on source chain for deposit tx |
| **Destination gas** | Variable | Gas on Pharos for claim tx |
| **Bridge fee** | 0.01-0.1% | Protocol fee (if applicable) |
| **Validator fee** | Fixed | Relayer/validator reward |

### Estimation Script

```bash
# Estimate total bridge cost
SOURCE_GAS="<estimated_source_gas>"
SOURCE_GAS_PRICE=$(cast gas-price --rpc-url $SOURCE_RPC)
SOURCE_COST_WEI=$(echo "$SOURCE_GAS * $SOURCE_GAS_PRICE" | bc)

PHAROS_GAS="<estimated_pharos_gas>"  
PHAROS_GAS_PRICE=$(cast gas-price --rpc-url $RPC_URL)
PHAROS_COST_WEI=$(echo "$PHAROS_GAS * $PHAROS_GAS_PRICE" | bc)

BRIDGE_FEE_RATE=0.001  # 0.1%
BRIDGE_AMOUNT="<amount_in_wei>"
BRIDGE_FEE=$(echo "scale=0; $BRIDGE_AMOUNT * $BRIDGE_FEE_RATE / 1" | bc)

echo "=== Bridge Cost Estimate ==="
echo "Source gas:    $SOURCE_COST_WEI wei"
echo "Pharos gas:    $PHAROS_COST_WEI wei"
echo "Bridge fee:    $BRIDGE_FEE wei"
echo "Total:         $((SOURCE_COST_WEI + PHAROS_COST_WEI + BRIDGE_FEE)) wei"
```

---

## Cross-Chain Security Checklist

Before any bridge operation, the Agent MUST verify:

1. **Bridge contract verified** ? Check on Pharos explorer that the bridge contract source is verified
2. **Token mapping confirmed** ? Ensure the wrapped token on Pharos maps 1:1 to the source token
3. **Finality understood** ? Bridge takes N confirmations (typically 12-64 blocks on source chain)
4. **No urgent timing** ? Warn user not to bridge funds needed immediately
5. **Test with small amount first** ? Always recommend a small test transfer before large amounts

---

## Supported Chains (Configurable)

Bridge chain support is configured in `assets/dex.json` under `bridge.supportedChains`:

```json
{
  "bridge": {
    "supportedChains": [
      {"id": 1, "name": "Ethereum", "bridgeContract": "0x...", "finalityBlocks": 64},
      {"id": 56, "name": "BSC", "bridgeContract": "0x...", "finalityBlocks": 20},
      {"id": 42161, "name": "Arbitrum", "bridgeContract": "0x...", "finalityBlocks": 100}
    ]
  }
}
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| Token not supported by bridge | Check bridge token registry; suggest wrapped alternative |
| Insufficient confirmations | Wait for required blocks; show current/target progress |
| Bridge paused | Bridge may be under maintenance; check official announcements |
| Claim already processed | Deposit already claimed ? no action needed |
| Wrong destination chain | Verify chain ID before initiating withdrawal |
| Gas too low on destination | Ensure Pharos wallet has native tokens for gas |
