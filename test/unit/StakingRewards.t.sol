// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { Assert } from "src/utils/Assert.sol";

import { Base } from "test/Base.t.sol";
import { MockFeeToken } from "test/mocks/MockFeeToken.sol";

interface TestEvents {
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event DepositRewards(uint256 amount);
    event DurationUpdate(uint256 duration);
}

contract StakingRewardsTest is Base, TestEvents {
    // =========================================================================
    // Constants
    // =========================================================================

    uint256 constant DURATION = 7 days;

    // =========================================================================
    // State
    // =========================================================================

    StakingRewards staking;
    address stakingAddr;

    // =========================================================================
    // Setup
    // =========================================================================

    function setUp() public {
        _initBase();

        staking = new StakingRewards(owner, stakingTokenAddr, rewardTokenAddr, DURATION);
        stakingAddr = address(staking);

        _dealTokens(stakingAddr);
    }

    // =========================================================================
    // Test - Constructor
    // =========================================================================

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(staking.owner(), owner);
        assertEq(staking.stakingToken(), stakingTokenAddr);
        assertEq(staking.rewardToken(), rewardTokenAddr);
        assertEq(staking.duration(), DURATION);
        assertEq(staking.periodFinish(), 0);
        assertEq(staking.lastUpdated(), 0);
        assertEq(staking.rate(), 0);
        assertEq(staking.index(), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(staking.rewardBalance(), 0);
    }

    function test_RevertWhen_Constructor_StakingTokenIsZeroAddress() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewards(owner, address(0), rewardTokenAddr, DURATION);
    }

    function test_RevertWhen_Constructor_RewardTokenIsZeroAddress() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewards(owner, stakingTokenAddr, address(0), DURATION);
    }

    function test_RevertWhen_Constructor_DurationIsZero() public {
        vm.expectRevert(Assert.Assert__Zero.selector);
        new StakingRewards(owner, stakingTokenAddr, rewardTokenAddr, 0);
    }

    function test_RevertWhen_Constructor_TokensAreSame() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        new StakingRewards(owner, stakingTokenAddr, stakingTokenAddr, DURATION);
    }

    // =========================================================================
    // Test - Stake
    // =========================================================================

    function test_Stake_UpdatesBalanceAndTotalSupply() public {
        uint256 amount = 100 * SCALE;

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit Stake(alice, amount);

        vm.prank(alice);
        staking.stake(amount);

        assertEq(staking.balanceOf(alice), amount);
        assertEq(staking.totalSupply(), amount);
        assertEq(stakingToken.balanceOf(stakingAddr), amount);
    }

    function test_RevertWhen_Stake_AmountIsZero() public {
        vm.prank(alice);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.stake(0);
    }

    function testFuzz_Stake(uint256 amount, uint256 actorSeed) public {
        amount = bound(amount, 1, MINT_AMOUNT);
        address actor = _actor(actorSeed);

        uint256 initialBalance = stakingToken.balanceOf(actor);

        vm.prank(actor);
        staking.stake(amount);

        assertEq(staking.balanceOf(actor), amount);
        assertEq(staking.totalSupply(), amount);
        assertEq(stakingToken.balanceOf(stakingAddr), amount);
        assertEq(stakingToken.balanceOf(actor), initialBalance - amount);
    }

    // =========================================================================
    // Test - Unstake
    // =========================================================================

    function test_Unstake_UpdatesBalanceAndTotalSupply() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 unstakeAmount = 75 * SCALE;
        uint256 delta = stakeAmount - unstakeAmount;

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit Unstake(alice, unstakeAmount);

        vm.prank(alice);
        staking.unstake(unstakeAmount);

        assertEq(staking.balanceOf(alice), delta);
        assertEq(staking.totalSupply(), delta);
        assertEq(stakingToken.balanceOf(stakingAddr), delta);
        assertEq(stakingToken.balanceOf(alice), MINT_AMOUNT - delta);
    }

    function test_RevertWhen_Unstake_AmountIsZero() public {
        vm.prank(alice);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.unstake(0);
    }

    function test_RevertWhen_Unstake_AmountExceedsBalance() public {
        uint256 amount = 100 * SCALE;

        vm.prank(alice);
        staking.stake(amount);

        vm.prank(alice);
        vm.expectRevert(); // Arithmetic underflow
        staking.unstake(amount + 1);
    }

    function testFuzz_Unstake(uint256 stakeAmount, uint256 unstakeAmount, uint256 actorSeed) public {
        stakeAmount = bound(stakeAmount, 1, MINT_AMOUNT);
        unstakeAmount = bound(unstakeAmount, 1, stakeAmount);

        address actor = _actor(actorSeed);
        uint256 delta = stakeAmount - unstakeAmount;

        vm.prank(actor);
        staking.stake(stakeAmount);

        vm.prank(actor);
        staking.unstake(unstakeAmount);

        assertEq(staking.balanceOf(actor), delta);
        assertEq(staking.totalSupply(), delta);
    }

    // =========================================================================
    // Test - Deposit Rewards
    // =========================================================================

    function test_DepositRewards_SetsRateAndPeriod() public {
        uint256 amount = 700 * SCALE;

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DepositRewards(amount);

        vm.prank(owner);
        staking.depositRewards(amount);

        assertEq(staking.rate(), amount / DURATION);
        assertEq(staking.periodFinish(), vm.getBlockTimestamp() + DURATION);
        assertEq(staking.lastUpdated(), vm.getBlockTimestamp());
        assertEq(rewardToken.balanceOf(stakingAddr), amount);
    }

    function test_RevertWhen_DepositRewards_AmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(0);
    }

    function test_RevertWhen_DepositRewards_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.depositRewards(100 * SCALE);
    }

    function test_DepositRewards_DuringActivePeriod() public {
        uint256 initialAmount = 700 * SCALE;

        vm.prank(owner);
        staking.depositRewards(initialAmount);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 additional = 300 * SCALE;
        uint256 remainingTime = DURATION - 1 days;
        uint256 remainingRewards = staking.rate() * remainingTime;
        uint256 newRate = (remainingRewards + additional) / DURATION;

        vm.prank(owner);
        staking.depositRewards(additional);

        assertEq(staking.rate(), newRate);
        assertEq(staking.periodFinish(), vm.getBlockTimestamp() + DURATION);
    }

    function testFuzz_DepositRewards(uint256 amount) public {
        amount = bound(amount, SCALE, MINT_AMOUNT);

        vm.prank(owner);
        staking.depositRewards(amount);

        assertEq(staking.rate(), amount / DURATION);
        assertEq(staking.periodFinish(), vm.getBlockTimestamp() + DURATION);
    }

    // =========================================================================
    // Test - Set Duration
    // =========================================================================

    function test_SetDuration_UpdatesDuration() public {
        uint256 newDuration = 14 days;

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DurationUpdate(newDuration);

        vm.prank(owner);
        staking.setDuration(newDuration);

        assertEq(staking.duration(), newDuration);
    }

    function test_RevertWhen_SetDuration_PeriodIsActive() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        vm.prank(owner);
        vm.expectRevert(Assert.Assert__GtFailed.selector);
        staking.setDuration(14 days);
    }

    function test_RevertWhen_SetDuration_DurationIsZero() public {
        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.setDuration(0);
    }

    function test_RevertWhen_SetDuration_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.setDuration(14 days);
    }

    // =========================================================================
    // Test - Reward Accrual and Claim
    // =========================================================================

    function test_PendingRewards_AccruesCorrectly() public {
        uint256 deposit = 700 * SCALE;
        uint256 stake = 100 * SCALE;

        vm.prank(owner);
        staking.depositRewards(deposit);

        vm.prank(alice);
        staking.stake(stake);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 expectedPending = (staking.rate() * 1 days * stake) / stake;
        assertEq(staking.pendingRewards(alice), expectedPending);

        vm.prank(bob);
        staking.stake(stake);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        // For Alice: previous + share of next day.
        uint256 secondDayEarned = (staking.rate() * 1 days * stake) / (stake * 2);
        assertEq(staking.pendingRewards(alice), expectedPending + secondDayEarned);

        // For Bob: share of day two.
        assertEq(staking.pendingRewards(bob), secondDayEarned);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(owner);
        staking.depositRewards(rewardAmount);

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.warp(vm.getBlockTimestamp() + DURATION);

        uint256 pending = staking.pendingRewards(alice);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit ClaimRewards(alice, pending);

        vm.prank(alice);
        staking.claimRewards();

        assertEq(rewardToken.balanceOf(alice), pending);
        assertEq(staking.pendingRewards(alice), 0);
        assertEq(staking.userIndex(alice), staking.index());
    }

    function test_ClaimRewards_NoopIfZero() public {
        vm.prank(alice);
        staking.claimRewards();
        assertEq(rewardToken.balanceOf(alice), 0);
    }

    function testFuzz_PendingRewards(uint256 stake1, uint256 stake2, uint256 time) public {
        stake1 = bound(stake1, 1, 500 * SCALE);
        stake2 = bound(stake2, 1, 500 * SCALE);
        time = bound(time, 1 days, DURATION);

        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        vm.prank(owner);
        staking.depositRewards(rewardAmount);

        vm.prank(alice);
        staking.stake(stake1);

        vm.prank(bob);
        staking.stake(stake2);

        vm.warp(vm.getBlockTimestamp() + time);

        uint256 totalStaked = stake1 + stake2;
        uint256 expectedTotalRewards = staking.rate() * time;
        uint256 pending1 = expectedTotalRewards * stake1 / totalStaked;
        uint256 pending2 = expectedTotalRewards * stake2 / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(alice), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(bob), pending2, 1000);
    }

    // =========================================================================
    // Test - Fee on Transfer
    // =========================================================================

    function test_RevertWhen_Stake_TokenTakesFee() public {
        MockFeeToken feeToken = new MockFeeToken(owner, 1000);
        feeToken.mint(alice, MINT_AMOUNT);

        StakingRewards c = new StakingRewards(owner, address(feeToken), rewardTokenAddr, DURATION);

        vm.prank(alice);
        feeToken.approve(address(c), MINT_AMOUNT);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(alice);
        c.stake(100 * SCALE);
    }

    function test_RevertWhen_DepositRewards_TokenTakesFee() public {
        uint256 rewardAmount = 100 * SCALE;

        MockFeeToken feeToken = new MockFeeToken(owner, 1000);
        feeToken.mint(owner, MINT_AMOUNT);

        StakingRewards c = new StakingRewards(owner, stakingTokenAddr, address(feeToken), DURATION);

        vm.prank(owner);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(owner);
        c.depositRewards(rewardAmount);
    }

    // =========================================================================
    // Test - Views
    // =========================================================================

    function test_LastTimeRewardApplicable() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);
        assertEq(staking.lastTimeRewardApplicable(), vm.getBlockTimestamp());

        vm.warp(vm.getBlockTimestamp() + DURATION / 2);
        assertEq(staking.lastTimeRewardApplicable(), vm.getBlockTimestamp());

        vm.warp(vm.getBlockTimestamp() + DURATION);
        assertEq(staking.lastTimeRewardApplicable(), staking.periodFinish());
    }

    function test_CurrentIndex() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        uint256 stakeAmount = 100 * SCALE;
        vm.prank(alice);
        staking.stake(stakeAmount);

        uint256 dt = 1 days;
        vm.warp(vm.getBlockTimestamp() + dt);

        uint256 expectedIndex = (staking.rate() * dt * SCALE) / stakeAmount;
        assertEq(staking.currentIndex(), expectedIndex);
    }

    function test_RewardPeriodActive() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        // Immediately after deposit: should be active.
        assertTrue(staking.periodRewardActive());

        // Halfway through: still active.
        vm.warp(vm.getBlockTimestamp() + staking.duration() / 2);
        assertTrue(staking.periodRewardActive());

        // After finish: inactive.
        vm.warp(staking.periodFinish() + 1);
        assertFalse(staking.periodRewardActive());
    }

    function test_CurrentIndex_ZeroSupply() public view {
        assertEq(staking.currentIndex(), 0);
    }

    function test_PeriodRewardTotal() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        uint256 expected = staking.rate() * staking.duration();
        assertEq(staking.periodRewardTotal(), expected);
    }

    function test_PeriodRewardRemaining() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        // Halfway through.
        vm.warp(vm.getBlockTimestamp() + staking.duration() / 2);
        uint256 expected = staking.rate() * (staking.periodFinish() - vm.getBlockTimestamp());
        assertEq(staking.periodRewardRemaining(), expected);

        // After finish.
        vm.warp(staking.periodFinish() + 1);
        assertEq(staking.periodRewardRemaining(), 0);
    }

    function test_PeriodRewardEmitted() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        // Initially none emitted.
        assertEq(staking.periodRewardEmitted(), 0);

        // Halfway through.
        vm.warp(vm.getBlockTimestamp() + staking.duration() / 2);
        uint256 expected = staking.rate() * (staking.duration() / 2);
        assertEq(staking.periodRewardEmitted(), expected);

        // After finish.
        vm.warp(staking.periodFinish() + 1);
        assertEq(staking.periodRewardEmitted(), staking.rate() * staking.duration());
    }

    // =========================================================================
    // Test - Period Views (regressions)
    // =========================================================================

    /// @dev Regression: `periodRewardActive` underflowed before the first
    /// deposit, because it computed `periodFinish - duration` from zero.
    function test_PeriodViews_BeforeFirstDeposit() public view {
        assertEq(staking.periodStart(), 0);
        assertFalse(staking.periodRewardActive());
        assertEq(staking.periodRewardTotal(), 0);
        assertEq(staking.periodRewardEmitted(), 0);
        assertEq(staking.periodRewardRemaining(), 0);
    }

    /// @dev Regression: after `setDuration`, the views paired the finished
    /// period's rate with the new duration, misreporting what it emitted.
    function test_PeriodViews_AfterSetDuration() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);
        uint256 periodRate = staking.rate();

        vm.warp(staking.periodFinish() + 1);
        vm.prank(owner);
        staking.setDuration(30 days);

        assertFalse(staking.periodRewardActive());
        assertEq(staking.periodRewardTotal(), periodRate * DURATION);
        assertEq(staking.periodRewardEmitted(), periodRate * DURATION);
        assertEq(staking.periodRewardRemaining(), 0);
    }

    /// @dev A top-up restarts the period: it begins at the top-up and runs for
    /// the full duration at the new rate.
    function test_PeriodViews_TopUpRestartsPeriod() public {
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        vm.warp(vm.getBlockTimestamp() + 2 days);
        vm.prank(owner);
        staking.depositRewards(700 * SCALE);

        uint256 topUp = vm.getBlockTimestamp();
        assertEq(staking.periodStart(), topUp);
        assertEq(staking.periodFinish(), topUp + DURATION);
        assertEq(staking.periodRewardTotal(), staking.rate() * DURATION);
        assertEq(staking.periodRewardEmitted(), 0);
    }

    // =========================================================================
    // Test - Known Limits
    // =========================================================================

    /// @dev Known limit, inherited from Synthetix: each update floors the index
    /// increment, so frequent checkpoints can erase accrual when
    /// `rate * dt * SCALE < totalSupply`. A claim with nothing owed still
    /// checkpoints, so anyone can trigger an update.
    function test_Checkpoints_FrequentUpdatesLoseRoundedAccrual() public {
        vm.prank(alice);
        staking.stake(10 * SCALE);

        // A deposit of `DURATION` base units sets a rate of 1 per second.
        vm.prank(owner);
        staking.depositRewards(DURATION);
        assertEq(staking.rate(), 1);

        uint256 snapshot = vm.snapshotState();

        // Ten 1-second checkpoints, each by an account with nothing staked.
        for (uint256 i; i < 10; ++i) {
            vm.warp(vm.getBlockTimestamp() + 1);
            vm.prank(bob);
            staking.claimRewards();
        }
        assertEq(staking.pendingRewards(alice), 0, "frequent checkpoints");

        // The same 10 seconds in one update.
        vm.revertToState(snapshot);
        vm.warp(vm.getBlockTimestamp() + 10);
        vm.prank(bob);
        staking.claimRewards();
        assertEq(staking.pendingRewards(alice), 10, "one checkpoint");
    }
}
