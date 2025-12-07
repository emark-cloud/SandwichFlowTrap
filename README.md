# SandwichFlowTrap

## Overview

The **SandwichFlowTrap** detects MEV sandwich attacks on a specific AMM pool by analyzing attacker patterns, victim impact, and repeated toxic order flow. It uses a feeder → trap → responder architecture and is fully Drosera-compliant.

---

## What It Detects

* Attacker → victim → attacker sandwich sequences
* High victim slippage or price impact
* Large attacker profit extracted from users
* Repeated MEV behavior across multiple blocks

---

## How It Works

### **Feeder** (off‑chain)

Analyzes each block and sends:

* `numSandwiches`
* `totalVictimVolume`
* `attackerProfit`
* `worstPriceImpactBps`
* `attackers[]`

### **Trap (on‑chain)**

* `collect()` safely reads feeder metrics.
* `shouldRespond()` evaluates a sliding window of recent blocks.
* Triggers if:

  * Sandwiches ≥ threshold
  * Attacker profit is high
  * Price impact is severe
  * Patterns repeat across blocks

Severity levels (1–3) reflect how aggressive the MEV activity is.

### **Responder**

When triggered:

* Emits a `ToxicOrderflowDetected` incident
* (Optional) Enables MEV‑protected routing or adjusts protocol parameters

---

## Drosera Settings (Example)

```toml
cooldown_period_blocks = 1
block_sample_size = 5
private_trap = true
whitelist = ["0x<OPERATOR>"]
```

---

## Summary

The SandwichFlowTrap provides early warning for:

* MEV farming
* Toxic orderflow
* Excessive price impact

It helps protocols react automatically and protect users when a pool is being exploited by sandwich bots.
