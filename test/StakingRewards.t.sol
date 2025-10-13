// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { StakingRewards } from "../src/staking-rewards/StakingRewards.sol";

import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeeToken } from "../src/mocks/MockFeeToken.sol";
import { Assert } from "../src/utils/Assert.sol";

interface TestEvents {
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event DepositRewards(uint256 amount);
    event DurationUpdate(uint256 duration);
}

contract StakingRewardsTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // Constants

    address constant OWNER = address(0x1234);
    address constant ALICE = address(0xA);
    address constant BOB = address(0xB);

    uint256 constant DURATION = 7 days;
    uint256 constant SCALE = 1e18;
    uint256 constant MINT_AMOUNT = 1000 * SCALE;

    // -------------------------------------------------------------------------
    // State

    StakingRewards staking;
    MockToken stakingToken;
    MockToken rewardToken;

    address stakingAddr;
    address stakingTokenAddr;
    address rewardTokenAddr;

    // -------------------------------------------------------------------------
    // Setup

    function setUp() public {
        stakingToken = new MockToken();
        rewardToken = new MockToken();

        stakingTokenAddr = address(stakingToken);
        rewardTokenAddr = address(rewardToken);

        staking = new StakingRewards(OWNER, stakingTokenAddr, rewardTokenAddr, DURATION);
        stakingAddr = address(staking);

        // Mint tokens.
        stakingToken.mint(ALICE, MINT_AMOUNT);
        stakingToken.mint(BOB, MINT_AMOUNT);
        rewardToken.mint(OWNER, MINT_AMOUNT);

        // Approve for users.
        vm.prank(ALICE);
        stakingToken.approve(stakingAddr, UINT256_MAX);

        vm.prank(BOB);
        stakingToken.approve(stakingAddr, UINT256_MAX);

        vm.prank(OWNER);
        rewardToken.approve(stakingAddr, UINT256_MAX);
    }

    // -------------------------------------------------------------------------
    // Test - Constructor

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(staking.owner(), OWNER);
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

    function test_Constructor_RevertsOnZeroAddressStakingToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewards(OWNER, address(0), rewardTokenAddr, DURATION);
    }

    function test_Constructor_RevertsOnZeroAddressRewardToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewards(OWNER, stakingTokenAddr, address(0), DURATION);
    }

    function test_Constructor_RevertsOnZeroDuration() public {
        vm.expectRevert(Assert.Assert__Zero.selector);
        new StakingRewards(OWNER, stakingTokenAddr, rewardTokenAddr, 0);
    }

    function test_Constructor_RevertsOnSameTokens() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        new StakingRewards(OWNER, stakingTokenAddr, stakingTokenAddr, DURATION);
    }

    // -------------------------------------------------------------------------
    // Test - Stake

    function test_Stake_UpdatesBalanceAndTotalSupply() public {
        uint256 amount = 100 * SCALE;

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit Stake(ALICE, amount);

        vm.prank(ALICE);
        staking.stake(amount);

        assertEq(staking.balanceOf(ALICE), amount);
        assertEq(staking.totalSupply(), amount);
        assertEq(stakingToken.balanceOf(stakingAddr), amount);
    }

    function test_Stake_RevertsOnZeroAmount() public {
        vm.prank(ALICE);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.stake(0);
    }

    function testFuzz_Stake(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MINT_AMOUNT);

        vm.prank(ALICE);
        staking.stake(amount);

        assertEq(staking.balanceOf(ALICE), amount);
        assertEq(staking.totalSupply(), amount);
        assertEq(stakingToken.balanceOf(stakingAddr), amount);
    }

    // -------------------------------------------------------------------------
    // Test - Unstake

    function test_Unstake_UpdatesBalanceAndTotalSupply() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 unstakeAmount = 75 * SCALE;
        uint256 delta = stakeAmount - unstakeAmount;

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit Unstake(ALICE, unstakeAmount);

        vm.prank(ALICE);
        staking.unstake(unstakeAmount);

        assertEq(staking.balanceOf(ALICE), delta);
        assertEq(staking.totalSupply(), delta);
        assertEq(stakingToken.balanceOf(stakingAddr), delta);
        assertEq(stakingToken.balanceOf(ALICE), MINT_AMOUNT - delta);
    }

    function test_Unstake_RevertsOnZeroAmount() public {
        vm.prank(ALICE);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.unstake(0);
    }

    function test_Unstake_RevertsOnInsufficientBalance() public {
        uint256 amount = 100 * SCALE;

        vm.prank(ALICE);
        staking.stake(amount);

        vm.prank(ALICE);
        vm.expectRevert(); // Arithmetic underflow
        staking.unstake(amount + 1);
    }

    function testFuzz_Unstake(uint256 stakeAmount, uint256 unstakeAmount) public {
        vm.assume(stakeAmount > 0 && stakeAmount <= MINT_AMOUNT);
        vm.assume(unstakeAmount > 0 && unstakeAmount <= stakeAmount);

        uint256 delta = stakeAmount - unstakeAmount;

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.prank(ALICE);
        staking.unstake(unstakeAmount);

        assertEq(staking.balanceOf(ALICE), delta);
        assertEq(staking.totalSupply(), delta);
    }

    // -------------------------------------------------------------------------
    // Test - Deposit Rewards

    function test_DepositRewards_SetsRateAndPeriod() public {
        uint256 amount = 700 * SCALE;

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DepositRewards(amount);

        vm.prank(OWNER);
        staking.depositRewards(amount);

        assertEq(staking.rate(), amount / DURATION);
        assertEq(staking.periodFinish(), block.timestamp + DURATION);
        assertEq(staking.lastUpdated(), block.timestamp);
        assertEq(rewardToken.balanceOf(stakingAddr), amount);
    }

    function test_DepositRewards_RevertsOnZero() public {
        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(0);
    }

    function test_DepositRewards_RevertsNonOwner() public {
        vm.prank(ALICE);
        vm.expectRevert();
        staking.depositRewards(100 * SCALE);
    }

    function test_DepositRewards_DuringActivePeriod() public {
        uint256 initialAmount = 700 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(initialAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 additional = 300 * SCALE;
        uint256 remainingTime = DURATION - 1 days;
        uint256 remainingRewards = staking.rate() * remainingTime;
        uint256 newRate = (remainingRewards + additional) / DURATION;

        vm.prank(OWNER);
        staking.depositRewards(additional);

        assertEq(staking.rate(), newRate);
        assertEq(staking.periodFinish(), block.timestamp + DURATION);
    }

    function testFuzz_DepositRewards(uint256 amount) public {
        vm.assume(amount > SCALE && amount <= MINT_AMOUNT);

        vm.prank(OWNER);
        staking.depositRewards(amount);

        assertEq(staking.rate(), amount / DURATION);
        assertEq(staking.periodFinish(), block.timestamp + DURATION);
    }

    // -------------------------------------------------------------------------
    // Test - Set Duration

    function test_SetDuration_UpdatesDuration() public {
        uint256 newDuration = 14 days;

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DurationUpdate(newDuration);

        vm.prank(OWNER);
        staking.setDuration(newDuration);

        assertEq(staking.duration(), newDuration);
    }

    function test_SetDuration_RevertsDuringActivePeriod() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__GtFailed.selector);
        staking.setDuration(14 days);
    }

    function test_SetDuration_RevertsOnZero() public {
        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.setDuration(0);
    }

    function test_SetDuration_RevertsNonOwner() public {
        vm.prank(ALICE);
        vm.expectRevert();
        staking.setDuration(14 days);
    }

    // -------------------------------------------------------------------------
    // Test - Reward Accrual and Claim

    function test_PendingRewards_AccruesCorrectly() public {
        uint256 deposit = 700 * SCALE;
        uint256 stake = 100 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(deposit);

        vm.prank(ALICE);
        staking.stake(stake);

        vm.warp(block.timestamp + 1 days);

        uint256 expectedPending = (staking.rate() * 1 days * stake) / stake;
        assertEq(staking.pendingRewards(ALICE), expectedPending);

        vm.prank(BOB);
        staking.stake(stake);

        vm.warp(block.timestamp + 1 days);

        // For Alice: previous + share of next day.
        uint256 secondDayEarned = (staking.rate() * 1 days * stake) / (stake * 2);
        assertEq(staking.pendingRewards(ALICE), expectedPending + secondDayEarned);

        // For Bob: share of day two.
        assertEq(staking.pendingRewards(BOB), secondDayEarned);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.warp(block.timestamp + DURATION);

        uint256 pending = staking.pendingRewards(ALICE);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit ClaimRewards(ALICE, pending);

        vm.prank(ALICE);
        staking.claimRewards();

        assertEq(rewardToken.balanceOf(ALICE), pending);
        assertEq(staking.pendingRewards(ALICE), 0);
        assertEq(staking.userIndex(ALICE), staking.index());
    }

    function test_ClaimRewards_NoopIfZero() public {
        vm.prank(ALICE);
        staking.claimRewards();
        assertEq(rewardToken.balanceOf(ALICE), 0);
    }

    function testFuzz_PendingRewards(uint256 stake1, uint256 stake2) public {
        vm.assume(stake1 > 0 && stake1 <= 500 * SCALE);
        vm.assume(stake2 > 0 && stake2 <= 500 * SCALE);

        uint256 time = 1 days;

        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        vm.prank(ALICE);
        staking.stake(stake1);

        vm.prank(BOB);
        staking.stake(stake2);

        vm.warp(block.timestamp + time);

        uint256 totalStaked = stake1 + stake2;
        uint256 expectedTotalRewards = staking.rate() * time;
        uint256 pending1 = expectedTotalRewards * stake1 / totalStaked;
        uint256 pending2 = expectedTotalRewards * stake2 / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(ALICE), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(BOB), pending2, 1000);
    }

    // -------------------------------------------------------------------------
    // Test - Fee on Transfer

    function test_RejectsFeeOnTransfer() public {
        uint256 rewardAmount = 100 * SCALE;

        MockFeeToken feeToken = new MockFeeToken(OWNER, 1000);
        feeToken.mint(OWNER, MINT_AMOUNT);

        StakingRewards c = new StakingRewards(OWNER, stakingTokenAddr, address(feeToken), DURATION);

        vm.prank(OWNER);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(OWNER);
        c.depositRewards(rewardAmount);
    }

    // -------------------------------------------------------------------------
    // Test - Views

    function test_LastTimeRewardApplicable() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);
        assertEq(staking.lastTimeRewardApplicable(), block.timestamp);

        vm.warp(block.timestamp + DURATION / 2);
        assertEq(staking.lastTimeRewardApplicable(), block.timestamp);

        vm.warp(block.timestamp + DURATION);
        assertEq(staking.lastTimeRewardApplicable(), staking.periodFinish());
    }

    function test_CurrentIndex() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        uint256 stakeAmount = 100 * SCALE;
        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 dt = 1 days;
        uint256 expectedIndex = (staking.rate() * dt * SCALE) / stakeAmount;
        assertEq(staking.currentIndex(), expectedIndex);
    }

    function test_RewardPeriodActive() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        // Immediately after deposit: should be active.
        assertTrue(staking.periodRewardActive());

        // Halfway through: still active.
        vm.warp(block.timestamp + staking.duration() / 2);
        assertTrue(staking.periodRewardActive());

        // After finish: inactive.
        vm.warp(staking.periodFinish() + 1);
        assertFalse(staking.periodRewardActive());
    }

    function test_CurrentIndex_ZeroSupply() public view {
        assertEq(staking.currentIndex(), 0);
    }

    function test_PeriodRewardTotal() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        uint256 expected = staking.rate() * staking.duration();
        assertEq(staking.periodRewardTotal(), expected);
    }

    function test_PeriodRewardRemaining() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        // Halfway through.
        vm.warp(block.timestamp + staking.duration() / 2);
        uint256 expected = staking.rate() * (staking.periodFinish() - block.timestamp);
        assertEq(staking.periodRewardRemaining(), expected);

        // After finish.
        vm.warp(staking.periodFinish() + 1);
        assertEq(staking.periodRewardRemaining(), 0);
    }

    function test_PeriodRewardEmitted() public {
        vm.prank(OWNER);
        staking.depositRewards(700 * SCALE);

        // Initially none emitted.
        assertEq(staking.periodRewardEmitted(), 0);

        // Halfway through.
        vm.warp(block.timestamp + staking.duration() / 2);
        uint256 expected = staking.rate() * (staking.duration() / 2);
        assertEq(staking.periodRewardEmitted(), expected);

        // After finish.
        vm.warp(staking.periodFinish() + 1);
        assertEq(staking.periodRewardEmitted(), staking.rate() * staking.duration());
    }
}
