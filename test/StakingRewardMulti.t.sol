// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { StakingRewardsMulti } from "../src/staking-rewards-multi/StakingRewardsMulti.sol";

import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeeToken } from "../src/mocks/MockFeeToken.sol";
import { Assert } from "../src/utils/Assert.sol";

interface TestEvents {
    event AddReward(address indexed token, uint256 duration);
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, address indexed token, uint256 amount);
    event DepositRewards(address indexed token, uint256 amount);
    event DurationUpdate(address indexed token, uint256 duration);
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

    StakingRewardsMulti staking;
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

        staking = new StakingRewardsMulti(OWNER, stakingTokenAddr);
        stakingAddr = address(staking);

        vm.prank(OWNER);
        staking.addReward(rewardTokenAddr, DURATION);

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
        assertEq(staking.totalSupply(), 0);
    }

    function test_Constructor_RevertsOnZeroAddressStakingToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new StakingRewardsMulti(OWNER, address(0));
    }

    // -------------------------------------------------------------------------
    // Test - Add Reward

    function test_AddReward_InitializesCorrectly() public {
        address newReward = address(new MockToken());

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit AddReward(newReward, DURATION);

        vm.prank(OWNER);
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

    function test_AddReward_RevertsOnZeroAddressRewardToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        vm.prank(OWNER);
        staking.addReward(address(0), DURATION);
    }

    function test_AddReward_RevertsOnSameAsStakingToken() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        vm.prank(OWNER);
        staking.addReward(stakingTokenAddr, DURATION);
    }

    function test_AddReward_RevertsOnZeroDuration() public {
        address newReward = address(new MockToken());

        vm.expectRevert(Assert.Assert__Zero.selector);
        vm.prank(OWNER);
        staking.addReward(newReward, 0);
    }

    function test_AddReward_RevertsOnAlreadyAdded() public {
        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(OWNER);
        staking.addReward(rewardTokenAddr, DURATION);
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

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit DepositRewards(rewardTokenAddr, amount);

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, amount);

        assertEq(staking.rate(rewardTokenAddr), amount / DURATION);
        assertEq(staking.periodFinish(rewardTokenAddr), block.timestamp + DURATION);
        assertEq(staking.lastUpdated(rewardTokenAddr), block.timestamp);
        assertEq(rewardToken.balanceOf(stakingAddr), amount);
    }

    function test_DepositRewards_RevertsOnZero() public {
        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(rewardTokenAddr, 0);
    }

    function test_DepositRewards_RevertsNonOwner() public {
        vm.prank(ALICE);
        vm.expectRevert();
        staking.depositRewards(rewardTokenAddr, 100 * SCALE);
    }

    function test_DepositRewards_DuringActivePeriod() public {
        uint256 initialAmount = 700 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, initialAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 additional = 300 * SCALE;
        uint256 remainingTime = DURATION - 1 days;
        uint256 remainingRewards = staking.rate(rewardTokenAddr) * remainingTime;
        uint256 newRate = (remainingRewards + additional) / DURATION;

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, additional);

        assertEq(staking.rate(rewardTokenAddr), newRate);
        assertEq(staking.periodFinish(rewardTokenAddr), block.timestamp + DURATION);
    }

    function testFuzz_DepositRewards(uint256 amount) public {
        vm.assume(amount > SCALE && amount <= MINT_AMOUNT);

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, amount);

        assertEq(staking.rate(rewardTokenAddr), amount / DURATION);
        assertEq(staking.periodFinish(rewardTokenAddr), block.timestamp + DURATION);
    }

    // -------------------------------------------------------------------------
    // Test - Set Duration

    function test_SetDuration_UpdatesDuration() public {
        uint256 newDuration = 14 days;

        vm.expectEmit(true, false, false, true, stakingAddr);
        emit DurationUpdate(rewardTokenAddr, newDuration);

        vm.prank(OWNER);
        staking.setDuration(rewardTokenAddr, newDuration);

        assertEq(staking.duration(rewardTokenAddr), newDuration);
    }

    function test_SetDuration_RevertsDuringActivePeriod() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__GtFailed.selector);
        staking.setDuration(rewardTokenAddr, 14 days);
    }

    function test_SetDuration_RevertsOnZero() public {
        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.setDuration(rewardTokenAddr, 0);
    }

    function test_SetDuration_RevertsNonOwner() public {
        vm.prank(ALICE);
        vm.expectRevert();
        staking.setDuration(rewardTokenAddr, 14 days);
    }

    // -------------------------------------------------------------------------
    // Test - Reward Accrual and Claim

    function test_PendingRewards_AccruesCorrectly() public {
        uint256 deposit = 700 * SCALE;
        uint256 stake = 100 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, deposit);

        vm.prank(ALICE);
        staking.stake(stake);

        vm.warp(block.timestamp + 1 days);

        uint256 expectedPending = (staking.rate(rewardTokenAddr) * 1 days * stake) / stake;
        assertEq(staking.pendingRewards(ALICE, rewardTokenAddr), expectedPending);

        vm.prank(BOB);
        staking.stake(stake);

        vm.warp(block.timestamp + 1 days);

        // For Alice: previous + share of next day.
        uint256 secondDayEarned = (staking.rate(rewardTokenAddr) * 1 days * stake) / (stake * 2);
        assertEq(staking.pendingRewards(ALICE, rewardTokenAddr), expectedPending + secondDayEarned);

        // For Bob: share of day two.
        assertEq(staking.pendingRewards(BOB, rewardTokenAddr), secondDayEarned);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.warp(block.timestamp + DURATION);

        uint256 pending = staking.pendingRewards(ALICE, rewardTokenAddr);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, true, false, true, stakingAddr);
        emit ClaimRewards(ALICE, rewardTokenAddr, pending);

        vm.prank(ALICE);
        staking.claimRewards();

        assertEq(rewardToken.balanceOf(ALICE), pending);
        assertEq(staking.pendingRewards(ALICE, rewardTokenAddr), 0);
        assertEq(staking.userIndex(ALICE, rewardTokenAddr), staking.index(rewardTokenAddr));
    }

    function test_ClaimRewards_Single_TransfersAndResetsPending() public {
        uint256 rewardAmount = (700 * SCALE) / DURATION * DURATION;
        uint256 stakeAmount = 100 * SCALE;

        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.warp(block.timestamp + DURATION);

        uint256 pending = staking.pendingRewards(ALICE, rewardTokenAddr);
        assertEq(pending, rewardAmount);

        vm.expectEmit(true, true, false, true, stakingAddr);
        emit ClaimRewards(ALICE, rewardTokenAddr, pending);

        vm.prank(ALICE);
        staking.claimRewards(rewardTokenAddr);

        assertEq(rewardToken.balanceOf(ALICE), pending);
        assertEq(staking.pendingRewards(ALICE, rewardTokenAddr), 0);
        assertEq(staking.userIndex(ALICE, rewardTokenAddr), staking.index(rewardTokenAddr));
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
        staking.depositRewards(rewardTokenAddr, rewardAmount);

        vm.prank(ALICE);
        staking.stake(stake1);

        vm.prank(BOB);
        staking.stake(stake2);

        vm.warp(block.timestamp + time);

        uint256 totalStaked = stake1 + stake2;
        uint256 expectedTotalRewards = staking.rate(rewardTokenAddr) * time;
        uint256 pending1 = expectedTotalRewards * stake1 / totalStaked;
        uint256 pending2 = expectedTotalRewards * stake2 / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(ALICE, rewardTokenAddr), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(BOB, rewardTokenAddr), pending2, 1000);
    }

    // -------------------------------------------------------------------------
    // Test - Fee on Transfer

    function test_RejectsFeeOnTransfer() public {
        uint256 rewardAmount = 100 * SCALE;

        MockFeeToken feeToken = new MockFeeToken(OWNER, 1000);
        feeToken.mint(OWNER, MINT_AMOUNT);

        StakingRewardsMulti c = new StakingRewardsMulti(OWNER, stakingTokenAddr);

        address feeTokenAddr = address(feeToken);
        vm.prank(OWNER);
        c.addReward(feeTokenAddr, DURATION);

        vm.prank(OWNER);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(OWNER);
        c.depositRewards(feeTokenAddr, rewardAmount);
    }

    // -------------------------------------------------------------------------
    // Test - Views

    function test_LastTimeRewardApplicable() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), block.timestamp);

        vm.warp(block.timestamp + DURATION / 2);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), block.timestamp);

        vm.warp(block.timestamp + DURATION);
        assertEq(staking.lastTimeRewardApplicable(rewardTokenAddr), staking.periodFinish(rewardTokenAddr));
    }

    function test_CurrentIndex() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        uint256 stakeAmount = 100 * SCALE;
        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.warp(block.timestamp + 1 days);

        uint256 dt = 1 days;
        uint256 expectedIndex = (staking.rate(rewardTokenAddr) * dt * SCALE) / stakeAmount;
        assertEq(staking.currentIndex(rewardTokenAddr), expectedIndex);
    }

    function test_RewardPeriodActive() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Immediately after deposit: should be active.
        assertTrue(staking.periodRewardActive(rewardTokenAddr));

        // Halfway through: still active.
        vm.warp(block.timestamp + staking.duration(rewardTokenAddr) / 2);
        assertTrue(staking.periodRewardActive(rewardTokenAddr));

        // After finish: inactive.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertFalse(staking.periodRewardActive(rewardTokenAddr));
    }

    function test_CurrentIndex_ZeroSupply() public view {
        assertEq(staking.currentIndex(rewardTokenAddr), 0);
    }

    function test_PeriodRewardTotal() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        uint256 expected = staking.rate(rewardTokenAddr) * staking.duration(rewardTokenAddr);
        assertEq(staking.periodRewardTotal(rewardTokenAddr), expected);
    }

    function test_PeriodRewardRemaining() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Halfway through.
        vm.warp(block.timestamp + staking.duration(rewardTokenAddr) / 2);
        uint256 expected = staking.rate(rewardTokenAddr) * (staking.periodFinish(rewardTokenAddr) - block.timestamp);
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), expected);

        // After finish.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertEq(staking.periodRewardRemaining(rewardTokenAddr), 0);
    }

    function test_PeriodRewardEmitted() public {
        vm.prank(OWNER);
        staking.depositRewards(rewardTokenAddr, 700 * SCALE);

        // Initially none emitted.
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), 0);

        // Halfway through.
        vm.warp(block.timestamp + staking.duration(rewardTokenAddr) / 2);
        uint256 expected = staking.rate(rewardTokenAddr) * (staking.duration(rewardTokenAddr) / 2);
        assertEq(staking.periodRewardEmitted(rewardTokenAddr), expected);

        // After finish.
        vm.warp(staking.periodFinish(rewardTokenAddr) + 1);
        assertEq(
            staking.periodRewardEmitted(rewardTokenAddr),
            staking.rate(rewardTokenAddr) * staking.duration(rewardTokenAddr)
        );
    }
}
