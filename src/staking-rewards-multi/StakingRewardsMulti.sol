// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Assert } from "../utils/Assert.sol";
import { IStakingRewardsMulti } from "./IStakingRewardsMulti.sol";

/// @title StakingRewardsMulti
///
/// @author TSxo
/// @author Modified from Synthetix (https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewardsMulti.sol)
///
/// @notice A modern reference implementation of the Synthetix StakingRewards
/// contract that allows multiple reward tokens to be emitted.
///
/// @dev This contract implements the core mechanics of proportional, time-weighted
/// staking rewards distribution.
///
/// Important:
///
/// See the top level README for information regarding the algoirthm, important
/// considerations, and limitations.
contract StakingRewardsMulti is Ownable, ReentrancyGuard, IStakingRewardsMulti {
    // -------------------------------------------------------------------------
    // Type Declarations

    using SafeERC20 for IERC20;

    /// @dev Represents a single reward token configuration.
    struct RewardConfig {
        // The fixed duration, in seconds, for each reward distribution period.
        uint256 duration;
        // The timestamp at which the active reward distribution period ends.
        uint256 periodFinish;
        // The timestamp at which the last global rewards update occurred.
        uint256 lastUpdated;
        // The amount of rewards, per second, to emit.
        uint256 rate;
        // Tracks the cumulative amount of reward tokens emitted per unit of
        // staked token from the start of the contract up until `lastUpdated`.
        uint256 index;
    }

    // -------------------------------------------------------------------------
    // State

    /// @dev The amount by which the reward index is scaled. Should be sufficiently
    /// high to minimize rounding errors.
    uint256 private constant SCALE = 1e18;

    /// @dev The token to be staked.
    IERC20 private immutable STAKING_TOKEN;

    /// @dev The total amount of staked tokens.
    uint256 private _totalSupply;

    /// @dev Each user's staked balance.
    mapping(address => uint256) private _balances;

    /// @dev Each reward token's configuration.
    mapping(address => RewardConfig) private _config;

    /// @dev Each user's last known reward token index. Updated at the given
    /// user's last contract interaction.
    /// user => reward token => index
    mapping(address => mapping(address => uint256)) private _userIndex;

    /// @dev Each user's accrued, but unclaimed, rewards. Updated at the given
    /// user's last contract interaction.
    /// user => reward token => pending rewards.
    mapping(address => mapping(address => uint256)) private _pendingRewards;

    /// @dev A list of all supported reward tokens.
    address[] private _rewardTokens;

    // -------------------------------------------------------------------------
    // Constructor

    /// @param owner_           The initial contract owner.
    /// @param stakingToken_    The token to be staked.
    ///
    /// @dev Requirements:
    /// - The provided addresses cannot be the zero address.
    constructor(address owner_, address stakingToken_) Ownable(owner_) {
        Assert.notZero(stakingToken_);
        STAKING_TOKEN = IERC20(stakingToken_);
    }

    // -------------------------------------------------------------------------
    // Functions - External

    /// @inheritdoc IStakingRewardsMulti
    function addReward(address token, uint256 initialDuration) external onlyOwner {
        Assert.notZero(token);
        Assert.notZero(initialDuration);
        Assert.ne(token, address(STAKING_TOKEN));

        RewardConfig storage cfg = _config[token];
        Assert.eq(cfg.duration, 0);

        cfg.duration = initialDuration;
        _rewardTokens.push(token);

        emit AddReward(token, initialDuration);
    }

    /// @inheritdoc IStakingRewardsMulti
    function stake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] += amount;
        _totalSupply += amount;

        _checkedTransferIn(STAKING_TOKEN, amount);

        emit Stake(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewardsMulti
    function unstake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewardsMulti
    function claimRewards(address token) external nonReentrant {
        _updateRewards(msg.sender);
        _claim(msg.sender, token);
    }

    /// @inheritdoc IStakingRewardsMulti
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        uint256 n = _rewardTokens.length;
        for (uint256 i; i < n; i++) {
            address token = _rewardTokens[i];
            _claim(msg.sender, token);
        }
    }

    /// @inheritdoc IStakingRewardsMulti
    function setDuration(address token, uint256 newDuration) external onlyOwner {
        Assert.notZero(token);
        Assert.notZero(newDuration);

        RewardConfig storage cfg = _config[token];

        Assert.gt(block.timestamp, cfg.periodFinish);
        Assert.notZero(cfg.duration);

        cfg.duration = newDuration;

        emit DurationUpdate(token, newDuration);
    }

    /// @inheritdoc IStakingRewardsMulti
    function depositRewards(address token, uint256 amount) external nonReentrant onlyOwner {
        Assert.notZero(token);
        Assert.notZero(amount);

        _updateRewards(address(0));

        RewardConfig storage cfg = _config[token];
        Assert.notZero(cfg.duration);

        if (block.timestamp >= cfg.periodFinish) {
            cfg.rate = amount / cfg.duration;
        } else {
            uint256 remaining = cfg.rate * (cfg.periodFinish - block.timestamp);
            cfg.rate = (remaining + amount) / cfg.duration;
        }

        Assert.notZero(cfg.rate);

        cfg.periodFinish = block.timestamp + cfg.duration;
        cfg.lastUpdated = block.timestamp;

        _checkedTransferIn(IERC20(token), amount);

        emit DepositRewards(token, amount);
    }

    /// @inheritdoc IStakingRewardsMulti
    function stakingToken() external view returns (address) {
        return address(STAKING_TOKEN);
    }

    /// @inheritdoc IStakingRewardsMulti
    function rewardTokens() external view returns (address[] memory) {
        return _rewardTokens;
    }

    /// @inheritdoc IStakingRewardsMulti
    function duration(address token) external view returns (uint256) {
        return _config[token].duration;
    }

    /// @inheritdoc IStakingRewardsMulti
    function periodFinish(address token) external view returns (uint256) {
        return _config[token].periodFinish;
    }

    /// @inheritdoc IStakingRewardsMulti
    function lastUpdated(address token) external view returns (uint256) {
        return _config[token].lastUpdated;
    }

    /// @inheritdoc IStakingRewardsMulti
    function rate(address token) external view returns (uint256) {
        return _config[token].rate;
    }

    /// @inheritdoc IStakingRewardsMulti
    function index(address token) external view returns (uint256) {
        return _config[token].index;
    }

    /// @inheritdoc IStakingRewardsMulti
    function userIndex(address account, address token) external view returns (uint256) {
        return _userIndex[account][token];
    }

    /// @inheritdoc IStakingRewardsMulti
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IStakingRewardsMulti
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IStakingRewardsMulti
    function rewardBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @inheritdoc IStakingRewardsMulti
    function periodRewardActive(address token) external view returns (bool) {
        RewardConfig storage cfg = _config[token];
        return block.timestamp >= (cfg.periodFinish - cfg.duration) && block.timestamp <= cfg.periodFinish;
    }

    /// @inheritdoc IStakingRewardsMulti
    function periodRewardTotal(address token) external view returns (uint256) {
        RewardConfig storage cfg = _config[token];
        return cfg.rate * cfg.duration;
    }

    /// @inheritdoc IStakingRewardsMulti
    function periodRewardEmitted(address token) external view returns (uint256) {
        RewardConfig storage cfg = _config[token];

        if (block.timestamp > cfg.periodFinish) return cfg.rate * cfg.duration;

        uint256 dt = block.timestamp - (cfg.periodFinish - cfg.duration);
        return cfg.rate * dt;
    }

    /// @inheritdoc IStakingRewardsMulti
    function periodRewardRemaining(address token) external view returns (uint256) {
        RewardConfig storage cfg = _config[token];

        if (block.timestamp >= cfg.periodFinish) return 0;

        return cfg.rate * (cfg.periodFinish - block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IStakingRewardsMulti
    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        uint256 finish = _config[token].periodFinish;
        return finish <= block.timestamp ? finish : block.timestamp;
    }

    /// @inheritdoc IStakingRewardsMulti
    function currentIndex(address token) public view returns (uint256) {
        RewardConfig storage cfg = _config[token];
        if (_totalSupply == 0) return cfg.index;

        uint256 dt = lastTimeRewardApplicable(token) - cfg.lastUpdated;
        return cfg.index + (cfg.rate * dt * SCALE) / _totalSupply;
    }

    /// @inheritdoc IStakingRewardsMulti
    function pendingRewards(address account, address token) public view returns (uint256) {
        uint256 pending = _pendingRewards[account][token];
        uint256 shares = _balances[account];
        uint256 di = currentIndex(token) - _userIndex[account][token];

        return pending + (shares * di / SCALE);
    }

    // -------------------------------------------------------------------------
    // Functions - Private

    /// @notice Updates the global and per-user reward state.
    ///
    /// @param account The account to update rewards for.
    ///
    /// @dev If `account` set to the zero address, only global reward indexes
    /// and timestamps are updated.
    function _updateRewards(address account) private {
        uint256 n = _rewardTokens.length;
        for (uint256 i; i < n; i++) {
            address token = _rewardTokens[i];
            RewardConfig storage cfg = _config[token];

            cfg.index = currentIndex(token);
            cfg.lastUpdated = lastTimeRewardApplicable(token);

            if (account != address(0)) {
                _pendingRewards[account][token] = pendingRewards(account, token);
                _userIndex[account][token] = cfg.index;
            }
        }
    }

    /// @notice Transfers any pending rewards for the given account and token.
    ///
    /// @param account  The account whose rewards are being claimed.
    /// @param token    The reward token to claim rewards for.
    ///
    /// @dev Emits a `ClaimRewards` event.
    function _claim(address account, address token) private {
        uint256 reward = _pendingRewards[account][token];

        if (reward > 0) {
            _pendingRewards[account][token] = 0;
            IERC20(token).safeTransfer(account, reward);

            emit ClaimRewards(account, token, reward);
        }
    }

    /// @notice Safely transfers tokens into the contract and verifies the
    /// amount received.
    ///
    /// @param token    The token to transfer in.
    /// @param amount   The amount to transfer in.
    function _checkedTransferIn(IERC20 token, uint256 amount) private {
        uint256 start = token.balanceOf(address(this));

        token.safeTransferFrom(msg.sender, address(this), amount);

        uint256 end = token.balanceOf(address(this));
        uint256 delta = end - start;
        Assert.eq(delta, amount);
    }
}
