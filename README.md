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

─ vault/ # Asset-to-share vault primitive

─ staking/ # Staking and reward accounting primitive

test/

── VaultStaking.t.sol

Each primitive includes its own README explaining the design and reasoning in detail.

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
