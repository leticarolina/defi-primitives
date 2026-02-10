// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Timelock {
    error NotBeneficiary();
    error NotUnlockedYet();
    error AlreadyWithdrawn();
    error TransferFailed();

    IERC20 public immutable TOKEN;
    address public immutable BENEFICIARY;
    uint256 public immutable UNLOCK_TIME;
    uint256 public immutable AMOUNT;

    bool public withdrawn;

    constructor(IERC20 _token, address _beneficiary, uint256 _amount, uint256 _unlockTime) {
        TOKEN = _token;
        BENEFICIARY = _beneficiary;
        AMOUNT = _amount;
        UNLOCK_TIME = _unlockTime;
    }

    function deposit() external {
        if (withdrawn) {
            revert AlreadyWithdrawn();
        }
        bool success = TOKEN.transferFrom(msg.sender, address(this), AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
    }

    function withdraw() external {
        if (msg.sender != BENEFICIARY) {
            revert NotBeneficiary();
        }

        if (block.timestamp < UNLOCK_TIME) {
            revert NotUnlockedYet();
        }

        if (withdrawn) {
            revert AlreadyWithdrawn();
        }

        withdrawn = true;
        bool success = TOKEN.transfer(BENEFICIARY, AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
    }
}

/*
Timelocks are escrow contracts where time is the only release condition. The contract itself holds the funds, custody is identical.

So where do the funds come from?
There are common patterns in real protocols:
Pattern 1 — Funded in constructor
Pattern 2 — Funded via a deposit function
Pattern 3 — Funded via airdrop

key state variables:
- token: the ERC20 token being held in timelock
- beneficiary: the address that will receive the tokens when unlocked
- unlockTime: the timestamp when the tokens can be withdrawn

*/
