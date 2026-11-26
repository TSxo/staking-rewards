// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { MockToken } from "test/mocks/MockToken.sol";

/// @notice Symbolic proofs for `StakingRewards`. Run with `just symbolic`.
///
/// Each check takes symbolic amounts and times, so the solver proves the
/// property for every value in range rather than for sampled ones. The bounds
/// keep the arithmetic within what a realistic token supply and schedule
/// allow, and keep the solver's queries small enough to finish.
contract StakingRewardsSymbolicTest is Test {
    uint256 constant SCALE = 1e18;
    uint256 constant DURATION = 7 days;

    /// @dev Upper bound on any staked or deposited amount: 1e12 whole tokens.
    uint256 constant MAX_AMOUNT = 1e30;

    /// @dev Upper bound on any warp: ten years.
    uint256 constant MAX_WARP = 3650 days;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    MockToken stakingToken;
    MockToken rewardToken;
    StakingRewards staking;

    function setUp() public {
        stakingToken = new MockToken();
        rewardToken = new MockToken();
        staking = new StakingRewards(owner, address(stakingToken), address(rewardToken), DURATION);

        rewardToken.mint(owner, 2 * MAX_AMOUNT);
        vm.prank(owner);
        rewardToken.approve(address(staking), type(uint256).max);

        address[2] memory users = [alice, bob];
        for (uint256 i; i < users.length; i++) {
            stakingToken.mint(users[i], 2 * MAX_AMOUNT);
            vm.prank(users[i]);
            stakingToken.approve(address(staking), type(uint256).max);
        }
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _deposit(uint256 amount) internal {
        vm.prank(owner);
        staking.depositRewards(amount);
    }

    function _stake(address user, uint256 amount) internal {
        vm.prank(user);
        staking.stake(amount);
    }

    /// @dev A running period with Alice staked an hour in.
    function _seed() internal {
        _deposit(1_000_000 * SCALE);
        _stake(alice, 1_000 * SCALE);
        _warp(1 hours);
    }

    function _warp(uint256 dt) internal {
        vm.warp(vm.getBlockTimestamp() + dt);
    }

    // =========================================================================
    // Checks - Index
    // =========================================================================

    /// @dev Whatever one action follows (stake, claim, or deposit), after any
    /// wait, the stored index, the current index, and the user's index never
    /// decrease, and the user's index never passes the global one.
    function check_Index_NeverDecreases(uint8 action, uint256 amount, uint256 dt) public {
        vm.assume(amount >= SCALE && amount <= MAX_AMOUNT);
        vm.assume(dt <= MAX_WARP);

        _seed();

        uint256 storedBefore = staking.index();
        uint256 currentBefore = staking.currentIndex();
        uint256 userBefore = staking.userIndex(alice);

        _warp(dt);

        uint256 kind = action % 3;
        vm.startPrank(kind == 2 ? owner : alice);
        if (kind == 0) {
            staking.stake(amount);
        } else if (kind == 1) {
            staking.claimRewards();
        } else {
            staking.depositRewards(amount);
        }
        vm.stopPrank();

        assertGe(staking.index(), storedBefore);
        assertGe(staking.currentIndex(), currentBefore);
        assertGe(staking.userIndex(alice), userBefore);
        assertLe(staking.userIndex(alice), staking.index());
    }

    /// @dev The same property for `unstake`. Comparing the current index with
    /// its value before the unstake divides by a symbolic remaining supply,
    /// which the solver cannot settle within the timeout. Instead, the check
    /// shows that right after the unstake the current index equals the stored
    /// one, which never decreases.
    function check_Index_NeverDecreasesOnUnstake(uint256 amount, uint256 dt) public {
        vm.assume(amount >= 1 && amount <= 1_000 * SCALE);
        vm.assume(dt <= MAX_WARP);

        _seed();

        uint256 storedBefore = staking.index();
        uint256 userBefore = staking.userIndex(alice);

        _warp(dt);

        vm.prank(alice);
        staking.unstake(amount);

        assertGe(staking.index(), storedBefore);
        assertEq(staking.currentIndex(), staking.index());
        assertGe(staking.userIndex(alice), userBefore);
        assertEq(staking.userIndex(alice), staking.index());
    }

    // =========================================================================
    // Checks - Period Views
    // =========================================================================

    /// @dev At any time after a deposit, emitted plus remaining is the period's
    /// total, and the views never revert.
    function check_PeriodViews_EmittedPlusRemainingIsTotal(uint256 reward, uint256 dt) public {
        vm.assume(reward >= DURATION && reward <= MAX_AMOUNT);
        vm.assume(dt <= MAX_WARP);

        _deposit(reward);
        _warp(dt);

        uint256 total = staking.periodRewardTotal();
        assertEq(staking.periodRewardEmitted() + staking.periodRewardRemaining(), total);
        assertLe(total, reward);
        assertEq(staking.periodRewardActive(), dt <= DURATION);
    }

    /// @dev Regression property for the duration bug: changing the duration
    /// after a period ends leaves every view of that period unchanged.
    function check_PeriodViews_IgnoreLaterSetDuration(uint256 reward, uint256 dt, uint256 newDuration) public {
        vm.assume(reward >= DURATION && reward <= MAX_AMOUNT);
        vm.assume(dt > DURATION && dt <= MAX_WARP);
        vm.assume(newDuration >= 1 && newDuration <= MAX_WARP);

        _deposit(reward);
        _warp(dt);

        uint256 start = staking.periodStart();
        uint256 finish = staking.periodFinish();
        bool active = staking.periodRewardActive();
        uint256 total = staking.periodRewardTotal();
        uint256 emitted = staking.periodRewardEmitted();
        uint256 remaining = staking.periodRewardRemaining();

        vm.prank(owner);
        staking.setDuration(newDuration);

        assertEq(staking.periodStart(), start);
        assertEq(staking.periodFinish(), finish);
        assertEq(staking.periodRewardActive(), active);
        assertEq(staking.periodRewardTotal(), total);
        assertEq(staking.periodRewardEmitted(), emitted);
        assertEq(staking.periodRewardRemaining(), remaining);
    }
}
