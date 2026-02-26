// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract FeeController {
    address public governance;
    uint256 public fee;

    constructor(address _governance) {
        governance = _governance;
        fee = 30; // 0.3%
    }

    modifier onlyGovernance() {
        _onlyGovernance();
        _;
    }

    function _onlyGovernance() internal view {
        if (msg.sender != governance) {
            revert("Only governance");
        }
    }

    function setFee(uint256 newFee) external onlyGovernance {
        fee = newFee;
    }
}
