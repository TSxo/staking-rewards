// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Test } from "forge-std/Test.sol";

import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { StakingRewardsMulti } from "src/staking-rewards-multi/StakingRewardsMulti.sol";
import { MockToken } from "test/mocks/MockToken.sol";

/// @notice Differential test: `StakingRewardsMulti` configured with one reward
/// token behaves exactly like `StakingRewards`.
///
/// The fuzzer chooses a sequence of steps. Each step waits, then stakes,
/// unstakes, claims, deposits, or changes the duration, and is applied to
/// both contracts. Every call must have the same outcome, including the same
/// revert error, and every view must match afterwards. Inputs are bounded
/// loosely, so that reverting calls are compared too. The sequence starts from
/// a funded period with a payout already made (see `_seed`).
///
/// `forge equivalence` does not apply: it compares contracts with the same
/// interface, and these interfaces differ.
contract SingleVsMultiDifferentialTest is Test {
    enum Action {
        Stake,
        Unstake,
        Claim,
        DepositRewards,
        SetDuration
    }

    /// @dev One fuzzed step. `action` and `actor` are bounded to their ranges;
    /// `amount` is an amount or a duration, depending on the action.
    struct Step {
        uint8 action;
        uint8 actor;
        uint256 amount;
        uint32 wait;
    }

    uint256 constant DURATION = 7 days;
    uint256 constant STEPS = 16;
    uint256 constant MAX_AMOUNT = 1_000e18;

    address owner = makeAddr("owner");
    address[3] actors = [makeAddr("alice"), makeAddr("bob"), makeAddr("charlie")];

    // Each contract has its own tokens, so an actor's token balances show what
    // each contract paid them.
    MockToken singleStaking = new MockToken();
    MockToken singleReward = new MockToken();
    MockToken multiStaking = new MockToken();
    MockToken multiReward = new MockToken();

    StakingRewards single;
    StakingRewardsMulti multi;

    function setUp() public {
        single = new StakingRewards(owner, address(singleStaking), address(singleReward), DURATION);
        multi = new StakingRewardsMulti(owner, address(multiStaking));
        vm.prank(owner);
        multi.addReward(address(multiReward), DURATION);

        _seed();
    }

    /// @dev Puts both contracts in the same live state, with a payout already
    /// made, so the fuzzed steps cannot pass on matched reverts alone: alice
    /// stakes, a period is funded, a day passes, and alice claims.
    function _seed() internal {
        address alice = actors[0];

        _stake(alice, 100e18);
        _depositRewards(700e18);
        vm.warp(vm.getBlockTimestamp() + 1 days);
        _claim(alice);

        assertGt(singleReward.balanceOf(alice), 0, "seed paid out");
        assertEq(multiReward.balanceOf(alice), singleReward.balanceOf(alice), "seed payouts differ");

        _assertGlobalStateMatches();
        _assertPeriodViewsMatch();
        _assertUserStateMatches();
    }

    function testFuzz_AnySequence_MatchesSingle(Step[STEPS] calldata steps) public {
        for (uint256 i; i < STEPS; ++i) {
            Step calldata step = steps[i];
            vm.warp(vm.getBlockTimestamp() + bound(step.wait, 0, 14 days));

            Action action = Action(bound(step.action, 0, uint256(type(Action).max)));
            address actor = actors[bound(step.actor, 0, actors.length - 1)];

            if (action == Action.Stake) {
                _stake(actor, bound(step.amount, 0, MAX_AMOUNT));
            } else if (action == Action.Unstake) {
                _unstake(actor, step.amount);
            } else if (action == Action.Claim) {
                _claim(actor);
            } else if (action == Action.DepositRewards) {
                _depositRewards(bound(step.amount, 0, MAX_AMOUNT));
            } else {
                _setDuration(bound(step.amount, 0, 30 days));
            }

            _assertGlobalStateMatches();
            _assertPeriodViewsMatch();
            _assertUserStateMatches();
        }
    }

    // =========================================================================
    // Actions
    // =========================================================================

    function _stake(address actor, uint256 amount) internal {
        _fund(singleStaking, actor, address(single), amount);
        _fund(multiStaking, actor, address(multi), amount);

        _callBoth(actor, abi.encodeCall(single.stake, (amount)), abi.encodeCall(multi.stake, (amount)));
    }

    /// @dev Up to twice the balance, so that over-withdrawals are compared.
    function _unstake(address actor, uint256 seed) internal {
        uint256 amount = bound(seed, 0, 2 * single.balanceOf(actor));

        _callBoth(actor, abi.encodeCall(single.unstake, (amount)), abi.encodeCall(multi.unstake, (amount)));
    }

    function _claim(address actor) internal {
        _callBoth(
            actor,
            abi.encodeWithSignature("claimRewards()"),
            abi.encodeWithSignature("claimRewards(address)", multiReward)
        );
    }

    /// @dev From zero, so that deposits too small to set a rate are compared.
    function _depositRewards(uint256 amount) internal {
        _fund(singleReward, owner, address(single), amount);
        _fund(multiReward, owner, address(multi), amount);

        _callBoth(
            owner,
            abi.encodeCall(single.depositRewards, (amount)),
            abi.encodeCall(multi.depositRewards, (address(multiReward), amount))
        );
    }

    /// @dev From zero, and at any time, so that both rejections are compared.
    function _setDuration(uint256 newDuration) internal {
        _callBoth(
            owner,
            abi.encodeCall(single.setDuration, (newDuration)),
            abi.encodeCall(multi.setDuration, (address(multiReward), newDuration))
        );
    }

    // =========================================================================
    // Helpers
    // =========================================================================

    function _fund(MockToken token, address account, address spender, uint256 amount) internal {
        token.mint(account, amount);
        vm.prank(account);
        token.approve(spender, amount);
    }

    /// @dev Calls both contracts as `caller` and requires the same outcome:
    /// both succeed with the same return data, or both revert with the same
    /// error.
    function _callBoth(address caller, bytes memory singleCall, bytes memory multiCall) internal {
        vm.prank(caller);
        (bool singleOk, bytes memory singleData) = address(single).call(singleCall);

        vm.prank(caller);
        (bool multiOk, bytes memory multiData) = address(multi).call(multiCall);

        assertEq(multiOk, singleOk, "success differs");
        assertEq(multiData, singleData, "return or revert data differs");
    }

    function _assertGlobalStateMatches() internal view {
        address token = address(multiReward);

        assertEq(multi.totalSupply(), single.totalSupply(), "totalSupply");
        assertEq(multi.duration(token), single.duration(), "duration");
        assertEq(multi.rate(token), single.rate(), "rate");
        assertEq(multi.index(token), single.index(), "index");
        assertEq(multi.currentIndex(token), single.currentIndex(), "currentIndex");
        assertEq(multi.lastUpdated(token), single.lastUpdated(), "lastUpdated");
        assertEq(multi.lastTimeRewardApplicable(token), single.lastTimeRewardApplicable(), "lastTimeRewardApplicable");
        assertEq(multi.rewardBalance(token), single.rewardBalance(), "rewardBalance");
    }

    function _assertPeriodViewsMatch() internal view {
        address token = address(multiReward);

        assertEq(multi.periodStart(token), single.periodStart(), "periodStart");
        assertEq(multi.periodFinish(token), single.periodFinish(), "periodFinish");
        assertEq(multi.periodRewardActive(token), single.periodRewardActive(), "periodRewardActive");
        assertEq(multi.periodRewardTotal(token), single.periodRewardTotal(), "periodRewardTotal");
        assertEq(multi.periodRewardEmitted(token), single.periodRewardEmitted(), "periodRewardEmitted");
        assertEq(multi.periodRewardRemaining(token), single.periodRewardRemaining(), "periodRewardRemaining");
    }

    function _assertUserStateMatches() internal view {
        address token = address(multiReward);

        for (uint256 i; i < actors.length; i++) {
            address user = actors[i];
            assertEq(multi.balanceOf(user), single.balanceOf(user), "balanceOf");
            assertEq(multi.userIndex(user, token), single.userIndex(user), "userIndex");
            assertEq(multi.pendingRewards(user, token), single.pendingRewards(user), "pendingRewards");
            assertEq(multiReward.balanceOf(user), singleReward.balanceOf(user), "rewards paid");
            assertEq(multiStaking.balanceOf(user), singleStaking.balanceOf(user), "staking tokens held");
        }
    }
}
