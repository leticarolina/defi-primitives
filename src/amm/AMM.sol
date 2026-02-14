//SPDX-License-Identifier:MIT

import {IERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

pragma solidity ^0.8.0;

contract AMM {
    IERC20 public tokenA;
    IERC20 public tokenB;

    // How many tokens the pool currently holds
    uint256 public reserveA;
    uint256 public reserveB;

    // LP ownership accounting (like vault shares)
    uint256 public totalShares; //LP shares
    mapping(address => uint256) public shares; //how many shares this address has

    // Fee: 0.3%
    uint256 constant FEE_MULTIPLIER = 997;
    uint256 constant FEE_DENOMINATOR = 1000;

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    /* ------------------------------------------------------------ */
    /*                       ADD LIQUIDITY                          */
    /* ------------------------------------------------------------ */

    function addLiquidity(uint256 amountA, uint256 amountB) external {
        // User sends tokens to pool
        //ERC20 'transfer' and 'transferFrom' calls should check the return value
        require(
            tokenA.transferFrom(msg.sender, address(this), amountA),
            "Fail"
        );
        require(
            tokenB.transferFrom(msg.sender, address(this), amountB),
            "Fail"
        );

        uint256 mintedShares;

        if (totalShares == 0) {
            // First liquidity provider defines pool ratio and we mint shares using sqrt to represent total pool size.
            // sqrt keeps ownership proportional
            mintedShares = sqrt(amountA * amountB); //initial LP shares represent geometric average of deposits
        } else {
            // Later providers must match current ratio
            // We compute two hypothetical ownership contributions and mint shares based on the smaller proportional contribution
            uint256 sharesFromA = (amountA * totalShares) / reserveA;
            uint256 sharesFromB = (amountB * totalShares) / reserveB;
            //Liquidity is formed by paired assets. Ownership can only be minted where pairs are complete.
            mintedShares = min(sharesFromA, sharesFromB);
        }

        shares[msg.sender] += mintedShares;
        totalShares += mintedShares;

        // Update pool balances
        reserveA += amountA;
        reserveB += amountB;
    }

    /* ------------------------------------------------------------ */
    /*                         SWAPPING                             */
    /* ------------------------------------------------------------ */

    function swapAToB(uint256 amountAIn) external {
        // User sends token A to pool
        require(
            tokenA.transferFrom(msg.sender, address(this), amountAIn),
            "Fail"
        );

        // Take fee
        uint256 amountInWithFee = (amountAIn * FEE_MULTIPLIER) /
            FEE_DENOMINATOR;

        // Calculate how much B to send out
        //"give me a proportional chunk of the opposite reserve, but adjusted so invariant holds"
        uint256 amountBOut = (amountInWithFee * reserveB) /
            (reserveA + amountInWithFee);

        // Update pool balances
        reserveA += amountAIn;
        reserveB -= amountBOut;

        // Send token B to user
        require(tokenB.transfer(msg.sender, amountBOut), "Fail");
    }

    function swapBToA(uint256 amountBIn) external {
        require(
            tokenB.transferFrom(msg.sender, address(this), amountBIn),
            "Fail"
        );

        uint256 amountInWithFee = (amountBIn * FEE_MULTIPLIER) /
            FEE_DENOMINATOR;

        uint256 amountAOut = (amountInWithFee * reserveA) /
            (reserveB + amountInWithFee);

        reserveB += amountBIn;
        reserveA -= amountAOut;

        require(tokenA.transfer(msg.sender, amountAOut), "Fail");
    }

    /* ------------------------------------------------------------ */
    /*                      REMOVE LIQUIDITY                        */
    /* ------------------------------------------------------------ */

    function removeLiquidity(uint256 shareAmount) external {
        // Calculate proportional ownership
        uint256 amountA = (shareAmount * reserveA) / totalShares;

        uint256 amountB = (shareAmount * reserveB) / totalShares;

        // Burn LP shares
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        // Update pool balances
        reserveA -= amountA;
        reserveB -= amountB;

        // Send tokens back
        require(tokenA.transfer(msg.sender, amountA), "Fail");
        require(tokenB.transfer(msg.sender, amountB), "Fail");
    }

    /* ------------------------------------------------------------ */
    /*                         HELPERS                              */
    /* ------------------------------------------------------------ */

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Babylonian square root (used only for first LP)
    //"give me the square root of a number"
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
