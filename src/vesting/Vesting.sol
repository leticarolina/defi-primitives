//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vesting {
    error NotBeneficiary();
    error NothingToClaim();
    error TransferFailed();

    IERC20 public immutable TOKEN;
    address public immutable BENEFICIARY;
    uint256 public immutable START; //aka cliff time, before this time no tokens are vested
    uint256 public immutable DURATION;
    uint256 public immutable TOTAL_AMOUNT;

    uint256 public released;

    constructor(IERC20 _token, address _beneficiary, uint256 _totalAmount, uint256 _start, uint256 _duration) {
        TOKEN = _token;
        BENEFICIARY = _beneficiary;
        TOTAL_AMOUNT = _totalAmount;
        START = _start;
        DURATION = _duration;
    }

    function deposit() external {
        bool success = TOKEN.transferFrom(msg.sender, address(this), TOTAL_AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
    }

    function claim() external {
        if (msg.sender != BENEFICIARY) {
            revert NotBeneficiary();
        }

        uint256 vested = vestedAmount(); //vested is the amount that based on time should be unlocked
        uint256 claimable = vested - released; //claimable is the amount that can be claimed now, which is vested minus what has already been released

        if (claimable == 0) {
            revert NothingToClaim();
        }

        released += claimable; // update released to add the claimable amount, so Next time claim is called, it will only allow claiming the newly vested amount
        bool success = TOKEN.transfer(BENEFICIARY, claimable);
        if (!success) {
            revert TransferFailed();
        }
    }

    function vestedAmount() public view returns (uint256) {
        if (block.timestamp <= START) {
            return 0;
        }

        uint256 elapsed = block.timestamp - START;

        if (elapsed >= DURATION) {
            return TOTAL_AMOUNT;
        }

        return (TOTAL_AMOUNT * elapsed) / DURATION;
    }
}

/*
Vesting is timelock + partial release accounting.
So it will feel like escrow partial releases.

Core formula used everywhere in DeFi:
vested = total amount * elapsed time / duration
claimable amount = vested - amount already withdrawn

Key state variables:
- total amount
- start time
- end time / duration
- amount withdrawn

What is a vesting contract?
Vesting enforces time-based linear unlock with invariants preventing early claims and over-distribution,
typically implemented using lazy accounting.
A vesting contract holds tokens and releases them linearly over time.
The invariant is that claimed tokens never exceed the proportion unlocked by elapsed time.
We track claimed amount to prevent double withdrawals and compute claimable lazily.

vesting invariants:
- Contract always holds enough to pay
- No claims before start time
- No claims beyond vested amount
- Accurate tracking of already claimed amounts
- After duration, everything is claimable

Why do we track claimed instead of just checking token balance?
token balance can be manipulated (airdrops, mistakes, griefing)
state should be source of truth
avoids accounting attacks

Could someone grief the contract by sending extra tokens?
Yes — but it shouldn’t affect logic.
That’s why you rely on claimed, not balances.

Main security risks in vesting:
- Over-claiming: Users could try to claim more than their vested amount.
- Front-running: Attackers could exploit the timing of claims.
- Contract bugs: Flaws in the vesting logic could be exploited, not updating claimed correctly, time logic bugs.
- Division by zero errors: Ensure duration is never zero to avoid runtime errors.

*/
