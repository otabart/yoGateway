// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Minimal surface the gateway needs from a yoVault (ERC4626-like)
interface IYoVaultMinimal {
    function asset() external view returns (address);
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    /// @dev If enough liquidity: returns assets; otherwise returns 0 (async).
    function requestRedeem(uint256 shares, address receiver, address owner) external returns (uint256 assetsOrRequestId);

    // Quotes
    function convertToShares(uint256 assets) external view returns (uint256);
    function convertToAssets(uint256 shares) external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
}