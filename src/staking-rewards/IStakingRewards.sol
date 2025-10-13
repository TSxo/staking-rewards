// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title IStakingRewards
///
/// @notice The interface for `StakingRewards`.
interface IStakingRewards {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when a user stakes tokens.
    ///
    /// @param user     The address of the user.
    /// @param amount   The amount of tokens staked.
    event Stake(address indexed user, uint256 amount);

    /// @notice Emitted when a user unstakes tokens.
    ///
    /// @param user     The address of the user.
    /// @param amount   The amount of tokens unstaked.
    event Unstake(address indexed user, uint256 amount);

    /// @notice Emitted when a user claims rewards.
    ///
    /// @param user     The address of the user.
    /// @param amount   The amount of reward tokens received.
    event ClaimRewards(address indexed user, uint256 amount);

    /// @notice Emitted when rewards are deposited into the contract.
    ///
    /// @param amount The amount of reward tokens deposited.
    event DepositRewards(uint256 amount);

    /// @notice Emitted when the reward period duration is updated.
    ///
    /// @param duration The new reward period duration.
    event DurationUpdate(uint256 duration);

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Stakes an amount of tokens in the contract.
    ///
    /// @param amount The amount of tokens to stake.
    ///
    /// @dev Requirements:
    /// - Amount to stake must be greater than zero.
    /// - Caller must have granted this contract sufficient allowance over the
    ///   staking token.
    ///
    /// Emits a `Stake` event.
    function stake(uint256 amount) external;

    /// @notice Unstakes an amount of tokens from the contract.
    ///
    /// @param amount The amount of tokens to unstake.
    ///
    /// @dev Requirements:
    /// - Amount to unstake must be greater than zero.
    ///
    /// Emits an `Unstake` event.
    function unstake(uint256 amount) external;

    /// @notice Claims a user's pending rewards.
    ///
    /// @dev Emits a `ClaimRewards` event.
    function claimRewards() external;

    /// @notice Sets the reward period duration.
    ///
    /// @param newDuration The new reward period duration.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - Only callable when no reward period is active.
    /// - The new duration must be greater than zero.
    ///
    /// Emits a `DurationUpdate` event.
    function setDuration(uint256 newDuration) external;

    /// @notice Deposits reward tokens into the contract.
    ///
    /// @param amount The amount of reward tokens to deposit.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - Amount to deposit must be greater than zero.
    /// - Caller must have granted this contract sufficient allowance over the
    ///   reward token.
    ///
    /// Emits a `DepositRewards` event.
    function depositRewards(uint256 amount) external;

    /// @notice Returns the address of the staking token.
    ///
    /// @return The address of the staking token.
    function stakingToken() external view returns (address);

    /// @notice Returns the address of the deposit token.
    ///
    /// @return The address of the deposit token.
    function rewardToken() external view returns (address);

    /// @notice Returns the duration, in seconds, for each reward distribution
    /// period.
    ///
    /// @return The duration, in seconds, for each reward distribution period.
    function duration() external view returns (uint256);

    /// @notice Returns the timestamp at which the active reward distribution
    /// period ends.
    ///
    /// @return The timestamp at which the active reward distribution period ends.
    function periodFinish() external view returns (uint256);

    /// @notice Returns the timestamp at which the last global rewards update
    /// occurred.
    ///
    /// @return The timestamp at which the last global rewards update occurred.
    function lastUpdated() external view returns (uint256);

    /// @notice Returns the amount of rewards, per second, to emit.
    ///
    /// @return The amount of rewards, per second, to emit.
    function rate() external view returns (uint256);

    /// @notice Returns the last stored cumulative reward index.
    ///
    /// @return The last stored cumulative reward index.
    function index() external view returns (uint256);

    /// @notice Returns the last stored reward index for a given account.
    ///
    /// @param account The account to check.
    ///
    /// @return The last stored reward index for a given account.
    function userIndex(address account) external view returns (uint256);

    /// @notice Returns the total number of staked tokens.
    ///
    /// @return The total number of staked tokens.
    function totalSupply() external view returns (uint256);

    /// @notice Returns the amount of tokens an account has staked.
    ///
    /// @param account The account to check.
    ///
    /// @return The amount of tokens an account has staked.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Returns the amount of reward tokens deposited in this contract.
    ///
    /// @return the amount of reward tokens deposited in this contract.
    function rewardBalance() external view returns (uint256);

    /// @notice Returns the timestamp at which rewards were last applicable.
    ///
    /// @return The timestamp at which rewards were last applicable.
    function lastTimeRewardApplicable() external view returns (uint256);

    /// @notice Returns the current reward index.
    ///
    /// @return The current reward index.
    function currentIndex() external view returns (uint256);

    /// @notice Returns the amount of unclaimed reward tokens accrued by an account.
    ///
    /// @param account The account to check.
    ///
    /// @return The amount of unclaimed reward tokens accrued by an account.
    function pendingRewards(address account) external view returns (uint256);

    /// @notice Returns whether the current reward distribution period is active.
    ///
    /// @return True if the current reward period is active, false otherwise.
    function periodRewardActive() external view returns (bool);

    /// @notice Returns the total reward amount allocated for the current period.
    ///
    /// @return The total reward amount allocated for the current period.
    function periodRewardTotal() external view returns (uint256);

    /// @notice Returns the reward amount already emitted during the current
    /// period.
    ///
    /// @return The reward amount already emitted during the current period.
    function periodRewardEmitted() external view returns (uint256);

    /// @notice Returns the reward amount remaining to be emitted in the current
    /// period.
    ///
    /// @return The reward amount remaining to be emitted in the current period.
    function periodRewardRemaining() external view returns (uint256);
}
