# Constant Product AMM (Uniswap V2–Style)

This folder contains a minimal implementation of a **constant-product Automated Market Maker (AMM)** built from scratch in Solidity.

The goal of this primitive is to deeply understand:

- Invariant-based pricing  
- Liquidity accounting  
- Swap mechanics  
- Slippage  
- Arbitrage dynamics  
- Impermanent loss  
- Fee-driven invariant growth  

This is an educational implementation focused on protocol mechanics rather than production hardening.

---

## Core Invariant

The pool enforces the constant product formula:

``
x * y = k
``

- `x` = reserve of Token A  
- `y` = reserve of Token B  
- `k` = constant product (never decreases; grows with fees)

All swaps move the pool along this curve.

The spot price emerges from reserve ratios:

price(A) = reserveB / reserveA

---

## Liquidity Provision

Liquidity providers deposit **both tokens proportionally** and receive internal LP shares representing proportional ownership of the entire pool.

### First LP

Shares are minted as:

shares = sqrt(amountA * amountB)

The geometric mean ensures ownership is invariant to how value is split between assets.

### Subsequent LPs

Shares are minted proportionally:

```solidity
sharesFromA = amountA * totalShares / reserveA
sharesFromB = amountB * totalShares / reserveB
mintedShares = min(sharesFromA, sharesFromB)
```

---

## Swaps

Swaps preserve the invariant by solving:

``
(newX) * (newY) = k
``

Output is computed as:

```solidity
amountOut = (amountInWithFee * reserveOut) / (reserveIn + amountInWithFee);
```

A 0.3% fee is applied, fees remain in the pool, causing k to increase over time.:

```solidity
amountInWithFee = amountIn * 997 / 1000;
```

---

## Slippage

Trades move along the bonding curve and large swaps relative to pool depth experience worse average prices.

Slippage % is defined as:

```solidity
slippage = (expectedSpotOutput - actualOutput) / expectedSpotOutput
```

- Low liquidity → high slippage
- High liquidity → low slippage

---

## Impermanent Loss

LPs experience impermanent loss due to continuous rebalancing:

The AMM sells appreciating assets and accumulates depreciating assets.

When LPs withdraw, they receive assets at the current reserve ratio rather than their original deposit ratio.

LP profitability depends on fee revenue vs volatility-driven rebalancing loss.

---

## Test Coverage

The test suite validates:

- Liquidity
- First LP share minting
- Proportional share minting
- Reserve updates
- Proportional withdrawals
- Swaps
- Invariant preservation & growth
- Price movement
- Fee application
- Economics
- Slippage behavior
- Impermanent loss simulation
- Arbitrage price convergence

---

## Key Invariants

``
reserveA * reserveB never decreases
``

``
LP shares represent proportional ownership
``

``
Liquidity is always paired
``

``
Swaps preserve curve structure
``

---

## Scope

This is a simplified AMM, the focus is strictly on invariant-based design and core AMM economics

LP shares are internal accounting (not ERC20)

No TWAP oracle

No flash-loan protection

No reentrancy guards

No production-grade hardening
