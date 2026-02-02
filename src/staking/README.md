# Vault Staking Primitive

## Overview

This contract implements a staking system on top of a vault that uses ERC20 shares.

Users stake vault shares (not underlying assets) to earn rewards over time.  
The staking contract does not manage asset custody or share pricing; it only manages incentives.

This separation allows the vault and staking logic to remain modular and composable.

---

## Why Staking Uses Vault Shares

The vault is responsible for:

- holding assets
- minting and burning shares
- maintaining ownership proportions

The staking contract is responsible for:

- tracking staked shares
- distributing rewards over time

By staking shares instead of assets, the staking system automatically adapts to changes in vault value without additional logic.

---

## Core Challenge

A staking system must distribute rewards fairly over time without looping over all users.

Looping over users is not scalable, as gas costs grow linearly with the number of participants.

---

## Solution: Reward-Per-Share Accounting

This contract uses a reward-per-share accumulator to track rewards efficiently.

`rewardPerShare` represents how much reward **one staked share** has earned over time.

As time passes, rewards are added to the system at a fixed `rewardRate`, and the accumulator increases accordingly.

---

## User Checkpoints

Each user stores a checkpoint called `userRewardPerSharePaid`.

This value records the global reward-per-share value at the moment the user last interacted with the contract.

When rewards are calculated, only the difference between the current reward-per-share and the user’s checkpoint is considered.

This prevents users from earning rewards that were accrued before they staked.

---

## Lazy Reward Accounting

Rewards are not distributed continuously.

Instead, rewards are:

- accumulated globally over time
- settled only when users interact (stake, withdraw, or claim)

This approach keeps gas usage constant and makes the system scalable.

---

## Reward Calculation

The amount of rewards earned by a user is calculated as:

```solidity
earned = previousRewards + (userStakedShares * (rewardPerShare - userCheckpoint))
```

This ensures rewards are distributed proportionally based on both:

- time
- ownership

---

## Stake Flow

When a user stakes:

1. The global reward state is updated.
2. The user’s pending rewards are settled.
3. Vault shares are transferred from the user to the staking contract.
4. The user’s staked balance and total staked amount are updated.

---

## Withdraw Flow

When a user withdraws:

1. The global reward state is updated.
2. The user’s pending rewards are settled.
3. The user’s staked balance is reduced.
4. Vault shares are transferred back to the user.

---

## Security Considerations

Key security aspects include:

- Updating reward accounting before balance changes
- Preventing reward theft through user checkpoints
- Avoiding loops over users
- Using safe token transfers
- Ensuring consistent precision through fixed-point math

Common staking vulnerabilities include incorrect checkpoint handling, reward dilution, and precision errors.

---

## Design Notes

- The staking contract assumes the vault shares follow the ERC20 standard.
- Reward logic is intentionally separated from asset and ownership logic.
- This pattern is commonly used in production DeFi protocols.
- Rewards are calculated first, then transferred to the user in the reward token.
