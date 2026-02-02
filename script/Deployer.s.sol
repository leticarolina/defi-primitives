// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Vault} from "../src/vault/Vault.sol";
import {VaultStaking} from "../src/staking/VaultStaking.sol";

contract Deployer {
    Vault public vault;
    VaultStaking public vaultStaking;

    function run() public returns (Vault, VaultStaking) {
        vault = new Vault(IERC20(0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9)); //WETH on Sepolia
        vaultStaking = new VaultStaking(
            IERC20(vault),
            IERC20(0x8cA1a0E543b8C02B29e5e9C3f7EC18EEb82b157f),
            1e18
        );

        return (vault, vaultStaking);
    }
}
