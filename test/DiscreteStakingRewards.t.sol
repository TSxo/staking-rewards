// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

import { DiscreteStakingRewards } from "../src/discrete-staking-rewards/DiscreteStakingRewards.sol";

import { MockToken } from "../src/mocks/MockToken.sol";
import { MockFeeToken } from "../src/mocks/MockFeeToken.sol";
import { Assert } from "../src/utils/Assert.sol";

interface TestEvents {
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event DepositRewards(uint256 amount);
}

contract DiscreteStakingRewardsTest is Test, TestEvents {
    // -------------------------------------------------------------------------
    // Constants

    address constant OWNER = address(0x1234);
    address constant ALICE = address(0xA);
    address constant BOB = address(0xB);

    uint256 constant SCALE = 1e18;
    uint256 constant MINT_AMOUNT = 1000 * SCALE;

    // -------------------------------------------------------------------------
    // State

    DiscreteStakingRewards staking;
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

        staking = new DiscreteStakingRewards(OWNER, stakingTokenAddr, rewardTokenAddr);
        stakingAddr = address(staking);

        // Mint tokens.
        stakingToken.mint(ALICE, MINT_AMOUNT);
        stakingToken.mint(BOB, MINT_AMOUNT);
        rewardToken.mint(OWNER, MINT_AMOUNT);

        // Approve for users.
        vm.prank(ALICE);
        stakingToken.approve(stakingAddr, type(uint256).max);

        vm.prank(BOB);
        stakingToken.approve(stakingAddr, type(uint256).max);

        vm.prank(OWNER);
        rewardToken.approve(stakingAddr, type(uint256).max);
    }

    // -------------------------------------------------------------------------
    // Test - Constructor

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(staking.owner(), OWNER);
        assertEq(staking.stakingToken(), stakingTokenAddr);
        assertEq(staking.rewardToken(), rewardTokenAddr);
        assertEq(staking.index(), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(staking.rewardBalance(), 0);
    }

    function test_Constructor_RevertsOnZeroAddressStakingToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new DiscreteStakingRewards(OWNER, address(0), rewardTokenAddr);
    }

    function test_Constructor_RevertsOnZeroAddressRewardToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new DiscreteStakingRewards(OWNER, stakingTokenAddr, address(0));
    }

    function test_Constructor_RevertsOnSameTokens() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        new DiscreteStakingRewards(OWNER, stakingTokenAddr, stakingTokenAddr);
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

    function test_DepositRewards_UpdatesIndex() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DepositRewards(rewardAmount);

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        uint256 expectedIndex = (rewardAmount * SCALE) / stakeAmount;
        assertEq(staking.index(), expectedIndex);
        assertEq(rewardToken.balanceOf(stakingAddr), rewardAmount);
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

    function test_DepositRewards_RevertsOnZeroTotalSupply() public {
        uint256 amount = 700 * SCALE;

        vm.prank(OWNER);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(amount);
    }

    function testFuzz_DepositRewards(uint256 stakeAmount, uint256 rewardAmount) public {
        vm.assume(stakeAmount > 0 && stakeAmount <= MINT_AMOUNT);
        vm.assume(rewardAmount > 0 && rewardAmount <= MINT_AMOUNT);

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        uint256 expectedIndex = (rewardAmount * SCALE) / stakeAmount;
        assertEq(staking.index(), expectedIndex);
    }

    // -------------------------------------------------------------------------
    // Test - Reward Accrual and Claim

    function test_PendingRewards_AccruesCorrectly() public {
        uint256 stakeAlice = 100 * SCALE;
        uint256 stakeBob = 200 * SCALE;
        uint256 deposit = 600 * SCALE;

        vm.prank(ALICE);
        staking.stake(stakeAlice);

        vm.prank(OWNER);
        staking.depositRewards(deposit / 2);

        uint256 expectedAlice1 = (deposit / 2 * stakeAlice) / stakeAlice;
        assertEq(staking.pendingRewards(ALICE), expectedAlice1);

        vm.prank(BOB);
        staking.stake(stakeBob);

        vm.prank(OWNER);
        staking.depositRewards(deposit / 2);

        uint256 totalStaked = stakeAlice + stakeBob;
        uint256 secondDepositShareAlice = (deposit / 2 * stakeAlice) / totalStaked;
        uint256 secondDepositShareBob = (deposit / 2 * stakeBob) / totalStaked;

        assertEq(staking.pendingRewards(ALICE), expectedAlice1 + secondDepositShareAlice);
        assertEq(staking.pendingRewards(BOB), secondDepositShareBob);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

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

    function testFuzz_PendingRewards(uint256 stake1, uint256 stake2, uint256 rewardAmount) public {
        vm.assume(stake1 > 0 && stake1 <= 500 * SCALE);
        vm.assume(stake2 > 0 && stake2 <= 500 * SCALE);
        vm.assume(rewardAmount > 0 && rewardAmount <= MINT_AMOUNT);

        vm.prank(ALICE);
        staking.stake(stake1);

        vm.prank(BOB);
        staking.stake(stake2);

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        uint256 totalStaked = stake1 + stake2;
        uint256 pending1 = (rewardAmount * stake1) / totalStaked;
        uint256 pending2 = (rewardAmount * stake2) / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(ALICE), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(BOB), pending2, 1000);
    }

    // -------------------------------------------------------------------------
    // Test - Fee on Transfer

    function test_RejectsFeeOnTransfer() public {
        uint256 rewardAmount = 100 * SCALE;

        MockFeeToken feeToken = new MockFeeToken(OWNER, 1000);
        feeToken.mint(OWNER, MINT_AMOUNT);

        DiscreteStakingRewards c = new DiscreteStakingRewards(OWNER, stakingTokenAddr, address(feeToken));

        vm.prank(ALICE);
        stakingToken.approve(address(c), MINT_AMOUNT);

        vm.prank(ALICE);
        c.stake(MINT_AMOUNT / 2);

        vm.prank(OWNER);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(OWNER);
        c.depositRewards(rewardAmount);
    }

    // -------------------------------------------------------------------------
    // Test - Views

    function test_Index() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(ALICE);
        staking.stake(stakeAmount);

        vm.prank(OWNER);
        staking.depositRewards(rewardAmount);

        uint256 expectedIndex = (rewardAmount * SCALE) / stakeAmount;
        assertEq(staking.index(), expectedIndex);
    }

    function test_Index_ZeroSupply() public view {
        assertEq(staking.index(), 0);
    }
}
