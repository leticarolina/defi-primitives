//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Escrow {
    error NotAuthorized();
    error ContractIsFinalized();
    error AlreadyDeposited();
    error DeadlineNotReached();
    error NotAllowedReceiver();
    error AmountExceeded(uint256 amountLeft);
    error ReleasePartialAmount();
    error TransferFailed();

    IERC20 public immutable TOKEN;
    address public immutable BUYER;
    address public immutable SELLER;
    address public immutable ARBITER;
    uint256 public immutable AMOUNT;
    uint256 public immutable DEADLINE;
    uint256 public releasedAmount;

    bool public released;
    bool public canceled;
    bool public deposited;

    event EscrowFinalized(bool released);

    constructor(IERC20 _token, address _seller, uint256 _amount, address _arbiter) {
        TOKEN = _token;
        SELLER = _seller;
        AMOUNT = _amount;
        BUYER = msg.sender;
        DEADLINE = block.timestamp + 3 days;
        ARBITER = _arbiter;
    }

    function deposit() external {
        if (msg.sender != BUYER) {
            revert NotAuthorized();
        }
        if (deposited) {
            revert AlreadyDeposited();
        }
        deposited = true;
        // TOKEN.transferFrom(address(this), seller, amount);
        bool success = TOKEN.transferFrom(BUYER, address(this), AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
    }

    function cancel() external {
        if (msg.sender != BUYER && msg.sender != ARBITER) {
            revert NotAuthorized();
        }
        if (canceled || released) {
            revert ContractIsFinalized();
        }
        if (block.timestamp < DEADLINE) {
            revert DeadlineNotReached();
        }
        canceled = true;
        uint256 refund = AMOUNT - releasedAmount;
        bool success = TOKEN.transfer(BUYER, refund);
        if (!success) {
            revert TransferFailed();
        }
        emit EscrowFinalized(false);
    }

    function release() external {
        if (msg.sender != BUYER && msg.sender != ARBITER) {
            revert NotAuthorized();
        }
        if (released || canceled) {
            revert ContractIsFinalized();
        }
        if (releasedAmount != 0) {
            revert ReleasePartialAmount();
        }
        released = true;
        bool success = TOKEN.transfer(SELLER, AMOUNT);
        if (!success) {
            revert TransferFailed();
        }
        emit EscrowFinalized(true);
    }

    function releasePartialAmount(uint256 _amount, address _receiver) public {
        if (released || canceled) {
            revert ContractIsFinalized();
        }
        if (msg.sender != BUYER && msg.sender != ARBITER) {
            revert NotAuthorized();
        }
        if (_receiver != BUYER && _receiver != SELLER) {
            revert NotAllowedReceiver();
        }
        uint256 amountLeft = AMOUNT - releasedAmount;
        if (_amount > amountLeft) {
            revert AmountExceeded(amountLeft);
        }
        releasedAmount += _amount;
        if (releasedAmount == AMOUNT) {
            released = true;
            emit EscrowFinalized(true);
        }
        bool success = TOKEN.transfer(_receiver, _amount);
        if (!success) {
            revert TransferFailed();
        }
    }
}
