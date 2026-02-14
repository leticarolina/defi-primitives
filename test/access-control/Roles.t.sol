//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Roles} from "../../src/access-control/Roles.sol";

contract RolesTest is Test {
    Roles roles;
    address admin = address(0x1);
    address operator = address(0x2);
    address nonOperator = address(0x3);

    function setUp() public {
        vm.prank(admin);
        roles = new Roles();
    }

    function test_constructor_setsAdmin() public view {
        assertEq(roles.admin(), admin);
    }

    function test_addOperator() public {
        vm.prank(admin);
        roles.addOperator(operator);
        assertTrue(roles.operators(operator));
    }

    function test_removeOperator() public {
        vm.prank(admin);
        roles.addOperator(operator);
        vm.prank(admin);
        roles.removeOperator(operator);
        assertFalse(roles.operators(operator));
    }

    function test_addOperator_reverts_ifNotAdmin() public {
        vm.prank(nonOperator);
        vm.expectRevert(Roles.NotAdmin.selector);
        roles.addOperator(operator);
    }

    function test_removeOperator_reverts_ifNotAdmin() public {
        vm.prank(nonOperator);
        vm.expectRevert(Roles.NotAdmin.selector);
        roles.removeOperator(operator);
    }

    function test_onlyOperator_modifier() public {
        vm.prank(admin);
        roles.addOperator(operator);

        vm.prank(operator);
        roles._onlyOperator(); // should not revert

        vm.prank(nonOperator);
        vm.expectRevert(Roles.NotOperator.selector);
        roles._onlyOperator();
    }

    function test_onlyAdmin_modifier() public {
        vm.prank(admin);
        roles._onlyAdmin(); // should not revert

        vm.prank(nonOperator);
        vm.expectRevert(Roles.NotAdmin.selector);
        roles._onlyAdmin();
    }
}
