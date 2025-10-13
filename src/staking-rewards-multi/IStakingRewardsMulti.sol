// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title IStakingRewardsMulti
///
/// @notice The interface for `StakingRewardsMulti`.
interface IStakingRewardsMulti {
    // -------------------------------------------------------------------------
    // Events

    /// @notice Emitted when a reward token is added to the contract.
    ///
    /// @param token    The token that was added.
    /// @param duration The initial reward period duration, in seconds.
    event AddReward(address indexed token, uint256 duration);

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
    /// @param token    The reward token claimed.
    /// @param amount   The amount of reward tokens received.
    event ClaimRewards(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when rewards are deposited into the contract.
    ///
    /// @param token    The reward token deposited.
    /// @param amount   The amount of reward tokens deposited.
    event DepositRewards(address indexed token, uint256 amount);

    /// @notice Emitted when the reward period duration is updated.
    ///
    /// @param token    The reward token for which the duration was updated.
    /// @param duration The new reward period duration.
    event DurationUpdate(address indexed token, uint256 duration);

    // -------------------------------------------------------------------------
    // Functions

    /// @notice Adds a new reward token to the contract.
    ///
    /// @param token            The reward token.
    /// @param initialDuration  The initial reward period duration, in seconds.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - The reward token cannot be the zero address.
    /// - The initial duration cannot be zero.
    /// - There must no existing configuration for the token.
    ///
    /// Emits an `AddReward` event.
    function addReward(address token, uint256 initialDuration) external;

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
    /// @param token The reward token to claim.
    ///
    /// @dev Emits a `ClaimRewards` event.
    function claimRewards(address token) external;

    /// @notice Claims all a user's pending rewards.
    ///
    /// @dev Emits a `ClaimRewards` event.
    function claimRewards() external;

    /// @notice Sets a reward period duration.
    ///
    /// @param token        The reward token for which the duration is set.
    /// @param newDuration  The new reward period duration.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - Only callable when no reward period is active for the given token.
    /// - The new duration must be greater than zero.
    ///
    /// Emits a `DurationUpdate` event.
    function setDuration(address token, uint256 newDuration) external;

    /// @notice Deposits reward tokens into the contract.
    ///
    /// @param token    The reward token to deposit.
    /// @param amount   The amount of reward tokens to deposit.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - The reward token must be supported.
    /// - Amount to deposit must be greater than zero.
    /// - Caller must have granted this contract sufficient allowance over the
    ///   reward token.
    ///
    /// Emits a `DepositRewards` event.
    function depositRewards(address token, uint256 amount) external;

    /// @notice Returns the address of the staking token.
    ///
    /// @return The address of the staking token.
    function stakingToken() external view returns (address);

    /// @notice Returns the all supported reward token addresses.
    ///
    /// @return All supported reward token addresses.
    function rewardTokens() external view returns (address[] memory);

    /// @notice Returns the duration, in seconds, for the reward token's
    /// distribution period.
    ///
    /// @param token The reward token.
    ///
    /// @return The duration, in seconds, for the reward token's distribution
    /// period.
    function duration(address token) external view returns (uint256);

    /// @notice Returns the timestamp at which the reward token's distribution
    /// period ends.
    ///
    /// @param token The reward token.
    ///
    /// @return The timestamp at which the reward token's distribution period ends.
    function periodFinish(address token) external view returns (uint256);

    /// @notice Returns the timestamp at which the reward token's last global
    /// update occurred.
    ///
    /// @param token The reward token.
    ///
    /// @return The timestamp at which the reward token's last global update
    /// occurred.
    function lastUpdated(address token) external view returns (uint256);

    /// @notice Returns the amount of rewards, per second, to emit.
    ///
    /// @param token The reward token.
    ///
    /// @return The amount of rewards, per second, to emit.
    function rate(address token) external view returns (uint256);

    /// @notice Returns the reward token's last stored cumulative index.
    ///
    /// @param token The reward token.
    ///
    /// @return The reward token's last stored cumulative index.
    function index(address token) external view returns (uint256);

    /// @notice Returns the last stored reward index for a given account.
    ///
    /// @param account  The account to check.
    /// @param token    The reward token.
    ///
    /// @return The last stored reward index for a given account.
    function userIndex(address account, address token) external view returns (uint256);

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
    /// @param token The reward token.
    ///
    /// @return the amount of reward tokens deposited in this contract.
    function rewardBalance(address token) external view returns (uint256);

    /// @notice Returns the timestamp at which rewards were last applicable.
    ///
    /// @param token The reward token.
    ///
    /// @return The timestamp at which rewards were last applicable.
    function lastTimeRewardApplicable(address token) external view returns (uint256);

    /// @notice Returns the reward token's current index.
    ///
    /// @param token The reward token.
    ///
    /// @return The current reward index.
    function currentIndex(address token) external view returns (uint256);

    /// @notice Returns the amount of unclaimed reward tokens accrued by an account.
    ///
    /// @param account  The account to check.
    /// @param token    The reward token.
    ///
    /// @return The amount of unclaimed reward tokens accrued by an account.
    function pendingRewards(address account, address token) external view returns (uint256);

    /// @notice Returns whether the current reward distribution period is active.
    ///
    /// @param token The reward token.
    ///
    /// @return True if the current reward period is active, false otherwise.
    function periodRewardActive(address token) external view returns (bool);

    /// @notice Returns the total reward amount allocated for the current period.
    ///
    /// @param token The reward token.
    ///
    /// @return The total reward amount allocated for the current period.
    function periodRewardTotal(address token) external view returns (uint256);

    /// @notice Returns the reward amount already emitted during the current
    /// period.
    ///
    /// @param token The reward token.
    ///
    /// @return The reward amount already emitted during the current period.
    function periodRewardEmitted(address token) external view returns (uint256);

    /// @notice Returns the reward amount remaining to be emitted in the current
    /// period.
    ///
    /// @param token The reward token.
    ///
    /// @return The reward amount remaining to be emitted in the current period.
    function periodRewardRemaining(address token) external view returns (uint256);
}
