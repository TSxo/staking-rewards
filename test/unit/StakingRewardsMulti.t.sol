// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { StakingRewardsMulti } from "src/staking-rewards-multi/StakingRewardsMulti.sol";
import { Assert } from "src/utils/Assert.sol";

import { Base } from "test/Base.t.sol";
import { MockToken } from "test/mocks/MockToken.sol";
import { MockFeeToken } from "test/mocks/MockFeeToken.sol";

interface TestEvents {
    event AddReward(address indexed token, uint256 duration);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, address indexed token, uint256 amount);
    event DepositRewards(address indexed token, uint256 amount);
    event DurationUpdate(address indexed token, uint256 duration);
}

contract StakingRewardsMultiTest is Base, TestEvents {
    // =========================================================================
    // Constants
    // =========================================================================

    uint256 constant DURATION = 7 days;

    // =========================================================================
    // State
    // =========================================================================

    StakingRewardsMulti staking;
    address stakingAddr;

    // =========================================================================
    // Setup
    // =========================================================================

    function setUp() public {
        _initBase();

        staking = new StakingRewardsMulti(owner, stakingTokenAddr);
        stakingAddr = address(staking);

        _dealTokens(stakingAddr);

        vm.prank(owner);
        staking.addReward(rewardTokenAddr, DURATION);
    }

    // =========================================================================
    // Test - Constructor
    // =========================================================================

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(staking.owner(), owner);
        assertEq(staking.stakingToken(), stakingTokenAddr);
        assertEq(staking.totalSupply(), 0);
    }

    function test_RevertWhen_Constructor_StakingTokenIsZeroAddress() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewardsMulti(owner, address(0));
    }

    // =========================================================================
    // Test - Add Reward
    // =========================================================================

    function test_AddReward_InitializesCorrectly() public {
        address newReward = address(new MockToken());

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit AddReward(newReward, DURATION);

        vm.prank(owner);
        staking.addReward(newReward, DURATION);

        assertEq(staking.duration(newReward), DURATION);
        assertEq(staking.periodFinish(newReward), 0);
        assertEq(staking.lastUpdated(newReward), 0);
        assertEq(staking.rate(newReward), 0);
        assertEq(staking.index(newReward), 0);
        assertEq(staking.rewardBalance(newReward), 0);

        address[] memory tokens = staking.rewardTokens();
        assertEq(tokens.length, 2);
        assertEq(tokens[0], rewardTokenAddr);
        assertEq(tokens[1], newReward);
    }

    function test_RevertWhen_AddReward_TokenIsZeroAddress() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        vm.prank(owner);
        staking.addReward(address(0), DURATION);
    }

    function test_RevertWhen_AddReward_TokenIsStakingToken() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        vm.prank(owner);
        staking.addReward(stakingTokenAddr, DURATION);
    }

    function test_RevertWhen_AddReward_DurationIsZero() public {
        address newReward = address(new MockToken());

        vm.expectRevert(Assert.Assert__Zero.selector);
        vm.prank(owner);
        staking.addReward(newReward, 0);
    }

    function test_RevertWhen_AddReward_TokenAlreadyAdded() public {
        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(owner);
        staking.addReward(rewardTokenAddr, DURATION);
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

        vm.prank(actor);
        staking.stake(amount);

        assertEq(staking.balanceOf(actor), amount);
        assertEq(staking.totalSupply(), amount);
        assertEq(stakingToken.balanceOf(stakingAddr), amount);
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

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit DepositRewards(rewardTokenAddr, amount);

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, amount);

        assertEq(staking.rate(rewardTokenAddr), amount / DURATION);
        assertEq(staking.periodFinish(rewardTokenAddr), vm.getBlockTimestamp() + DURATION);
        assertEq(staking.lastUpdated(rewardTokenAddr), vm.getBlockTimestamp());
        assertEq(rewardToken.balanceOf(stakingAddr), amount);
    }

    function test_RevertWhen_DepositRewards_AmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(rewardTokenAddr, 0);
    }

    function test_RevertWhen_DepositRewards_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.depositRewards(rewardTokenAddr, 100 * SCALE);
    }

    function test_DepositRewards_DuringActivePeriod() public {
        uint256 initialAmount = 700 * SCALE;

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, initialAmount);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 additional = 300 * SCALE;
        uint256 remainingTime = DURATION - 1 days;
        uint256 remainingRewards = staking.rate(rewardTokenAddr) * remainingTime;
        uint256 newRate = (remainingRewards + additional) / DURATION;

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, additional);

        assertEq(staking.rate(rewardTokenAddr), newRate);
        assertEq(staking.periodFinish(rewardTokenAddr), vm.getBlockTimestamp() + DURATION);
    }

    function testFuzz_DepositRewards(uint256 amount) public {
        amount = bound(amount, SCALE, MINT_AMOUNT);

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, amount);

        assertEq(staking.rate(rewardTokenAddr), amount / DURATION);
        assertEq(staking.periodFinish(rewardTokenAddr), vm.getBlockTimestamp() + DURATION);
    }

    // =========================================================================
    // Test - Set Duration
    // =========================================================================

    function test_SetDuration_UpdatesDuration() public {
        uint256 newDuration = 14 days;

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit DurationUpdate(rewardTokenAddr, newDuration);

        vm.prank(owner);
        staking.setDuration(rewardTokenAddr, newDuration);

        assertEq(staking.duration(rewardTokenAddr), newDuration);
    }

    function test_RevertWhen_SetDuration_PeriodIsActive() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        vm.prank(owner);
        vm.expectRevert(Assert.Assert__GtFailed.selector);
        staking.setDuration(rewardTokenAddr, 14 days);
    }

    function test_RevertWhen_SetDuration_DurationIsZero() public {
        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.setDuration(rewardTokenAddr, 0);
    }

    function test_RevertWhen_SetDuration_CallerIsNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.setDuration(rewardTokenAddr, 14 days);
    }

    // =========================================================================
    // Test - Reward Accrual and Claim
    // =========================================================================

    function test_PendingRewards_AccruesCorrectly() public {
        uint256 deposit = 700 * SCALE;
        uint256 stake = 100 * SCALE;

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, deposit);

        vm.prank(alice);
        staking.stake(stake);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 expectedPending = (staking.rate(rewardTokenAddr) * 1 days * stake) / stake;
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), expectedPending);

        vm.prank(bob);
        staking.stake(stake);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        // For Alice: previous + share of next day.
        uint256 secondDayEarned = (staking.rate(rewardTokenAddr) * 1 days * stake) / (stake * 2);
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), expectedPending + secondDayEarned);

        // For Bob: share of day two.
        assertEq(staking.pendingRewards(bob, rewardTokenAddr), secondDayEarned);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.warp(vm.getBlockTimestamp() + DURATION);

        uint256 pending = staking.pendingRewards(alice, rewardTokenAddr);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, true, false, true, stakingAddr);
        emit ClaimRewards(alice, rewardTokenAddr, pending);

        vm.prank(alice);
        staking.claimRewards();

        assertEq(rewardToken.balanceOf(alice), pending);
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), 0);
        assertEq(staking.userIndex(alice, rewardTokenAddr), staking.index(rewardTokenAddr));
    }

    function test_ClaimRewards_Single_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.warp(vm.getBlockTimestamp() + DURATION);

        uint256 pending = staking.pendingRewards(alice, rewardTokenAddr);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, true, false, true, stakingAddr);
        emit ClaimRewards(alice, rewardTokenAddr, pending);

        vm.prank(alice);
        staking.claimRewards(rewardTokenAddr);

        assertEq(rewardToken.balanceOf(alice), pending);
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), 0);
        assertEq(staking.userIndex(alice, rewardTokenAddr), staking.index(rewardTokenAddr));
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
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(alice);
        staking.stake(stake1);

        vm.prank(bob);
        staking.stake(stake2);

        vm.warp(vm.getBlockTimestamp() + time);

        uint256 totalStaked = stake1 + stake2;
        uint256 expectedTotalRewards = staking.rate(rewardTokenAddr) * time;
        uint256 pending1 = expectedTotalRewards * stake1 / totalStaked;
        uint256 pending2 = expectedTotalRewards * stake2 / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(alice, rewardTokenAddr), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(bob, rewardTokenAddr), pending2, 1000);
    }

    // =========================================================================
    // Test - Fee on Transfer
    // =========================================================================

    function test_RevertWhen_Stake_TokenTakesFee() public {
        MockFeeToken feeToken = new MockFeeToken(owner, 1000);
        feeToken.mint(alice, MINT_AMOUNT);

        StakingRewardsMulti c = new StakingRewardsMulti(owner, address(feeToken));

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

        StakingRewardsMulti c = new StakingRewardsMulti(owner, stakingTokenAddr);

        address feeTokenAddr = address(feeToken);
        vm.prank(owner);
        c.addReward(feeTokenAddr, DURATION);

        vm.prank(owner);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(owner);
        c.depositRewards(feeTokenAddr, rewardAmount);
    }

    // =========================================================================
    // Test - Views
    // =========================================================================

    function test_LastTimeRewardApplicable() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), vm.getBlockTimestamp());

        vm.warp(vm.getBlockTimestamp() + DURATION / 2);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), vm.getBlockTimestamp());

        vm.warp(vm.getBlockTimestamp() + DURATION);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), staking.periodFinish(rewardTokenAddr));
    }

    function test_CurrentIndex() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        uint256 stakeAmount = 100 * SCALE;
        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.warp(vm.getBlockTimestamp() + 1 days);

        uint256 dt = 1 days;
        uint256 expectedIndex = (staking.rate(rewardTokenAddr) * dt * SCALE) / stakeAmount;
        assertEq(staking.currentIndex(rewardTokenAddr), expectedIndex);
    }

    function test_RewardPeriodActive() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Immediately after deposit: should be active.
        assertTrue(staking.periodRewardActive(rewardTokenAddr));

        // Halfway through: still active.
        vm.warp(vm.getBlockTimestamp() + staking.duration(rewardTokenAddr) / 2);
        assertTrue(staking.periodRewardActive(rewardTokenAddr));

        // After finish: inactive.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertFalse(staking.periodRewardActive(rewardTokenAddr));
    }

    function test_CurrentIndex_ZeroSupply() public view {
        assertEq(staking.currentIndex(rewardTokenAddr), 0);
    }

    function test_PeriodRewardTotal() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        uint256 expected = staking.rate(rewardTokenAddr) * staking.duration(rewardTokenAddr);
        assertEq(staking.periodRewardTotal(rewardTokenAddr), expected);
    }

    function test_PeriodRewardRemaining() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Halfway through.
        vm.warp(vm.getBlockTimestamp() + staking.duration(rewardTokenAddr) / 2);
        uint256 expected =
            staking.rate(rewardTokenAddr) * (staking.periodFinish(rewardTokenAddr) - vm.getBlockTimestamp());
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), expected);

        // After finish.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), 0);
    }

    function test_PeriodRewardEmitted() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Initially none emitted.
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), 0);

        // Halfway through.
        vm.warp(vm.getBlockTimestamp() + staking.duration(rewardTokenAddr) / 2);
        uint256 expected = staking.rate(rewardTokenAddr) * (staking.duration(rewardTokenAddr) / 2);
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), expected);

        // After finish.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertEq(
            staking.periodRewardEmitted(rewardTokenAddr),
            staking.rate(rewardTokenAddr) * staking.duration(rewardTokenAddr)
        );
    }

    // =========================================================================
    // Test - Period Views (regressions)
    // =========================================================================

    /// @dev Regression: `periodRewardActive` underflowed before the first
    /// deposit, because it computed `periodFinish - duration` from zero.
    function test_PeriodViews_BeforeFirstDeposit() public view {
        assertEq(staking.periodStart(rewardTokenAddr), 0);
        assertFalse(staking.periodRewardActive(rewardTokenAddr));
        assertEq(staking.periodRewardTotal(rewardTokenAddr), 0);
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), 0);
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), 0);
    }

    /// @dev Regression: after `setDuration`, the views paired the finished
    /// period's rate with the new duration, misreporting what it emitted.
    function test_PeriodViews_AfterSetDuration() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);
        uint256 periodRate = staking.rate(rewardTokenAddr);

        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        vm.prank(owner);
        staking.setDuration(rewardTokenAddr, 30 days);

        assertFalse(staking.periodRewardActive(rewardTokenAddr));
        assertEq(staking.periodRewardTotal(rewardTokenAddr), periodRate * DURATION);
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), periodRate * DURATION);
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), 0);
    }

    /// @dev A top-up restarts the period: it begins at the top-up and runs for
    /// the full duration at the new rate.
    function test_PeriodViews_TopUpRestartsPeriod() public {
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        vm.warp(vm.getBlockTimestamp() + 2 days);
        vm.prank(owner);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        uint256 topUp = vm.getBlockTimestamp();
        assertEq(staking.periodStart(rewardTokenAddr), topUp);
        assertEq(staking.periodFinish(rewardTokenAddr), topUp + DURATION);
        assertEq(staking.periodRewardTotal(rewardTokenAddr), staking.rate(rewardTokenAddr) * DURATION);
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), 0);
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
        staking.depositRewards(rewardTokenAddr, DURATION);
        assertEq(staking.rate(rewardTokenAddr), 1);

        uint256 snapshot = vm.snapshotState();

        // Ten 1-second checkpoints, each by an account with nothing staked.
        for (uint256 i; i < 10; ++i) {
            vm.warp(vm.getBlockTimestamp() + 1);
            vm.prank(bob);
            staking.claimRewards();
        }
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), 0, "frequent checkpoints");

        // The same 10 seconds in one update.
        vm.revertToState(snapshot);
        vm.warp(vm.getBlockTimestamp() + 10);
        vm.prank(bob);
        staking.claimRewards();
        assertEq(staking.pendingRewards(alice, rewardTokenAddr), 10, "one checkpoint");
    }
}
