# 🔐 Escrow — DeFi Primitive

This contract implements a **deterministic on-chain escrow** with support for:

- single deposit
- optional arbiter
- time-based cancellation
- partial releases
- irreversible finalization

---

## What is Escrow?

An escrow is a **state machine that temporarily holds funds** and releases them only when predefined conditions are met.

On-chain escrow removes the need for trusted intermediaries by enforcing:

- authorization rules
- time constraints
- accounting invariants
- irreversible settlement

---

## Roles

- **Buyer**  
  Funds the escrow and initiates settlement.

- **Seller**  
  Receives funds if conditions are met.

- **Arbiter**  
  An optional trusted third party that can resolve disputes or unblock funds.

---

## Core State Variables

- `amount` - Total escrowed amount
- `releasedAmount`- Amount already released
- `deposited` - Prevents double funding
- `released` - Final success state
- `canceled` - Final failure state
- `deadline` - Time-based escape hatch
- `buyer/seller/arbiter` - Authorization roles

---

## Why Track `releasedAmount`?

Escrow correctness relies on **explicit accounting**, not implicit balances.

Instead of checking the contract’s token balance, the contract tracks:

```solidity
amountLeft = amount - releasedAmount;
````

This ensures:

- no over-release
- correct refunds
- deterministic finalization
- resistance to unexpected token transfers

---

## Partial Releases

Partial releases allow incremental settlement while preserving safety:

- Releases are capped by `amountLeft`
- Finalization occurs automatically when `releasedAmount == amount`
- Full `release()` is disabled after partial settlement to avoid mixed accounting models

---

## Time Locks & Safety

A deadline allows:

- buyer or arbiter to cancel after inactivity
- prevention of indefinite fund lock
- deterministic resolution paths

```solidity
deadline = block.timestamp + 3 days;
```

---

## Security Considerations

The contract enforces:

- single deposit
- irreversible finalization
- strict authorization
- conservation of value
- safe ERC-20 transfers

Common escrow vulnerabilities (double release, invalid state transitions, over-withdrawals) are explicitly prevented.
