// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { HandlerBase } from "./HandlerBase.t.sol";
import { DiscreteStakingRewards } from "src/discrete-staking-rewards/DiscreteStakingRewards.sol";
import { MockToken } from "test/mocks/MockToken.sol";

contract DiscreteStakingRewardsHandler is HandlerBase {
    // =========================================================================
    // State
    // =========================================================================

    DiscreteStakingRewards private _staking;
    MockToken private _stakingToken;
    MockToken private _rewardToken;

    uint256 public ghost_prevIndex;
    uint256 public ghost_totalRewardsDeposited;
    uint256 public ghost_totalRewardsClaimed;

    /// @dev An upper bound on the rewards lost to rounding so far. Each deposit
    /// floors the index increment, losing less than `totalSupply / SCALE + 1`
    /// wei across all stakers. Each user update floors that user's accrual,
    /// losing less than one wei.
    uint256 public ghost_dustBound;

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(
        address owner,
        address[] memory actors,
        MockToken stakingToken,
        MockToken rewardToken,
        DiscreteStakingRewards staking
    ) {
        _initHandlerBase(owner, actors);

        _stakingToken = stakingToken;
        _rewardToken = rewardToken;
        _staking = staking;
    }

    // =========================================================================
    // Functions - Public
    // =========================================================================

    function stake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        amount = bound(amount, 1, MINT_AMOUNT);

        _stakingToken.mint(currentActor, amount);
        _stakingToken.approve(address(_staking), amount);

        _beforeUserUpdate();
        _staking.stake(amount);
        _afterAction();
    }

    function unstake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        uint256 balance = _staking.balanceOf(currentActor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        _beforeUserUpdate();
        _staking.unstake(amount);
        _afterAction();
    }

    function claimRewards(uint256 actorSeed) public useActor(actorSeed) {
        uint256 balBefore = _rewardToken.balanceOf(currentActor);

        _beforeUserUpdate();
        _staking.claimRewards();
        _afterAction();

        ghost_totalRewardsClaimed += _rewardToken.balanceOf(currentActor) - balBefore;
    }

    /// @dev Discrete deposits need stakers to share between.
    function depositRewards(uint256 amount) public useOwner {
        uint256 supply = _staking.totalSupply();
        if (supply == 0) return;

        // The smallest deposit that raises the index; smaller ones revert.
        amount = bound(amount, supply / SCALE + 1, MINT_AMOUNT);

        _rewardToken.mint(_owner, amount);
        _rewardToken.approve(address(_staking), amount);

        ghost_prevIndex = _staking.index();
        _staking.depositRewards(amount);
        _afterAction();

        ghost_totalRewardsDeposited += amount;
        ghost_dustBound += supply / SCALE + 1;
    }

    // =========================================================================
    // Helper View Functions
    // =========================================================================

    function sumOfBalances() public view returns (uint256 sum) {
        for (uint256 i; i < _actors.length; i++) {
            sum += _staking.balanceOf(_actors[i]);
        }
    }

    function sumOfPendingRewards() public view returns (uint256 sum) {
        for (uint256 i; i < _actors.length; i++) {
            sum += _staking.pendingRewards(_actors[i]);
        }
    }

    // =========================================================================
    // Functions - Private
    // =========================================================================

    function _beforeUserUpdate() private {
        ghost_prevIndex = _staking.index();
        ghost_dustBound += 1;
    }

    function _afterAction() private view {
        assertGe(_staking.index(), ghost_prevIndex);
    }
}
