# Vault Primitive

## Overview

This vault implements a basic asset-to-share model, where users deposit an ERC20 asset and receive ERC20 shares representing proportional ownership of the vault.

The vault does not track user deposits directly. Instead, it tracks ownership through shares, allowing the value of each share to change over time as the vault’s total assets change.

This design is commonly used in DeFi protocols and is the foundation behind standards like ERC-4626.

---

## Assets vs Shares

- **Assets** are the underlying ERC20 tokens deposited into the vault.
- **Shares** are ERC20 tokens minted by the vault that represent ownership.

Assets represent *value*.  
Shares represent *ownership*.

A user’s claim on the vault is defined by how many shares they hold relative to the total share supply.

---

## Deposit Flow

When a user deposits assets into the vault:

1. The vault calculates how many shares should be minted based on the current ratio between total assets and total shares.
2. If the vault is empty, shares are minted 1:1 with the deposited assets.
3. Otherwise, shares are minted proportionally.
4. The vault pulls the assets from the user using `transferFrom`.
5. The calculated shares are minted to the user.



---

## Withdraw Flow

When a user withdraws:

1. The vault calculates how many assets correspond to the shares being redeemed.
2. The user’s shares are burned.
3. The corresponding assets are transferred from the vault to the user.

The withdrawal process follows the checks-effects-interactions pattern and uses reentrancy protection to prevent double-withdrawal attacks.

---

## Share Conversion Logic

The core formulas used by the vault are:

```
shares = amount * totalSupply / totalAssets
assets = shares * totalAssets / totalSupply
```

As the vault’s total assets increase or decrease, the value of each share adjusts automatically, while ownership remains proportional.

---

## Yield Behavior

When yield enters the vault (for example, through fees or external rewards):

- Total assets increase
- Total shares remain constant
- Each share becomes worth more assets

Early and late users are treated fairly, since ownership is preserved through shares rather than deposit history.

---

## Security Considerations

This vault includes several important safety measures:

- Reentrancy protection on withdrawals
- Explicit input validation
- Safe ERC20 transfers
- Strict separation between accounting and asset movement

Common risks in vault implementations include incorrect share math, rounding errors, and state updates occurring after external calls.

---

## Design Notes

- ERC20 shares are used to allow composability with other DeFi protocols.
- Ownership accounting is intentionally separated from incentive logic.
- The vault is designed to be extended by other contracts, such as staking or reward systems.
