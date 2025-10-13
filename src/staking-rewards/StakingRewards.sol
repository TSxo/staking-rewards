// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Assert } from "../utils/Assert.sol";
import { IStakingRewards } from "./IStakingRewards.sol";

/// @title StakingRewards
///
/// @author TSxo
/// @author Modified from Synthetix (https://github.com/Synthetixio/synthetix/blob/master/contracts/StakingRewards.sol)
///
/// @notice A modern reference implementation of the Synthetix StakingRewards
/// contract.
///
/// @dev This contract implements the core mechanics of proportional, time-weighted
/// staking rewards distribution.
///
/// Important:
///
/// See the top level README for information regarding the algoirthm, important
/// considerations, and limitations.
contract StakingRewards is Ownable, ReentrancyGuard, IStakingRewards {
    // -------------------------------------------------------------------------
    // Type Declarations

    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // State

    /// @dev The amount by which the reward index is scaled. Should be sufficiently
    /// high to minimize rounding errors.
    uint256 private constant SCALE = 1e18;

    /// @dev The token to be staked.
    IERC20 private immutable STAKING_TOKEN;

    /// @dev The token to be emitted as staking rewards.
    IERC20 private immutable REWARD_TOKEN;

    /// @dev The fixed duration, in seconds, for each reward distribution period.
    uint256 private _duration;

    /// @dev The timestamp at which the active reward distribution period ends.
    uint256 private _periodFinish;

    /// @dev The timestamp at which the last global rewards update occurred.
    uint256 private _lastUpdated;

    /// @dev The amount of rewards, per second, to emit.
    uint256 private _rate;

    /// @dev Tracks the cumulative amount of reward tokens emitted per unit of
    /// staked token from the start of the contract up until `_lastUpdated`.
    uint256 private _index;

    /// @dev The total amount of staked tokens.
    uint256 private _totalSupply;

    /// @dev Each user's staked balance.
    mapping(address => uint256) private _balances;

    /// @dev Each user's last known reward index. Updated at the given user's
    /// last contract interaction.
    mapping(address => uint256) private _userIndex;

    /// @dev Each user's accrued, but unclaimed, rewards. Updated at the given
    /// user's last contract interaction.
    mapping(address => uint256) private _pendingRewards;

    // -------------------------------------------------------------------------
    // Constructor

    /// @param owner_           The initial contract owner.
    /// @param stakingToken_    The token to be staked.
    /// @param rewardToken_     The token to be emitted as staking rewards.
    /// @param duration_        The initial reward period duration.
    ///
    /// @dev Requirements:
    /// - The provided addresses cannot be the zero address.
    /// - The duration cannot be zero.
    /// - The staking token cannot be the reward token.
    constructor(address owner_, address stakingToken_, address rewardToken_, uint256 duration_) Ownable(owner_) {
        Assert.notZero(stakingToken_);
        Assert.notZero(rewardToken_);
        Assert.notZero(duration_);
        Assert.ne(stakingToken_, rewardToken_);

        STAKING_TOKEN = IERC20(stakingToken_);
        REWARD_TOKEN = IERC20(rewardToken_);
        _duration = duration_;
    }

    // -------------------------------------------------------------------------
    // Functions - External

    /// @inheritdoc IStakingRewards
    function stake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] += amount;
        _totalSupply += amount;

        _checkedTransferIn(STAKING_TOKEN, amount);

        emit Stake(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewards
    function unstake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
    }

    /// @inheritdoc IStakingRewards
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        uint256 reward = _pendingRewards[msg.sender];
        if (reward > 0) {
            _pendingRewards[msg.sender] = 0;
            REWARD_TOKEN.safeTransfer(msg.sender, reward);

            emit ClaimRewards(msg.sender, reward);
        }
    }

    /// @inheritdoc IStakingRewards
    function setDuration(uint256 newDuration) external onlyOwner {
        Assert.gt(block.timestamp, _periodFinish);
        Assert.notZero(newDuration);

        _duration = newDuration;

        emit DurationUpdate(newDuration);
    }

    /// @inheritdoc IStakingRewards
    function depositRewards(uint256 amount) external nonReentrant onlyOwner {
        Assert.notZero(amount);

        _updateRewards(address(0));

        uint256 cachedRate = _rate;
        uint256 cachedDuration = _duration;

        if (block.timestamp >= _periodFinish) {
            cachedRate = amount / cachedDuration;
        } else {
            uint256 remaining = cachedRate * (_periodFinish - block.timestamp);
            cachedRate = (remaining + amount) / cachedDuration;
        }

        Assert.notZero(cachedRate);

        _rate = cachedRate;
        _periodFinish = block.timestamp + cachedDuration;
        _lastUpdated = block.timestamp;

        _checkedTransferIn(REWARD_TOKEN, amount);

        emit DepositRewards(amount);
    }

    /// @inheritdoc IStakingRewards
    function stakingToken() external view returns (address) {
        return address(STAKING_TOKEN);
    }

    /// @inheritdoc IStakingRewards
    function rewardToken() external view returns (address) {
        return address(REWARD_TOKEN);
    }

    /// @inheritdoc IStakingRewards
    function duration() external view returns (uint256) {
        return _duration;
    }

    /// @inheritdoc IStakingRewards
    function periodFinish() external view returns (uint256) {
        return _periodFinish;
    }

    /// @inheritdoc IStakingRewards
    function lastUpdated() external view returns (uint256) {
        return _lastUpdated;
    }

    /// @inheritdoc IStakingRewards
    function rate() external view returns (uint256) {
        return _rate;
    }

    /// @inheritdoc IStakingRewards
    function index() external view returns (uint256) {
        return _index;
    }

    /// @inheritdoc IStakingRewards
    function userIndex(address account) external view returns (uint256) {
        return _userIndex[account];
    }

    /// @inheritdoc IStakingRewards
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IStakingRewards
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IStakingRewards
    function rewardBalance() external view returns (uint256) {
        return REWARD_TOKEN.balanceOf(address(this));
    }

    /// @inheritdoc IStakingRewards
    function periodRewardActive() external view returns (bool) {
        return block.timestamp >= (_periodFinish - _duration) && block.timestamp <= _periodFinish;
    }

    /// @inheritdoc IStakingRewards
    function periodRewardTotal() external view returns (uint256) {
        return _rate * _duration;
    }

    /// @inheritdoc IStakingRewards
    function periodRewardEmitted() external view returns (uint256) {
        if (block.timestamp > _periodFinish) return _rate * _duration;

        uint256 dt = block.timestamp - (_periodFinish - _duration);
        return _rate * dt;
    }

    /// @inheritdoc IStakingRewards
    function periodRewardRemaining() external view returns (uint256) {
        if (block.timestamp >= _periodFinish) return 0;

        return _rate * (_periodFinish - block.timestamp);
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IStakingRewards
    function lastTimeRewardApplicable() public view returns (uint256) {
        return _periodFinish <= block.timestamp ? _periodFinish : block.timestamp;
    }

    /// @inheritdoc IStakingRewards
    function currentIndex() public view returns (uint256) {
        if (_totalSupply == 0) return _index;

        uint256 dt = lastTimeRewardApplicable() - _lastUpdated;
        return _index + (_rate * dt * SCALE) / _totalSupply;
    }

    /// @inheritdoc IStakingRewards
    function pendingRewards(address account) public view returns (uint256) {
        uint256 pending = _pendingRewards[account];
        uint256 shares = _balances[account];
        uint256 di = currentIndex() - _userIndex[account];

        return pending + (shares * di / SCALE);
    }

    // -------------------------------------------------------------------------
    // Functions - Private

    /// @notice Updates the global and per-user reward state.
    ///
    /// @param account The account to update rewards for.
    ///
    /// @dev If `account` set to the zero address, only the global reward index
    /// and timestamp are updated.
    function _updateRewards(address account) private {
        _index = currentIndex();
        _lastUpdated = lastTimeRewardApplicable();

        if (account != address(0)) {
            _pendingRewards[account] = pendingRewards(account);
            _userIndex[account] = _index;
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
