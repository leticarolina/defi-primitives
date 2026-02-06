# ⏳ Timelock & Vesting — DeFi Primitives

This folder contains two foundational time-based custody primitives used across DeFi protocols:

- **Timelock** — funds are locked until a specific timestamp
- **Vesting** — funds unlock linearly over a fixed duration

Both contracts hold ERC20 tokens in custody and release them according to deterministic conditions.

---

## Timelock

### Purpose

Locks tokens until a predefined unlock time, after which the beneficiary can withdraw the full amount.

Common use cases:

- delayed payments
- token cliffs
- inheritance contracts
- governance timelocks

---

### Core Flow

1. Depositor transfers tokens into the contract  
2. Contract holds custody  
3. After `unlockTime`, beneficiary withdraws once  

---

### Key Invariants

- Funds cannot be withdrawn before unlock time  
- Withdrawal happens only once
- Explicit withdrawn state prevents double spending
- Only the beneficiary can withdraw  

---

## Vesting

### Purpose

Gradually releases tokens over time rather than all at once.

Instead of a single unlock moment, tokens unlock proportionally based on elapsed time.

Common use cases:

- team token vesting
- investor schedules
- reward emissions

---

### Core Formula

```solidity
vested = totalAmount * elapsedTime / duration
claimable = vested - released
```

---

### Vesting Flow

1. Depositor funds contract  
2. Tokens unlock linearly over time  
3. Beneficiary claims periodically  

---

### Vesting Invariants

- Claimed amount never exceeds total  
- Claimed amount never exceeds vested amount  
- Claimed amount only increases  
- After duration, full amount becomes claimable  

---

### Security Properties

- Lazy accounting (computed on demand)
- Tracks released state instead of relying on token balances
- Prevents double claims
- Resistant to token griefing attacks

---

## Common Bugs Prevented

- Over-claiming unlocked funds  
- Double withdrawals  
- Time manipulation edge cases  
- Insolvent contract states  

---

## Testing

Both contracts include full Foundry test coverage validating:

- correct unlock behavior
- revert conditions
- state transitions
- invariant preservation

---

## Status

Minimal, production-style primitives focused on: correctness, gas efficiency, security, clarity.

Designed for learning, auditing practice, and interview preparation.