# Staking Rewards Patterns

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?style=flat-square)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/TSxo/staking-rewards/actions/workflows/ci.yml/badge.svg)](https://github.com/TSxo/staking-rewards/actions/workflows/ci.yml)

This repository serves as an educational resource that explains the foundational
staking rewards formula underpinning a vast number of systems across decentralized
finance (DeFi).

The model, popularized by [Synthetix](https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewards.sol),
uses indexed-based accounting that facilitates fair reward distribution with
constant-time efficiency.

Variations of this formula power many DeFi primitives, including liquidity mining
and staking systems, protocol fee sharing techniques, and interest-earning mechanisms.

While each evolved independently, all have a common lineage. This repository
isolates and explains this shared foundation with a step-by-step walk-through of
[the algorithm](#the-algorithm), and [three reference implementations](#contracts-overview)
that demonstrate the pattern.

> [!IMPORTANT]
> Review the [Considerations](#considerations) and [Disclaimer](#disclaimer)
> sections below before adapting any of the contracts in this repository.

## Table of Contents

- [Getting Started](#getting-started)
  - [Cloning the Repository](#cloning-the-repository)
  - [Installing Dependencies](#installing-dependencies)
- [Contracts Overview](#contracts-overview)
- [The Algorithm](#the-algorithm)
  - [A Note on Terminology](#a-note-on-terminology)
  - [Naive Approach](#naive-approach)
  - [The Key Insight](#the-key-insight)
  - [Compressing Time](#compressing-time)
  - [Prefix Sums and Range Queries](#prefix-sums-and-range-queries)
  - [Applying Prefix Sums to Staking Rewards](#applying-prefix-sums-to-staking-rewards)
  - [The Global Index](#the-global-index)
  - [The Per-User Index](#the-per-user-index)
  - [Bringing It All Together](#bringing-it-all-together)
- [Considerations](#considerations)
  - [General](#general)
  - [Production](#production)
- [Disclaimer](#disclaimer)

## Getting Started

### Cloning the Repository

To get a local copy of this repository, clone it using:

```bash
git clone git@github.com:TSxo/staking-rewards.git
cd staking-rewards
```

### Installing Dependencies

This project is built using Foundry. If you haven't installed Foundry, follow
the [installation guide](https://getfoundry.sh/).

Once Foundry is installed, install the project dependencies:

```bash
forge install
```

You can then build the contracts:

```bash
forge build
```

And run the tests:

```bash
forge test
```

## Contracts Overview

This repository includes reference implementations of three core staking rewards
patterns. These implementations were selected as they are highly extensible and
capture the foundational designs from which a majority of modern DeFi reward
systems can be derived.

Contracts are located in the [src](https://github.com/TSxo/staking-rewards/tree/main/src) directory:

```
src
├── discrete-staking-rewards
├── mocks
├── staking-rewards
├── staking-rewards-multi
└── utils
```

- `staking-rewards`: A continuous staking rewards contract based on the
  [Synthetix](https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewards.sol),
  model, where rewards are emitted at a constant rate over a fixed duration and
  accrued proportionally to stakers.

- `staking-rewards-multi`: An extension of the Staking Rewards model that supports
  multiple reward tokens simultaneously.

- `discrete-staking-rewards`: A discrete variant of the rewards pattern where
  reward distribution occurs in lump-sum deposits rather than continuously.

## The Algorithm

Modern staking reward systems use index-based accounting to fairly and efficiently
track proportional reward accruals. The following sections explain why this approach
is used, how it achieves constant-time reward updates, and what intuition underpins it.

While the focus here is on the foundational [Synthetix Staking Rewards](https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewards.sol)
model, the underlying algorithm is general and extensible, suitable for many variants
of staking, yield farming, interest earning, and liquidity mining systems.

We begin with the naive approach that calculates rewards iteratively, understand
its limitations, and then derive the index-based approach that achieves $O(1)$
efficiency.

### A Note on Terminology

The `index` described below appears under different names and implementations
across DeFi. For those familiar with other systems, what is referred to here as
`index` is also often also called:

| Protocol / Context          | Common Term                                            |
| --------------------------- | ------------------------------------------------------ |
| Synthetix / Staking Rewards | `rewardPerToken`                                       |
| Aave / Lending Markets      | `liquidityIndex`                                       |
| Sushi MasterChef / MiniChef | `accSushiPerShare`                                     |
| Curve-style Gauges          | `integrate_fraction`, `integrate_checkpoint_of` etc.   |
| General Literature          | Global Index, Reward Index, Stored Index, Accumulator. |

> [!TIP]
> For a visual explanation with in depth examples, do watch the excellent explanation
> of this formula from [Smart Contract Programmer](https://www.youtube.com/watch?v=iNZWMj4USUM).

### Naive Approach

We can express the total rewards $r$ owed to a user $u$ between times $a$ and $b$
as: $r(u, a, b)$.

This can be computed by summing the user’s share of emitted rewards over each
unit of time:

```math
r(u, a, b) = \sum_{t=a}^{b-1} \frac{ R \cdot S_t } { T_t }
```

Where:

- $R$: Reward emission rate (e.g., rewards per second).
- $S_t$: The total amount of tokens staked by the user at time $t$.
- $T_t$: The total amount of tokens staked at time $t$.
- Provided that $T_t \gt 0$.

**Intuition**: At each unit of time (e.g., every second), the protocol emits $R$
reward tokens. Each user receives a fraction of that emission proportional to
their stake $\frac{S_t} {T_t}$. Summing these shares over the interval $[a, b)$
gives the total rewards owed to the user.

**Problem**: This approach requires iterating over every time step between $a$ and $b$,
making it an $O(n)$ algorithm. On-chain, where time is measured in seconds or
blocks, $n$ could be in the thousands or millions. This method would quickly
exceed gas limits, making it infeasible for blockchain applications.

### The Key Insight

Moving from an iterative approach to a constant-time solution hinges on one
crucial observation:

**A user’s staked balance $S$ remains constant between contract interactions.**

This eliminates the need to compute rewards for every intermediate time step.
Instead, we aggregate rewards by tracking how much reward accrues per staked token
over time.

**Intuition**: Rather than asking, “How many rewards did the user earn each second?”
we ask, “How many rewards were distributed per staked token since the last update,
and how many tokens does the user hold?”. This shift allows us to collapse time
into state using a technique called prefix sums (explained below), making the
calculation efficient.

### Compressing Time

Recall our earlier formula:

```math
r(u, a, b) = \sum_{t=a}^{b-1} \frac{ R \cdot S_t } { T_t }
```

Because a user’s staked amount $S$ remains constant between $a$ and $b$, we can
factor it out of the summation:

```math
r(u, a, b) = S \cdot \sum_{t=a}^{b-1} \frac{ R } { T_t }
```

Where:

- $R$: Reward emission rate (e.g., rewards per second).
- $S$: The total amount of tokens staked by the user between time $a$ and $b$.
- $T_t$: The total amount of tokens staked at time $t$.
- Provided that $T_t \gt 0$.

The term $\sum_{t=a}^{b-1} \frac{ R } { T_t }$ represents the total rewards
emitted per token staked in the contract from time $a$ to $b$. Multiplying this
by the user’s stake $S$ gives their total rewards.

This is a major simplification. Our reward computation now depends only on the
cumulative rewards emitted per staked token between $a$ and $b$. However, we still
need an efficient way to calculate these cumulative totals on-chain without
iteration. Prefix sums provide exactly that.

### Prefix Sums and Range Queries

A [prefix sum](https://en.wikipedia.org/wiki/Prefix_sum) is a classic computer
science concept that allows us to compute the sum of any range in constant time
by storing cumulative totals.

For example, by maintaining an array of prefix sums, any index `i` represents
the sum of all elements up to, but not including `i`:

```typescript
const values = [3, 1, 4, 2];
const prefix = [0, 3, 4, 8, 10];
```

Therefore, we can obtain the sum of elements $[a, b)$ from the original `values`
array as `prefix[b] - prefix[a]` or $[a, b]$ as `prefix[b + 1] - prefix[a]`.
For example, to find the sum of range $[1, 3)$ and $[1, 3]$:

```typescript
const values = [3, 1, 4, 2];
const prefix = [0, 3, 4, 8, 10];

const a = 1;
const b = 3;

// [a, b):
const exclusive = prefix[b] - prefix[a]; // 8 - 3 = 5

// [a, b]:
const inclusive = prefix[b + 1] - prefix[a]; // 10 - 3 = 7
```

This subtraction instantly gives us the total of any segment, without iteration.

### Applying Prefix Sums to Staking Rewards

The same prefix sum logic applies directly to staking rewards. Recall the
simplified equation:

```math
r(u, a, b) = S \cdot \sum_{t=a}^{b-1} \frac{ R } { T_t }
```

We can rewrite this as the **difference between two cumulative totals**:

```math
S \cdot \sum_{t=a}^{b-1} \frac{ R } { T_t } = S \cdot ( \sum_{t=0}^{b-1} \frac{ R } { T_t } - \sum_{t=0}^{a-1} \frac{ R } { T_t } )
```

This reframes the reward calculation over $[a, b)$ as simply the difference between
two cumulative sums:

- One up to $b$: covering everything from the start to just before $b$; and
- One up to $a$: covering everything from the start to just before $a$.

Let’s define the cumulative rewards earned per token staked at time $t$ as:

```math
I_t = \sum_{k=0}^{t-1} \frac{ R }{ T_k }
```

We can now express a user's rewards earned between times $a$ and $b$ as:

```math
r(u, a, b) = S \cdot ( I_b - I_a )
```

While we are not strictly maintaining an array indexed by time, this is directly
analogous to how we compute a range sum in a prefix array:

```typescript
const rangeSum = prefix[b] - prefix[a];
```

This is the heart of the constant-time algorithm. The contract implements two
indexes:

1. A global index $I_b$ that represents the cumulative rewards earned per staked token up to time $b$.
2. A per-user index $I_a$ that represents the cumulative rewards earned per staked token up to time $a$.

**Intuition**: Just as computing a range sum in our prefix array required values
at two indexes (`prefix[b] - prefix[a]`), computing a user's rewards requires
values at two indexes ($I_b$ - $I_a$). As each user stakes, unstakes, and claims
at different times, each user has their own "checkpoint" - a snapshot of what
the global index was at their last interaction. The difference between the current
global index and their checkpoint tells us exactly how many rewards per token
accumulated between their contract interactions.

### The Global Index

The global reward index is updated whenever the contract’s state changes - such
as when rewards are deposited, or users stake, unstake, or claim. The update is
based on the time elapsed since the last index update and the current reward
emission rate:

```solidity
// When no tokens are staked, rewards cannot accrue (division by zero).
if (_totalSupply == 0) return _index;

uint256 dt = lastTimeRewardApplicable() - _lastUpdated;
_index = _index + (_rate * dt * SCALE) / _totalSupply;
```

Where:

- `lastTimeRewardApplicable()`: The current timestamp or the end of the reward period, whichever is earlier.
- `_lastUpdated`: The timestamp of the last index update.
- `_rate`: The reward emission rate $R$.
- `_totalSupply`: The total staked tokens $T_t$.
- `SCALE`: A scaling factor (e.g., $10^{18}$ ) to handle fixed-point arithmetic.

This implements:

```math
I_{new} = I_{old} + \frac{  R \cdot \Delta_t } { T }
```

Where $\Delta_t = t_{new} - t_{old}$ : the elapsed time since the last update.

### The Per-User Index

To compute a user’s rewards without iterating, we store a _per-user index_ that
records the global index at the last time the user’s rewards were updated (e.g.,
when they staked, unstaked, or claimed).

Let $I_u$ denote the user’s stored index.

The user's accrued rewards at the current time $t$ (relative to their last update) are:

```math
r(u) = S \cdot (I_b - I_a)
```

Where:

- $S$: The user’s staked balance.
- $I_b$: The current global index.
- $I_a$: The user’s stored index from their last update.

In Solidity:

```solidity
_index = currentIndex();

uint256 pending = _pendingRewards[account];
uint256 shares = _balances[account];
uint256 di = _index - _userIndex[account];

_pendingRewards[account] = pending + (shares * di / SCALE);
_userIndex[account] = _index;
```

**Intuition**: The difference $I_b - I_a$ represents the rewards per staked token
since the user’s last update. Multiplying by $S$ gives the user’s total accrued
rewards since their last update. When a user claims or updates their stake, we
set $I_a$ to the current global index, effectively “resetting” their accrued
rewards.

### Bringing It All Together

The complete algorithm works as follows:

1. On any state-changing operation (deposit rewards, stake, unstake, claim):

   - Update the global index using the time elapsed since the last update.
   - Calculate and store the user's pending rewards using their staked balance and index delta.
   - Update the user's stored index to match the current global index.
   - Perform the requested operation.

2. To query pending rewards (read-only):
   - Compute the current global index (without storing it).
   - Return `userStake * (currentIndex - userStoredIndex) + userStoredRewards`

This approach gives us:

- $O(1)$ complexity: No iteration over time periods.
- Fair distribution: Each user receives exactly their proportional share.
- Gas efficiency: Updates happen only when users interact.

> [!TIP]
> This algorithm converts a seemingly complex time-based calculation into simple
> arithmetic using state variables.
>
> The global index accumulates rewards emitted per staked token over time, and
> each user's checkpoint lets them claim exactly the rewards that accrued while
> they were staked.

## Considerations

### General

The implementations in this repository address key concerns from staking reward
contract audits.

- **Reward Notifications**: Many staking contracts that custody reward tokens
  allow for reward amounts to be "notified" without transferring in those tokens.
  With careful management, this behaviour is often fine (and perhaps desired),
  but can technically result in mismatches between the reward rate and the
  contract's available reward token balance when unclaimed rewards exist. The
  implementations here transfer reward tokens into the contract at the time
  of deposit, ensuring that accounting remains simple and consistent.

- **Token compatibility**: Fee-on-transfer, rebate, and deflationary tokens are
  explicitly rejected in these contracts as they introduce non-deterministic
  balance changes that invalidate reward calculations. Support for these tokens
  may be added at the expense of added complexity.

- **Reward and Stake Token Equivalence**: Using the same token for staking and
  rewards is disallowed to avoid accounting issues. While the use of a “checked”
  transfer ensures that deposits are accurately measured, distinct tokens are
  recommended. For example, if reward tokens are transferred into the contract
  and `balanceOf` is later used to infer total staked deposits (e.g., MasterChef-style
  contracts), the apparent balance will be inflated, leading to incorrect reward
  rate calculations or over-crediting of stakers.

Additional notes on the core staking rewards algorithm:

- Depositing rewards before any tokens are staked will result in the loss of
  rewards emitted from the time of deposit until the first stake.

- Any reward deposit that is not evenly divisible by the reward duration will
  be rounded down, with excess tokens remaining locked in the contract.

- Rebase tokens are not supported.

### Production

These implementations prioritize correctness and transparency of reward logic.
Production systems may additionally require:

- Emergency pause controls.
- Token recovery mechanisms.
- More sophisticated access control beyond single owner.
- Upgradeability or migration pathways.
- Additional accounting to track and recover reward tokens lost to rounding, or
  mechanisms to redistribute them in subsequent periods.
- Gas optimization (e.g., for large user bases).

## Disclaimer

The goal of this repository is to serve as an educational resource. It isolates
the core mechanics associated with staking reward distribution.

All contracts in this repository demonstrate modern security practices, strict
validation, and prioritize clear terminology and readability. However, they are
**left intentionally minimal, have not undergone formal security audits, and are
not intended for production deployment**.

**Do not deploy these contracts to production environments** without
modifications, audits, and testing. Please review the [General](#general) and
[Production](#production) consideration sections before adapting any code.

This repository is licensed under MIT. You are free to use the code however you
wish. The author assumes **no liability** for any loss, damage, or unintended
behavior resulting from the use of this software.

