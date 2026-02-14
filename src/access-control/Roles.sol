//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Roles {
    mapping(address => bool) public operators;
    address public admin;

    error NotAdmin();
    error NotOperator();

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        _onlyAdmin();
        _;
    }

    function _onlyAdmin() public view {
        if (msg.sender != admin) revert NotAdmin();
    }

    modifier onlyOperator() {
        _onlyOperator();
        _;
    }

    function _onlyOperator() public view {
        if (!operators[msg.sender]) revert NotOperator();
    }

    function addOperator(address user) external onlyAdmin {
        operators[user] = true;
    }

    function removeOperator(address user) external onlyAdmin {
        operators[user] = false;
    }
}
