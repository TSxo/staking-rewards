// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { HandlerBase } from "./HandlerBase.t.sol";
import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { MockToken } from "test/mocks/MockToken.sol";

contract StakingRewardsHandler is HandlerBase {
    // -------------------------------------------------------------------------
    // State

    StakingRewards private _staking;
    MockToken private _stakingToken;
    MockToken private _rewardToken;

    uint256 public ghost_prevIndex;
    mapping(address => uint256) public ghost_prevUserIndex;
    uint256 public ghost_totalRewardsDeposited;
    uint256 public ghost_totalRewardsClaimed;

    // -------------------------------------------------------------------------
    // Constructor

    constructor(
        address owner,
        address[] memory actors,
        MockToken stakingToken,
        MockToken rewardToken,
        StakingRewards staking
    ) {
        _initHandlerBase(owner, actors);

        _stakingToken = stakingToken;
        _rewardToken = rewardToken;
        _staking = staking;

        ghost_prevIndex = _staking.index();
    }

    // -------------------------------------------------------------------------
    // Functions - Public

    function stake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        amount = bound(amount, 1, MINT_AMOUNT);

        _updateIndexes();
        _stake(amount);
        _assertIndexMonotonicity();
    }

    function unstake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        uint256 balance = _staking.balanceOf(currentActor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        _updateIndexes();
        _staking.unstake(amount);
        _assertIndexMonotonicity();
    }

    function claimRewards(uint256 actorSeed) public useActor(actorSeed) {
        _updateIndexes();

        uint256 balBefore = _rewardToken.balanceOf(currentActor);
        _staking.claimRewards();
        uint256 balAfter = _rewardToken.balanceOf(currentActor);

        uint256 delta = balAfter - balBefore;
        if (delta > 0) ghost_totalRewardsClaimed += delta;

        _assertIndexMonotonicity();
    }

    function setDuration(uint256 duration) public useOwner {
        if (block.timestamp <= _staking.periodFinish()) return;

        _updateIndexes();
        duration = bound(duration, 1, 7 days);
        _staking.setDuration(duration);

        _assertIndexMonotonicity();
    }

    function depositRewards(uint256 amount) public useOwner {
        amount = bound(amount, 10 * SCALE, MINT_AMOUNT);

        _updateIndexes();

        _rewardToken.mint(_owner, amount);
        _rewardToken.approve(address(_staking), amount);
        _staking.depositRewards(amount);

        ghost_totalRewardsDeposited += amount;

        _assertIndexMonotonicity();
    }

    function warpTime(uint256 delta) public {
        delta = bound(delta, 1, 7 days);
        _updateIndexes();
        vm.warp(block.timestamp + delta);
        _assertIndexMonotonicity();
    }

    // -------------------------------------------------------------------------
    // Helper View Functions

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

    // -------------------------------------------------------------------------
    // Functions - Private

    function _stake(uint256 amount) private {
        _stakingToken.mint(currentActor, amount);
        _stakingToken.approve(address(_staking), amount);
        _staking.stake(amount);
    }

    function _updateIndexes() private {
        ghost_prevIndex = _staking.index();
        ghost_prevUserIndex[currentActor] = _staking.userIndex(currentActor);
    }

    function _assertIndexMonotonicity() private view {
        assertGe(_staking.index(), ghost_prevIndex);
        assertGe(_staking.currentIndex(), ghost_prevIndex);
        assertGe(_staking.userIndex(currentActor), ghost_prevUserIndex[currentActor]);
    }
}
