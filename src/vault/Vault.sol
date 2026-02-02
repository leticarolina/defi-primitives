//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

contract Vault is ERC20, ReentrancyGuard {
    error AmountZero();
    error NoAssetsInTheVault();
    error NoSharesInTheVault();
    error InsufficientShares();
    error ZeroSharesMinted();
    error TransferFailed();

    IERC20 public immutable ASSET;

    constructor(IERC20 _asset) ERC20("Vault Share", "vSHARE") {
        ASSET = _asset;
    }

    function deposit(uint256 amount) public {
        //check input
        if (amount <= 0) {
            revert AmountZero();
        }

        //effect - calculate shares, update vault accounting
        uint256 shares = convertToShares(amount);
        if (shares <= 0) {
            revert ZeroSharesMinted();
        }

        if (!ASSET.transferFrom(msg.sender, address(this), amount)) {
            revert TransferFailed();
        }

        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) public nonReentrant {
        //check - user shares are not zero
        if (shares <= 0) {
            revert AmountZero();
        }

        //effect - calculate amount, update vault accounting
        uint256 amount = convertToAssets(shares);
        if (amount <= 0) {
            revert AmountZero();
        }
        _burn(msg.sender, shares);

        //interactions - send tokens from vault to user
        SafeERC20.safeTransfer(ASSET, msg.sender, amount);
    }

    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this));
    }

    function convertToShares(uint256 amount) public view returns (uint256) {
        uint256 supply = totalSupply();

        if (supply == 0) return amount;
        uint256 currentTotalAssets = totalAssets();
        if (currentTotalAssets <= 0) {
            revert NoAssetsInTheVault();
        }
        return (amount * supply) / currentTotalAssets;
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        if (supply == 0) revert NoAssetsInTheVault();
        uint256 currentTotalAssets = totalAssets();
        return (shares * currentTotalAssets) / supply;
    }
}
