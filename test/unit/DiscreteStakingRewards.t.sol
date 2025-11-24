// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { DiscreteStakingRewards } from "src/discrete-staking-rewards/DiscreteStakingRewards.sol";
import { Assert } from "src/utils/Assert.sol";

import { Base } from "test/Base.t.sol";
import { MockFeeToken } from "test/mocks/MockFeeToken.sol";

interface TestEvents {
    event Stake(address indexed user, uint256 amount);
    event Unstake(address indexed user, uint256 amount);
    event ClaimRewards(address indexed user, uint256 amount);
    event DepositRewards(uint256 amount);
}

contract DiscreteStakingRewardsTest is Base, TestEvents {
    // -------------------------------------------------------------------------
    // State

    DiscreteStakingRewards staking;
    address stakingAddr;

    // -------------------------------------------------------------------------
    // Setup

    function setUp() public {
        _initBase();

        staking = new DiscreteStakingRewards(owner, stakingTokenAddr, rewardTokenAddr);
        stakingAddr = address(staking);

        _dealTokens(stakingAddr);
    }

    // -------------------------------------------------------------------------
    // Test - Constructor

    function test_Constructor_InitializesCorrectly() public view {
        assertEq(staking.owner(), owner);
        assertEq(staking.stakingToken(), stakingTokenAddr);
        assertEq(staking.rewardToken(), rewardTokenAddr);
        assertEq(staking.index(), 0);
        assertEq(staking.totalSupply(), 0);
        assertEq(staking.rewardBalance(), 0);
    }

    function test_Constructor_RevertsOnZeroAddressStakingToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new DiscreteStakingRewards(owner, address(0), rewardTokenAddr);
    }

    function test_Constructor_RevertsOnZeroAddressRewardToken() public {
        vm.expectRevert(Assert.Assert__ZeroAddress.selector);
        new DiscreteStakingRewards(owner, stakingTokenAddr, address(0));
    }

    function test_Constructor_RevertsOnSameTokens() public {
        vm.expectRevert(Assert.Assert__NeFailed.selector);
        new DiscreteStakingRewards(owner, stakingTokenAddr, stakingTokenAddr);
    }

    // -------------------------------------------------------------------------
    // Test - Stake

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

    function test_Stake_RevertsOnZeroAmount() public {
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

    // -------------------------------------------------------------------------
    // Test - Unstake

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

    function test_Unstake_RevertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.unstake(0);
    }

    function test_Unstake_RevertsOnInsufficientBalance() public {
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

    // -------------------------------------------------------------------------
    // Test - Deposit Rewards

    function test_DepositRewards_UpdatesIndex() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.expectEmit(false, false, false, true, stakingAddr);
        emit DepositRewards(rewardAmount);

        vm.prank(owner);
        staking.depositRewards(rewardAmount);

        uint256 expectedIndex = (rewardAmount * SCALE) / stakeAmount;
        assertEq(staking.index(), expectedIndex);
        assertEq(rewardToken.balanceOf(stakingAddr), rewardAmount);
    }

    function test_DepositRewards_RevertsOnZero() public {
        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(0);
    }

    function test_DepositRewards_RevertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        staking.depositRewards(100 * SCALE);
    }

    function test_DepositRewards_RevertsOnZeroTotalSupply() public {
        uint256 amount = 700 * SCALE;

        vm.prank(owner);
        vm.expectRevert(Assert.Assert__Zero.selector);
        staking.depositRewards(amount);
    }

    function testFuzz_DepositRewards(uint256 stakeAmount, uint256 rewardAmount, uint256 actorSeed) public {
        stakeAmount = bound(stakeAmount, 1, MINT_AMOUNT);
        rewardAmount = bound(rewardAmount, 1, MINT_AMOUNT);

        address actor = _actor(actorSeed);

        vm.prank(actor);
        staking.stake(stakeAmount);

        vm.prank(owner);
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

        vm.prank(alice);
        staking.stake(stakeAlice);

        vm.prank(owner);
        staking.depositRewards(deposit / 2);

        uint256 expectedAlice1 = (deposit / 2 * stakeAlice) / stakeAlice;
        assertEq(staking.pendingRewards(alice), expectedAlice1);

        vm.prank(bob);
        staking.stake(stakeBob);

        vm.prank(owner);
        staking.depositRewards(deposit / 2);

        uint256 totalStaked = stakeAlice + stakeBob;
        uint256 secondDepositShareAlice = (deposit / 2 * stakeAlice) / totalStaked;
        uint256 secondDepositShareBob = (deposit / 2 * stakeBob) / totalStaked;

        assertEq(staking.pendingRewards(alice), expectedAlice1 + secondDepositShareAlice);
        assertEq(staking.pendingRewards(bob), secondDepositShareBob);
    }

    function test_ClaimRewards_TransfersAndResetsPending() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.prank(owner);
        staking.depositRewards(rewardAmount);

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

    function testFuzz_PendingRewards(uint256 stake1, uint256 stake2, uint256 rewardAmount) public {
        stake1 = bound(stake1, 1, 500 * SCALE);
        stake2 = bound(stake2, 1, 500 * SCALE);
        rewardAmount = bound(rewardAmount, 1, MINT_AMOUNT);

        vm.prank(alice);
        staking.stake(stake1);

        vm.prank(bob);
        staking.stake(stake2);

        vm.prank(owner);
        staking.depositRewards(rewardAmount);

        uint256 totalStaked = stake1 + stake2;
        uint256 pending1 = (rewardAmount * stake1) / totalStaked;
        uint256 pending2 = (rewardAmount * stake2) / totalStaked;

        assertApproxEqAbs(staking.pendingRewards(alice), pending1, 1000);
        assertApproxEqAbs(staking.pendingRewards(bob), pending2, 1000);
    }

    // -------------------------------------------------------------------------
    // Test - Fee on Transfer

    function test_RejectsFeeOnTransfer() public {
        uint256 rewardAmount = 100 * SCALE;

        MockFeeToken feeToken = new MockFeeToken(owner, 1000);
        feeToken.mint(owner, MINT_AMOUNT);

        DiscreteStakingRewards c = new DiscreteStakingRewards(owner, stakingTokenAddr, address(feeToken));

        vm.prank(alice);
        stakingToken.approve(address(c), MINT_AMOUNT);

        vm.prank(alice);
        c.stake(MINT_AMOUNT / 2);

        vm.prank(owner);
        feeToken.approve(address(c), rewardAmount);

        vm.expectRevert(Assert.Assert__EqFailed.selector);
        vm.prank(owner);
        c.depositRewards(rewardAmount);
    }

    // -------------------------------------------------------------------------
    // Test - Views

    function test_Index() public {
        uint256 stakeAmount = 100 * SCALE;
        uint256 rewardAmount = 700 * SCALE;

        vm.prank(alice);
        staking.stake(stakeAmount);

        vm.prank(owner);
        staking.depositRewards(rewardAmount);

        uint256 expectedIndex = (rewardAmount * SCALE) / stakeAmount;
        assertEq(staking.index(), expectedIndex);
    }

    function test_Index_ZeroSupply() public view {
        assertEq(staking.index(), 0);
    }
}
