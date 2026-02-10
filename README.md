# DeFi Primitives

This repository contains a collection of core DeFi primitives implemented in Solidity.

The goal of this repo is not to build a full application, but to demonstrate understanding of fundamental protocol design patterns commonly used in production DeFi systems.

Each primitive is implemented with a focus on clarity, correctness, and reasoning rather than feature completeness.

---

## Included Primitives

### Vault

A basic asset-to-share vault that:

- accepts ERC20 assets
- issues ERC20 shares representing proportional ownership
- adjusts share value automatically as vault assets change
- mirrors the design behind ERC-4626.

### Staking

A staking system built on top of vault shares that:

- allows users to stake ownership tokens
- distributes rewards over time
- uses reward-per-share accounting to avoid looping over users
- staking logic intentionally separated from the vault

---

### Escrow

A state-based escrow contract that:

- securely holds funds between buyer and seller  
- supports arbiter-based dispute resolution  
- enforces irreversible finalization  
- allows partial releases with strict accounting invariants  

---

### Timelock

A time-based escrow primitive that:

- locks tokens until a predefined unlock time  
- enforces single withdrawal execution  
- models delayed payments and scheduled releases  

---

### Vesting

A linear token vesting contract with cliff behavior that:

- unlocks tokens gradually over time  
- prevents over-claiming through released tracking  
- enforces strict vesting invariants  
- models common token distribution schedules  

---

## Design Principles

The implementations in this repository emphasize:

- Separation of concerns (ownership vs incentives)
- Scalable reward accounting
- Gas efficiency
- Explicit security considerations
- Readability and explainability

The code is intentionally minimal and avoids unnecessary complexity.

---

## Repository Structure

src/

- escrow/ # Escrow contract with partial releases

─ staking/ # Staking and reward accounting primitive

─ vault/ # Asset-to-share vault primitive

- vesting/ # Timelock and linear vesting with cliff

Each primitive includes its own README explaining the design and reasoning in detail and a dedicated testing folder inside test/.

---

## Tooling

This project uses **Foundry** for development and testing.

### Setup

```bash
forge install
forge build
forge test
```

### Notes

These contracts are provided for educational and demonstration purposes.

They are not audited and should not be used in production without proper review.
