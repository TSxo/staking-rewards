// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { MockToken } from "test/mocks/MockToken.sol";

contract StakingRewardsIndexProof is Test {
    // -------------------------------------------------------------------------
    // Constants

    uint256 constant SCALE = 1e18;
    uint256 constant MINT_AMOUNT = 100_000 * SCALE;
    uint256 constant DURATION = 7 days;

    // -------------------------------------------------------------------------
    // State

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");

    StakingRewards staking;
    address stakingAddr;

    MockToken stakingToken;
    MockToken rewardToken;

    address stakingTokenAddr;
    address rewardTokenAddr;

    // -------------------------------------------------------------------------
    // Setup

    function setUp() public {
        stakingToken = new MockToken();
        rewardToken = new MockToken();

        stakingTokenAddr = address(stakingToken);
        rewardTokenAddr = address(rewardToken);

        staking = new StakingRewards(owner, stakingTokenAddr, rewardTokenAddr, DURATION);
        stakingAddr = address(staking);

        // To reduce the symbolic complexity and prevent HEVM from exhausting
        // its iteration limit, we mint tokens, deposit rewards, and perform an
        // initial stake here in the setup.
        rewardToken.mint(owner, 2 * MINT_AMOUNT);
        stakingToken.mint(alice, 2 * MINT_AMOUNT);

        vm.startPrank(owner);
        rewardToken.approve(stakingAddr, UINT256_MAX);
        staking.depositRewards(MINT_AMOUNT);
        vm.stopPrank();

        vm.startPrank(alice);
        stakingToken.approve(stakingAddr, UINT256_MAX);
        staking.stake(MINT_AMOUNT);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
    }

    // -------------------------------------------------------------------------
    // Proofs

    function prove_StoredIndexMonotonicity(uint256 amount) public {
        vm.assume(amount >= SCALE && amount <= MINT_AMOUNT);

        uint256 beforeIndex = staking.index();

        vm.prank(alice);
        staking.stake(amount);

        uint256 afterIndex = staking.index();
        assert(afterIndex >= beforeIndex);
    }

    function prove_CurrentIndexMonotonicity(uint256 amount) public {
        vm.assume(amount >= SCALE && amount <= MINT_AMOUNT);

        uint256 beforeIndex = staking.currentIndex();

        vm.prank(alice);
        staking.stake(amount);

        vm.warp(block.timestamp + 1 days);

        uint256 afterIndex = staking.currentIndex();
        assert(afterIndex >= beforeIndex);
    }

    function prove_UserIndexMonotonicity(uint256 amount) public {
        vm.assume(amount >= SCALE && amount <= MINT_AMOUNT);

        uint256 beforeIndex = staking.userIndex(alice);

        vm.prank(alice);
        staking.stake(amount);

        uint256 afterIndex = staking.userIndex(alice);
        assert(afterIndex >= beforeIndex);
    }
}
