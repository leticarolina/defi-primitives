// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Votes} from "../../lib/openzeppelin-contracts/contracts/governance/utils/Votes.sol";
import {Nonces} from "../../lib/openzeppelin-contracts/contracts/utils/Nonces.sol";

contract MockERC20Votes is ERC20, ERC20Permit, ERC20Votes {
    constructor() ERC20("GovToken", "GOV") ERC20Permit("GovToken") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
