// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Assert } from "../utils/Assert.sol";
import { IDiscreteStakingRewards } from "./IDiscreteStakingRewards.sol";

/// @title DiscreteStakingRewards
///
/// @author TSxo
/// @author Modified from Cyfrin (https://www.cyfrin.io/glossary/discrete-staking-rewards-solidity-code-example)
///
/// @notice A modern reference implementation of the DiscreteStakingRewards contract.
///
/// @dev This contract implements the core mechanics of proportional staking
/// rewards distribution.
///
/// Important:
///
/// See the top level README for information regarding the algoirthm, important
/// considerations, and limitations.
contract DiscreteStakingRewards is Ownable, ReentrancyGuard, IDiscreteStakingRewards {
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

    /// @dev Tracks the cumulative amount of reward tokens emitted per unit of
    /// staked token from the start of the contract.
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
    ///
    /// @dev Requirements:
    /// - The provided addresses cannot be the zero address.
    /// - The staking token cannot be the reward token.
    constructor(address owner_, address stakingToken_, address rewardToken_) Ownable(owner_) {
        Assert.notZero(stakingToken_);
        Assert.notZero(rewardToken_);
        Assert.ne(stakingToken_, rewardToken_);

        STAKING_TOKEN = IERC20(stakingToken_);
        REWARD_TOKEN = IERC20(rewardToken_);
    }

    // -------------------------------------------------------------------------
    // Functions - External

    /// @inheritdoc IDiscreteStakingRewards
    function stake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] += amount;
        _totalSupply += amount;

        _checkedTransferIn(STAKING_TOKEN, amount);

        emit Stake(msg.sender, amount);
    }

    /// @inheritdoc IDiscreteStakingRewards
    function unstake(uint256 amount) external nonReentrant {
        Assert.notZero(amount);

        _updateRewards(msg.sender);

        _balances[msg.sender] -= amount;
        _totalSupply -= amount;

        STAKING_TOKEN.safeTransfer(msg.sender, amount);

        emit Unstake(msg.sender, amount);
    }

    /// @inheritdoc IDiscreteStakingRewards
    function claimRewards() external nonReentrant {
        _updateRewards(msg.sender);

        uint256 reward = _pendingRewards[msg.sender];
        if (reward > 0) {
            _pendingRewards[msg.sender] = 0;
            REWARD_TOKEN.safeTransfer(msg.sender, reward);

            emit ClaimRewards(msg.sender, reward);
        }
    }

    /// @inheritdoc IDiscreteStakingRewards
    function depositRewards(uint256 amount) external nonReentrant onlyOwner {
        Assert.notZero(amount);
        Assert.notZero(_totalSupply);

        _index += amount * SCALE / _totalSupply;

        _checkedTransferIn(REWARD_TOKEN, amount);

        emit DepositRewards(amount);
    }

    /// @inheritdoc IDiscreteStakingRewards
    function stakingToken() external view returns (address) {
        return address(STAKING_TOKEN);
    }

    /// @inheritdoc IDiscreteStakingRewards
    function rewardToken() external view returns (address) {
        return address(REWARD_TOKEN);
    }

    /// @inheritdoc IDiscreteStakingRewards
    function index() external view returns (uint256) {
        return _index;
    }

    /// @inheritdoc IDiscreteStakingRewards
    function userIndex(address account) external view returns (uint256) {
        return _userIndex[account];
    }

    /// @inheritdoc IDiscreteStakingRewards
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    /// @inheritdoc IDiscreteStakingRewards
    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    /// @inheritdoc IDiscreteStakingRewards
    function rewardBalance() external view returns (uint256) {
        return REWARD_TOKEN.balanceOf(address(this));
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    /// @inheritdoc IDiscreteStakingRewards
    function pendingRewards(address account) public view returns (uint256) {
        uint256 pending = _pendingRewards[account];
        uint256 shares = _balances[account];
        uint256 di = _index - _userIndex[account];

        return pending + (shares * di / SCALE);
    }

    // -------------------------------------------------------------------------
    // Functions - Private

    /// @notice Updates the per-user reward state.
    ///
    /// @param account The account to update rewards for.
    function _updateRewards(address account) private {
        _pendingRewards[account] = pendingRewards(account);
        _userIndex[account] = _index;
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
