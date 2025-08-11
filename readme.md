# YoGateway Overview

YoGateway is a lightweight on-chain router for interacting with multiple YO Protocol ERC-4626 vaults through a **single entry point**.  

It allows developers to:

- Deposit underlying assets into any supported yoVault.
- Redeem shares from any supported yoVault (sync or async).
- Query exchange rates (assets ↔ shares) and preview deposits/redemptions.
- Check user allowances for both shares and underlying assets.

## Supported Vaults

The following vaults are supported by YoGateway on **Base chain**:

- **yoUSD**: `0x0000000f2eb9f69274678c76222b35eec7588a65`
- **yoBTC**:  `0xbCbc8cb4D1e8ED048a6276a5E94A3e952660BcbC`
- **yoETH**:  `0x3a43aec53490cb9fa922847385d82fe25d0e9de7`

---

## Use Cases

Common scenarios for using YoGateway:

- **Simplified Integration**: Integrate with multiple YO Protocol ERC-4626 vaults using a single contract interface.
- **Batch Deposit Flows**: Build user experiences that deposit into different vaults with a unified flow.
- **Partner Tracking**: Attribute deposits/redemptions to specific partners using the `partnerId` parameter.
- **Unified Allowance Checks**: Query and manage both underlying asset and share allowances from one place.
- **Automated Redemptions**: Enable dApps to redeem shares on behalf of users with proper approvals.

---
## Interaction Guide

### Approvals Required

- **Deposits**:  
  The user must approve YoGateway to spend their _underlying asset_ (e.g., USDC, DAI, ETH) for the target yoVault.
- **Redemptions**:  
  The user must approve YoGateway to spend their _yoVault shares_ (ERC-20) for the target yoVault.

> _Tip: Asset approval is required for deposit; share approval is required for redeem._

### Example: Asset Allowance (Deposit)

#### Solidity
```solidity
IERC20(asset).approve(address(yoGateway), amount);
```

#### ethers.js
```js
await assetToken.approve(yoGatewayAddress, amount);
```

#### cast CLI
```shell
cast approve <asset_token> <yoGateway_address> <amount> --private-key $PRIVKEY
```

### Example: Share Allowance (Redeem)

#### Solidity
```solidity
IERC20(yoVault).approve(address(yoGateway), shares);
```

#### ethers.js
```js
await yoVaultToken.approve(yoGatewayAddress, shares);
```

#### cast CLI
```shell
cast approve <yoVault_address> <yoGateway_address> <shares> --private-key $PRIVKEY
```

---

### Example Calls: deposit and redeem with partnerId

#### Solidity
```solidity
// Deposit
yoGateway.deposit(yoVault, assets, receiver, partnerId);

// Redeem
yoGateway.redeem(yoVault, shares, receiver, ownerOfShares, partnerId);
```

#### ethers.js
```js
// Deposit
await yoGateway.deposit(yoVaultAddress, amount, receiver, partnerId);

// Redeem
await yoGateway.redeem(yoVaultAddress, shares, receiver, ownerOfShares, partnerId);
```

#### cast CLI
```shell
# Deposit
cast send <yoGateway_address> "deposit(address,uint256,address,uint32)" \
  <yoVault_address> <amount> <receiver> <partnerId> --private-key $PRIVKEY

# Redeem
cast send <yoGateway_address> "redeem(address,uint256,address,address,uint32)" \
  <yoVault_address> <shares> <receiver> <ownerOfShares> <partnerId> --private-key $PRIVKEY
```

#### ABI Encodings
- For `deposit`, encode as:  
  `deposit(address yoVault, uint256 assets, address receiver, uint32 partnerId)`
- For `redeem`, encode as:  
  `redeem(address yoVault, uint256 shares, address receiver, address ownerOfShares, uint32 partnerId)`

---

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
- `getVaults()` — returns an array of whitelisted yoVault addresses.

**Events:**
- `GatewayDeposit(address indexed yoVault, address indexed owner, address indexed receiver, uint256 assets, uint256 shares, uint32 partnerId)`
- `GatewayRedeem(address indexed yoVault, address indexed owner, address indexed receiver, uint256 shares, uint256 assets, uint32 partnerId)`