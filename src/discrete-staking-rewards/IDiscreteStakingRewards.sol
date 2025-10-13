// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title IDiscreteStakingRewards
///
/// @notice The interface for `StakingRewards`.
interface IDiscreteStakingRewards {
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

    /// @notice Deposits reward tokens into the contract.
    ///
    /// @param amount The amount of reward tokens to deposit.
    ///
    /// @dev Requirements:
    /// - Only callable by the contract owner.
    /// - Amount to deposit must be greater than zero.
    /// - Total supply must be greater than zero.
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

    /// @notice Returns the amount of unclaimed reward tokens accrued by an account.
    ///
    /// @param account The account to check.
    ///
    /// @return The amount of unclaimed reward tokens accrued by an account.
    function pendingRewards(address account) external view returns (uint256);
}
