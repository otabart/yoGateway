// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title YoGateway
 * @notice Single entrypoint for deposits and redemption requests across allow-listed YO ERC-4626 vaults.
 *         - deposit(assets→shares) and redeem(shares→assets).
 *         - Emits partnerId for attribution; does NOT manage partner registries or fees.
 *         - Owner can add/remove yoVaults. Two-step ownership transfer (transferOwnership / acceptOwnership).
 *
 * Assumptions:
 *  - Callers supply the correct underlying `asset()` for each yoVault.
 *  - redeem may be async (returns 0 when routed to the vault's requestRedeem). Gateway is oblivious; assets are delivered by the vault.
 *  - For third-party redemption (owner != sender), owner must approve the gateway to transfer shares.
 */
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IYoVaultMinimal} from "./interfaces/IYoVaultMinimal.sol";

contract YoGateway is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ========= Errors =========
    error NotOwner();
    error NotPendingOwner();
    error ZeroAddress();
    error VaultNotAllowed();

    // ========= Ownership (two-step) =========
    address public owner;
    address public pendingOwner;

    event OwnershipTransferStarted(address indexed owner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        address prev = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(prev, owner);
    }

    // ========= Vault allow-list =========
    mapping(address => bool) public isVaultAllowed; // yoVault => allowed
    mapping(address => address) public assetOfVault; // yoVault => underlying asset
    address[] private _vaultList;

    event VaultAdded(address indexed yoVault, address indexed asset);
    event VaultRemoved(address indexed yoVault);

    constructor() {
        owner = msg.sender;
        // NOTE: Do not pre-seed vaults here. For proxy vaults, call addVault() or addVaultWithAsset() post-deploy.
    }

    function addVault(address yoVault) external onlyOwner {
        _addVault(yoVault);
    }

    function removeVault(address yoVault) external onlyOwner {
        _removeVault(yoVault);
    }

    function _addVault(address yoVault) internal {
        if (yoVault == address(0)) revert ZeroAddress();
        require(yoVault.code.length > 0, "Vault has no code");
        if (isVaultAllowed[yoVault]) return; // idempotent
        address a;
        // Try to resolve asset() from the vault (proxy should forward). If it reverts, owner can use addVaultWithAsset.
        try IYoVaultMinimal(yoVault).asset() returns (address resolved) {
            a = resolved;
        } catch {
            a = address(0);
        }
        // If asset() couldn’t be resolved here, it can be set via addVaultWithAsset().
        isVaultAllowed[yoVault] = true;
        assetOfVault[yoVault] = a;
        _vaultList.push(yoVault);
        emit VaultAdded(yoVault, a);
    }

    event VaultAssetRefreshed(address indexed yoVault, address indexed oldAsset, address indexed newAsset);

    /// @notice Owner can register a vault and explicitly set its asset (useful for proxies that revert on asset()).
    function addVaultWithAsset(address yoVault, address assetAddr) external onlyOwner {
        if (yoVault == address(0) || assetAddr == address(0)) revert ZeroAddress();
        require(yoVault.code.length > 0, "Vault has no code");
        if (!isVaultAllowed[yoVault]) {
            isVaultAllowed[yoVault] = true;
            _vaultList.push(yoVault);
            emit VaultAdded(yoVault, assetAddr);
        }
        assetOfVault[yoVault] = assetAddr;
    }

    /// @notice Owner can refresh the cached asset() from the vault (after proxy upgrades).
    function refreshVaultAsset(address yoVault) external onlyOwner {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        address oldA = assetOfVault[yoVault];
        address newA = IYoVaultMinimal(yoVault).asset();
        if (newA == address(0)) revert ZeroAddress();
        assetOfVault[yoVault] = newA;
        emit VaultAssetRefreshed(yoVault, oldA, newA);
    }

    function _removeVault(address yoVault) internal {
        if (!isVaultAllowed[yoVault]) return; // idempotent
        delete isVaultAllowed[yoVault];
        delete assetOfVault[yoVault];
        for (uint256 i = 0; i < _vaultList.length; i++) {
            if (_vaultList[i] == yoVault) {
                _vaultList[i] = _vaultList[_vaultList.length - 1];
                _vaultList.pop();
                break;
            }
        }
        emit VaultRemoved(yoVault);
    }

    function getVaults() external view returns (address[] memory) {
        return _vaultList;
    }

    // ========= Events =========
    event GatewayDeposit(
        uint32 indexed partnerId,
        address indexed yoVault,
        address indexed sender,
        address receiver,
        uint256 assets,
        uint256 shares
    );

    event GatewayRedeem(
        uint32 indexed partnerId,
        address indexed yoVault,
        address indexed originalOwner,
        address receiver,
        uint256 shares,
        uint256 assetsOrRequestId,
        bool instant
    );

    // ========= Write: deposit & redeem =========

    function deposit(address yoVault, uint256 assets, address receiver, uint32 partnerId)
        external
        nonReentrant
        returns (uint256 sharesOut)
    {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        address asset = assetOfVault[yoVault];
        if (asset == address(0)) {
            // Fallback for proxies added without known asset at the time
            asset = IYoVaultMinimal(yoVault).asset();
            require(asset != address(0), "asset unresolved");
            assetOfVault[yoVault] = asset; // cache for next time
        }

        IERC20(asset).safeTransferFrom(msg.sender, address(this), assets);

        _safeApproveExact(IERC20(asset), yoVault, assets);

        sharesOut = IYoVaultMinimal(yoVault).deposit(assets, receiver);

        // Cleanup: zero-out allowance to the vault
        IERC20(asset).forceApprove(yoVault, 0);

        emit GatewayDeposit(partnerId, yoVault, msg.sender, receiver, assets, sharesOut);
    }

    function redeem(address yoVault, uint256 shares, address receiver, address ownerOfShares, uint32 partnerId)
        external
        nonReentrant
        returns (uint256 assetsOrRequestId)
    {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        if (ownerOfShares == address(0) || receiver == address(0)) revert ZeroAddress();

        // Pull shares from the true owner into the gateway for this tx (sponsored flow)
        IERC20(yoVault).safeTransferFrom(ownerOfShares, address(this), shares);

        // Call the vault as the owner == gateway, satisfying `owner == msg.sender` in the vault
        assetsOrRequestId = IYoVaultMinimal(yoVault).requestRedeem(shares, receiver, address(this));

        bool instant = assetsOrRequestId > 0;

        emit GatewayRedeem(partnerId, yoVault, ownerOfShares, receiver, shares, assetsOrRequestId, instant);
    }

    // ========= Read helpers =========

    function quoteConvertToShares(address yoVault, uint256 assets) external view returns (uint256) {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        return IYoVaultMinimal(yoVault).convertToShares(assets);
    }

    function quoteConvertToAssets(address yoVault, uint256 shares) external view returns (uint256) {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        return IYoVaultMinimal(yoVault).convertToAssets(shares);
    }

    function quotePreviewDeposit(address yoVault, uint256 assets) external view returns (uint256) {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        return IYoVaultMinimal(yoVault).previewDeposit(assets);
    }

    function quotePreviewRedeem(address yoVault, uint256 shares) external view returns (uint256) {
        if (!isVaultAllowed[yoVault]) revert VaultNotAllowed();
        return IYoVaultMinimal(yoVault).previewRedeem(shares);
    }

    // ========= Internal utils =========
    function _safeApproveExact(IERC20 token, address spender, uint256 amount) internal {
        // Use OZ v5 SafeERC20.forceApprove to handle non-standard tokens
        token.forceApprove(spender, 0);
        token.forceApprove(spender, amount);
    }
    // ========= Allowance helpers =========
    /// @notice Returns the current allowance of `owner` for shares of the given yoVault to this gateway.

    function getShareAllowance(address yoVault, address owner_) external view returns (uint256) {
        return IERC20(yoVault).allowance(owner_, address(this));
    }

    /// @notice Returns the current allowance of `owner` for the underlying asset of the given yoVault to this gateway.
    function getAssetAllowance(address yoVault, address owner_) external view returns (uint256) {
        address asset = assetOfVault[yoVault];
        if (asset == address(0)) {
            // Fallback to fetch asset() if not cached
            try IYoVaultMinimal(yoVault).asset() returns (address resolved) {
                asset = resolved;
            } catch {
                return 0;
            }
        }
        return IERC20(asset).allowance(owner_, address(this));
    }
}
