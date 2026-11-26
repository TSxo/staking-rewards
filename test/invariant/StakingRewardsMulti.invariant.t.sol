// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Base } from "test/Base.t.sol";
import { StakingRewardsMulti } from "src/staking-rewards-multi/StakingRewardsMulti.sol";
import { MockToken } from "test/mocks/MockToken.sol";
import { StakingRewardsMultiHandler } from "./handler/StakingRewardsMultiHandler.t.sol";

/// @notice Invariants for `StakingRewardsMulti` with two reward tokens on
/// different durations. The single-token case is covered by the differential
/// campaign against `StakingRewards`; this suite checks that each token's
/// accounting holds on its own while the tokens share one staked supply.
contract StakingRewardsMultiInvariantTest is Base {
    // =========================================================================
    // State
    // =========================================================================

    StakingRewardsMulti staking;
    address stakingAddr;
    StakingRewardsMultiHandler handler;

    MockToken secondReward;
    address[] rewardTokens;

    // =========================================================================
    // Setup
    // =========================================================================

    function setUp() public {
        _initBase();
        secondReward = new MockToken();

        staking = new StakingRewardsMulti(owner, stakingTokenAddr);
        stakingAddr = address(staking);

        vm.startPrank(owner);
        staking.addReward(rewardTokenAddr, 7 days);
        staking.addReward(address(secondReward), 3 days);
        vm.stopPrank();

        MockToken[] memory tokens = new MockToken[](2);
        (tokens[0], tokens[1]) = (rewardToken, secondReward);
        rewardTokens.push(rewardTokenAddr);
        rewardTokens.push(address(secondReward));

        handler = new StakingRewardsMultiHandler(owner, actors, stakingToken, tokens, staking);
        targetContract(address(handler));
    }

    // =========================================================================
    // Test - Invariants (shared supply)
    // =========================================================================

    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        assertEq(handler.sumOfBalances(), staking.totalSupply());
    }

    function invariant_StakingTokenSolvency() public view {
        assertGe(stakingToken.balanceOf(stakingAddr), staking.totalSupply());
    }

    function invariant_RewardTokenListUnchanged() public view {
        assertEq(staking.rewardTokens(), rewardTokens);
    }

    // =========================================================================
    // Test - Invariants (per reward token)
    // =========================================================================

    function invariant_SufficientRewardTokensForClaims() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            assertGe(MockToken(token).balanceOf(stakingAddr), handler.sumOfPendingRewards(token));
        }
    }

    function invariant_DistributedRewardsNotGreaterThanDeposited() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            uint256 distributed = handler.ghost_totalRewardsClaimed(token) + handler.sumOfPendingRewards(token);
            assertLe(distributed, handler.ghost_totalRewardsDeposited(token));
        }
    }

    function invariant_IndexMonotonicallyIncreasing() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            assertGe(staking.index(token), handler.ghost_prevIndex(token));
            assertGe(staking.currentIndex(token), staking.index(token));
        }
    }

    function invariant_UserIndexNotGreaterThanGlobalIndex() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            for (uint256 i; i < actors.length; i++) {
                assertLe(staking.userIndex(actors[i], token), staking.index(token));
            }
        }
    }

    function invariant_TimestampsOrdered() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            uint256 finish = staking.periodFinish(token);

            assertLe(staking.periodStart(token), finish);
            assertLe(staking.lastUpdated(token), finish);
            assertLe(staking.lastUpdated(token), vm.getBlockTimestamp());
            assertLe(staking.lastTimeRewardApplicable(token), finish);
        }
    }

    function invariant_PeriodViewsConsistent() public view {
        for (uint256 t; t < rewardTokens.length; t++) {
            address token = rewardTokens[t];
            uint256 total = staking.periodRewardTotal(token);

            assertEq(staking.periodRewardEmitted(token) + staking.periodRewardRemaining(token), total);
            assertEq(total, staking.rate(token) * (staking.periodFinish(token) - staking.periodStart(token)));
        }
    }
}
