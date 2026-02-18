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

    uint256 constant FEE_MULTIPLIER = 997; // Fee: 0.3%
    uint256 constant FEE_DENOMINATOR = 1000;

    function setUp() public {
        tokenA = new MockERC20("Wrapped Ether", "WETH");
        tokenB = new MockERC20("USDC", "USDC");

        // Deploy AMM
        amm = new AMM(address(tokenA), address(tokenB));

        // Mint tokens for LP and trader
        tokenA.mint(lp, 100_000 ether);
        tokenB.mint(lp, 100_000 ether);
        tokenA.mint(trader, 100_000 ether);
        tokenB.mint(trader, 100_000 ether);

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

    modifier lpAddsLiquidity() {
        address lp2 = address(0x03);
        tokenA.mint(lp2, 100_000 ether);
        tokenB.mint(lp2, 100_000 ether);

        vm.startPrank(lp2);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(1 ether, 3_000 ether);
        vm.stopPrank();
        _;
    }

    /* ------------------------------------------------------------ */
    /*                         ADD LIQUIDITY                        */
    /* ------------------------------------------------------------ */

    function test_addLiquidity_firstLPMintsShares() public view {
        assertEq(amm.totalShares(), amm.sqrt(INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B));

        assertEq(amm.shares(lp), amm.sqrt(INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B));

        assertEq(amm.reserveA(), INITIAL_LIQUIDITY_A);
        assertEq(amm.reserveB(), INITIAL_LIQUIDITY_B);
    }

    function testAddLiquidity_SecondLPMintsMinimum() public {
        // First LP already added in setUp()
        address lp2 = address(0x03);
        tokenA.mint(lp2, 100_000 ether);
        tokenB.mint(lp2, 100_000 ether);

        // Pool ratio is (1 A : 3 B) and lp2 provides wrong ratio intentionally
        uint256 amountA = 1 ether;
        uint256 amountB = 2_000 ether; // should be 3 to match
        uint256 previousTotalShares = amm.totalShares();
        uint256 previousReserveA = amm.reserveA();
        uint256 previousReserveB = amm.reserveB();

        // shares from each side
        uint256 sharesFromA = (amountA * previousTotalShares) / amm.reserveA();
        uint256 sharesFromB = (amountB * previousTotalShares) / amm.reserveB();

        vm.startPrank(lp2);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(amountA, amountB);
        vm.stopPrank();

        uint256 minted = amm.min(sharesFromA, sharesFromB);

        assertLt(sharesFromB, sharesFromA);
        assertEq(amm.shares(lp2), minted);
        assertEq(amm.shares(lp2), sharesFromB);
        assertEq(amm.reserveA(), previousReserveA + amountA);
        assertEq(amm.reserveB(), previousReserveB + amountB);
        assertEq(amm.totalShares(), previousTotalShares + minted);
    }

    /* ------------------------------------------------------------ */
    /*                         REMOVE LIQUIDITY                     */
    /* ------------------------------------------------------------ */

    function test_removeLiquidity_firstLP() public lpAddsLiquidity {
        uint256 previousUserShares = amm.shares(lp);
        uint256 previousTotalShares = amm.totalShares();
        uint256 previousReserveA = amm.reserveA();
        uint256 previousReserveB = amm.reserveB();

        uint256 sharesToBurn = amm.shares(lp) / 2; // around 273 shares
        uint256 amountA = (sharesToBurn * previousReserveA) / previousTotalShares;
        uint256 amountB = (sharesToBurn * previousReserveB) / previousTotalShares;

        vm.startPrank(lp);
        amm.removeLiquidity(sharesToBurn);

        assertEq(amm.shares(lp), previousUserShares - sharesToBurn);
        assertEq(amm.totalShares(), previousTotalShares - sharesToBurn);
        assertEq(amm.reserveA(), previousReserveA - amountA);
        assertEq(amm.reserveB(), previousReserveB - amountB);
    }

    /* ------------------------------------------------------------ */
    /*                         HELPERS                              */
    /* ------------------------------------------------------------ */
    function test_min_returnsMinimumValue() public view {
        uint256 minimum = amm.min(19, 22);
        assertEq(minimum, 19);
    }

    function test_sqrt_basic() public view {
        uint256 actualShares = amm.sqrt(INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B);

        // convert from wei-style to human number
        uint256 actualInTokens = actualShares / 1e18;

        // sqrt(300000) ≈ 547.72 → floored to 547 in integer math
        uint256 expectedInTokens = 547;

        assertEq(actualInTokens, expectedInTokens);
        assertEq(amm.sqrt(100), 10);
        assertEq(amm.sqrt(25), 5);
        assertEq(amm.sqrt(2), 1);
    }

    /* ------------------------------------------------------------ */
    /*                            SWAPS                             */
    /* ------------------------------------------------------------ */

    function test_swapAToB_updatesReservesConceptually() public {
        //user will swap ETH(A) for USDC(B) aka send ETH and gets USDC.
        uint256 amountAIn = 1 ether;
        uint256 previousReserveA = amm.reserveA();
        uint256 previousReserveB = amm.reserveB();
        uint256 oldK = previousReserveA * previousReserveB;
        uint256 beforePrice = previousReserveB / previousReserveA;

        vm.prank(trader);
        amm.swapAToB(amountAIn); //1 ETH

        uint256 newReserveA = amm.reserveA();
        uint256 newReserveB = amm.reserveB();
        uint256 newK = newReserveA * newReserveB;
        uint256 afterPrice = newReserveB / newReserveA;

        assertEq(newReserveA, previousReserveA + amountAIn);
        assertLt(newReserveB, previousReserveB); // B should decrease
        assertGe(newK, oldK); //invariant a * b >= K
        assertLt(afterPrice, beforePrice);
    }

    function test_swapAToB_exactOutput() public {
        //current pool 10ETH 30_000USDC
        uint256 amountAIn = 1 ether;
        uint256 previousReserveA = amm.reserveA();
        uint256 previousReserveB = amm.reserveB();

        vm.prank(trader);
        amm.swapAToB(amountAIn); //1 ETH

        uint256 newReserveA = amm.reserveA();
        uint256 newReserveB = amm.reserveB();
        uint256 amountInWithFee = (amountAIn * FEE_MULTIPLIER) / FEE_DENOMINATOR;
        uint256 expectedBOut = (amountInWithFee * previousReserveB) / (previousReserveA + amountInWithFee);
        uint256 actualBOut = previousReserveB - newReserveB;

        assertLt(amountInWithFee, amountAIn);
        assertEq(amountInWithFee, (amountAIn * 997) / 1000);
        assertApproxEqAbs(actualBOut, expectedBOut, 1); // allow tiny rounding error
        assertEq(newReserveA, previousReserveA + amountAIn);
        assertEq(newReserveB, previousReserveB - actualBOut);
    }

    function test_swapBToA_exactOutput() public {
        uint256 amountBIn = 1_500 ether; //1_500USDC
        uint256 previousReserveA = amm.reserveA();
        uint256 previousReserveB = amm.reserveB();

        vm.prank(trader);
        amm.swapBToA(amountBIn);

        uint256 amountInWithFee = (amountBIn * FEE_MULTIPLIER) / FEE_DENOMINATOR;

        uint256 newReserveA = amm.reserveA();
        uint256 newReseveB = amm.reserveB();
        uint256 expectedAOut = (amountInWithFee * previousReserveA) / (previousReserveB + amountInWithFee);
        uint256 actualAOut = previousReserveA - newReserveA;

        assertEq(expectedAOut, actualAOut);
        assertEq(amountInWithFee, (amountBIn * 997) / 1000);
        assertEq(newReserveA, previousReserveA - actualAOut);
        assertEq(newReseveB, previousReserveB + amountBIn);
    }

    /* ------------------------------------------------------------ */
    /*                     INAVRIANT OVER TIME                      */
    /* ------------------------------------------------------------ */

    function test_inavriant_k_GrowsWithFees() public {
        uint256 kBeforeSwaps = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        amm.swapAToB(1 ether);
        amm.swapBToA(1000 ether);
        vm.stopPrank();

        uint256 kAfterSwaps = amm.reserveA() * amm.reserveB();
        assertGt(kAfterSwaps, kBeforeSwaps);
        console.log(kBeforeSwaps, kAfterSwaps);
    }

    function test_impermanentLoss_exists() public {
        //LP initial hold value
        uint256 initialHoldA = INITIAL_LIQUIDITY_A;
        uint256 initialHoldB = INITIAL_LIQUIDITY_B;

        // simulate big price move: trader buys A with B
        vm.prank(trader);
        amm.swapBToA(10_000 ether); //market moved + arbitrage corrected pool

        uint256 lpShares = amm.shares(lp); // LP withdraws all liquidity

        uint256 reserveA = amm.reserveA();
        uint256 reserveB = amm.reserveB();
        uint256 totalShares = amm.totalShares();

        uint256 lpAOut = (lpShares * reserveA) / totalShares;
        uint256 lpBOut = (lpShares * reserveB) / totalShares;

        uint256 newPrice = reserveB / reserveA; // get new price after shift

        // LP total value after withdrawing (in B terms)
        uint256 lpValueAfter = lpBOut + (lpAOut * newPrice);

        // HOLD value if LP never provided liquidity
        uint256 hodlValue = initialHoldB + (initialHoldA * newPrice);

        console.log("LP value:", lpValueAfter); //79997498123592694520912
        console.log("HODL value:", hodlValue); //83290000000000000000000

        assertLt(lpValueAfter, hodlValue);
    }

    function test_arbitrage_correctsPrice() public {
        // Initial price (B per A)
        uint256 initialPrice = amm.reserveB() / amm.reserveA(); //3.000 B per A

        // Step 1: distort price (buy B with A)
        vm.prank(trader);
        amm.swapAToB(2 ether); // push price away from equilibrium
        //2 ETH

        uint256 distortedPrice = amm.reserveB() / amm.reserveA(); // B per A after amm.swapAToB(2 ether)
        //30k - 5.983 = 24.017 USDC / 12 ETH = 2.0014 B per A

        assertLt(distortedPrice, initialPrice); // price must move

        // Step 2: arbitrage trade in opposite direction
        vm.prank(trader);
        amm.swapBToA(6_000 ether); // push back toward original price
        //5.984 USDC after fee enters and 2.39 ETH leaves

        uint256 correctedPrice = amm.reserveB() / amm.reserveA();

        // Distance to original should shrink
        uint256 distortedGap =
            initialPrice > distortedPrice ? initialPrice - distortedPrice : distortedPrice - initialPrice;

        uint256 correctedGap =
            initialPrice > correctedPrice ? initialPrice - correctedPrice : correctedPrice - initialPrice;

        assertLt(correctedGap, distortedGap);
    }
}
