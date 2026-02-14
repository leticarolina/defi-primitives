// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {AMM} from "../../src/amm/AMM.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract AMMTest is Test {
    AMM amm;

    MockERC20 tokenA; // e.g. WETH
    MockERC20 tokenB; // e.g. USDC

    address lp = address(0x01);
    address trader = address(0x02);

    uint256 constant INITIAL_LIQUIDITY_A = 10 ether;
    uint256 constant INITIAL_LIQUIDITY_B = 30000 ether;

    function setUp() public {
        tokenA = new MockERC20("Wrapped Ether", "WETH");
        tokenB = new MockERC20("USDC", "USDC");

        // Deploy AMM
        amm = new AMM(address(tokenA), address(tokenB));

        // Mint tokens for LP and trader
        tokenA.mint(lp, 1_000 ether);
        tokenB.mint(lp, 1_000 ether);
        tokenA.mint(trader, 1_000 ether);
        tokenB.mint(trader, 1_000 ether);

        // LP approves AMM
        vm.startPrank(lp);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        // Trader approves AMM
        vm.startPrank(trader);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();

        // Initial liquidity (first LP sets ratio)
        vm.startPrank(lp);
        amm.addLiquidity(INITIAL_LIQUIDITY_A, INITIAL_LIQUIDITY_B);
        vm.stopPrank();
    }

    function testSwapMovesPrice() public {}

    function testImpermanentLoss() public {}

    function testFeesAccumulate() public {}

    function testInvariantHolds() public {}
}
