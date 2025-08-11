## YoGateway Overview

YoGateway is a lightweight on-chain router for interacting with multiple YO Protocol ERC-4626 vaults through a **single entry point**.  
It allows developers to:

- Deposit underlying assets into any supported yoVault.
- Redeem shares from any supported yoVault (sync or async).
- Query exchange rates (assets ↔ shares) and preview deposits/redemptions.
- Check user allowances for both shares and underlying assets.

### Core Functions

**Write:**
- `deposit(address yoVault, uint256 assets, address receiver, uint32 partnerId)`
- `redeem(address yoVault, uint256 shares, address receiver, address ownerOfShares, uint32 partnerId)`

**Read:**
- `quoteConvertToShares(address yoVault, uint256 assets)`
- `quoteConvertToAssets(address yoVault, uint256 shares)`
- `quotePreviewDeposit(address yoVault, uint256 assets)`
- `quotePreviewRedeem(address yoVault, uint256 shares)`
- `getShareAllowance(address yoVault, address owner)`
- `getAssetAllowance(address yoVault, address owner)`
- `getVaults()` — returns the list of whitelisted yoVault addresses.

**Events:**
- `GatewayDeposit(address indexed yoVault, address indexed owner, address indexed receiver, uint256 assets, uint256 shares, uint32 partnerId)`
- `GatewayRedeem(address indexed yoVault, address indexed owner, address indexed receiver, uint256 shares, uint256 assets, uint32 partnerId)`

---

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
