// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { Base } from "test/Base.t.sol";
import { DiscreteStakingRewards } from "src/discrete-staking-rewards/DiscreteStakingRewards.sol";
import { DiscreteStakingRewardsHandler } from "./handler/DiscreteStakingRewardsHandler.t.sol";

contract DiscreteStakingRewardsInvariantTest is Base {
    // =========================================================================
    // State
    // =========================================================================

    DiscreteStakingRewards staking;
    address stakingAddr;
    DiscreteStakingRewardsHandler handler;

    // =========================================================================
    // Setup
    // =========================================================================

    function setUp() public {
        _initBase();

        staking = new DiscreteStakingRewards(owner, stakingTokenAddr, rewardTokenAddr);
        stakingAddr = address(staking);
        handler = new DiscreteStakingRewardsHandler(owner, actors, stakingToken, rewardToken, staking);

        targetContract(address(handler));
    }

    // =========================================================================
    // Test - Invariants
    // =========================================================================

    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        assertEq(handler.sumOfBalances(), staking.totalSupply());
    }

    function invariant_StakingTokenSolvency() public view {
        assertGe(stakingToken.balanceOf(stakingAddr), staking.totalSupply());
    }

    function invariant_IndexMonotonicallyIncreasing() public view {
        assertGe(staking.index(), handler.ghost_prevIndex());
    }

    function invariant_UserIndexNotGreaterThanGlobalIndex() public view {
        for (uint256 i; i < actors.length; i++) {
            assertLe(staking.userIndex(actors[i]), staking.index());
        }
    }

    function invariant_SufficientRewardTokensForClaims() public view {
        assertGe(rewardToken.balanceOf(stakingAddr), handler.sumOfPendingRewards());
    }

    function invariant_DistributedRewardsNotGreaterThanDeposited() public view {
        uint256 distributed = handler.ghost_totalRewardsClaimed() + handler.sumOfPendingRewards();
        assertLe(distributed, handler.ghost_totalRewardsDeposited());
    }

    /// @dev Rounding always favors the contract, and what it keeps stays
    /// within the bound the handler tracks: dust, never a meaningful amount.
    function invariant_RoundingDustBounded() public view {
        uint256 distributed = handler.ghost_totalRewardsClaimed() + handler.sumOfPendingRewards();
        uint256 dust = handler.ghost_totalRewardsDeposited() - distributed;

        // Each actor's pending view floors once more.
        assertLe(dust, handler.ghost_dustBound() + actors.length);
    }
}
