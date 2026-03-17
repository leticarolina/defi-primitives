//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "../../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title Minimal ERC20 Vault
/// @author Leticia Azevedo
/// @notice Allows users to deposit an ERC20 asset and receive proportional vault shares
/// @dev Shares represent proportional ownership of vault assets. Conversion math follows ERC4626 model simplified.
contract Vault is ERC20, ReentrancyGuard {
    error AmountZero();
    error NoAssetsInTheVault();
    error NoSharesInTheVault();
    error InsufficientShares();
    error ZeroSharesMinted();
    error TransferFailed();

    IERC20 public immutable ASSET;
    uint256 constant MINIMUM_SHARES = 1e3;

    event Deposit(address indexed user, uint256 assets, uint256 shares);
    event Withdraw(address indexed user, uint256 assets, uint256 shares);

    constructor(IERC20 _asset) ERC20("Vault Share", "vSHARE") {
        ASSET = _asset;
    }

    // function deposit(uint256 amount) public {
    //     //check input
    //     if (amount == 0) {
    //         revert AmountZero();
    //     }

    //     //effect - calculate shares
    //     uint256 shares = convertToShares(amount);
    //     if (shares <= 0) {
    //         revert ZeroSharesMinted();
    //     }

    //     SafeERC20.safeTransferFrom(ASSET, msg.sender, address(this), amount);

    //     _mint(msg.sender, shares);
    //     emit Deposit(msg.sender, amount, shares);
    // }

    function deposit(uint256 amount) public {
        if (amount == 0) revert AmountZero();

        uint256 supply = totalSupply();
        uint256 shares;

        if (supply == 0) {
            shares = amount - MINIMUM_SHARES;
            _mint(address(0), MINIMUM_SHARES); // lock initial shares
        } else {
            shares = convertToShares(amount);
        }

        if (shares == 0) revert ZeroSharesMinted();

        SafeERC20.safeTransferFrom(ASSET, msg.sender, address(this), amount);
        _mint(msg.sender, shares);
        emit Deposit(msg.sender, amount, shares);
    }

    function withdraw(uint256 shares) public nonReentrant {
        //check - shares are not zero
        if (shares <= 0) {
            revert AmountZero();
        }
        if (shares > balanceOf(msg.sender)) {
            revert InsufficientShares();
        }

        //effect - calculate amount
        uint256 amount = convertToAssets(shares);
        if (amount <= 0) {
            revert AmountZero();
        }

        _burn(msg.sender, shares);

        //interactions - send tokens from vault to user
        SafeERC20.safeTransfer(ASSET, msg.sender, amount);
        emit Withdraw(msg.sender, amount, shares);
    }

    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this));
    }

    function convertToShares(uint256 amount) public view returns (uint256) {
        uint256 supply = totalSupply(); // current total shares
        if (supply == 0) return amount;

        uint256 currentTotalAssets = totalAssets(); // collateral value in the vault
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
