// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {MockERC20} from "./MockERC20.sol";
import {IYoVaultMinimal} from "../interfaces/IYoVaultMinimal.sol";

/**
 * Minimal ERC4626-ish mock vault:
 * - Shares token is this contract (ERC20-like via MockERC20)
 * - 1:1 exchange (assets <-> shares)
 * - requestRedeem burns shares from msg.sender; if instant==true pays assets immediately, else returns 0
 */
contract MockYoVault is MockERC20, IYoVaultMinimal {
    MockERC20 public immutable assetToken; // underlying
    bool public instant;

    constructor(address _asset, bool _instant) MockERC20("MockShares", "MSHARE", 18) {
        assetToken = MockERC20(_asset);
        instant = _instant;
    }

    function setInstant(bool v) external {
        instant = v;
    }

    // IYoVaultMinimal
    function asset() external view override returns (address) {
        return address(assetToken);
    }

    function deposit(uint256 assets, address receiver) external override returns (uint256 shares) {
        require(assetToken.transferFrom(msg.sender, address(this), assets), "pull");
        shares = assets; // 1:1
        mint(receiver, shares);
    }

    function requestRedeem(uint256 shares, address receiver, address owner)
        external
        override
        returns (uint256 assetsOrRequestId)
    {
        require(owner == msg.sender, "owner!=sender"); // mimic real vault check
        burn(msg.sender, shares);

        if (instant) {
            assetsOrRequestId = shares;
            require(assetToken.transfer(receiver, assetsOrRequestId), "pay");
        } else {
            assetsOrRequestId = 0; // async path
        }
    }

    // Quotes
    function convertToShares(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function convertToAssets(uint256 shares) external pure override returns (uint256) {
        return shares;
    }

    function previewDeposit(uint256 assets) external pure override returns (uint256) {
        return assets;
    }

    function previewRedeem(uint256 shares) external pure override returns (uint256) {
        return shares;
    }
}
