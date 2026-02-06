//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Vesting {
    error NotBeneficiary();
    error NothingToClaim();
    error TransferFailed();

    IERC20 public immutable TOKEN;
    address public immutable BENEFICIARY;

    uint256 public immutable START;
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
vested = total amount * (time elapsed / total vesting time)
claimable amount =  vested - amount already withdrawn

Key state variables:
- total amount
- start time
- end time / duration
- amount withdrawn

What is a vesting contract?
Vesting enforces time-based linear unlock with invariants preventing early claims and over-distribution,
typically implemented using lazy accounting.


*/
