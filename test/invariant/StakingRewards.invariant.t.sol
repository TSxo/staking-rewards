// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.30;

import { Base } from "test/Base.t.sol";
import { StakingRewards } from "src/staking-rewards/StakingRewards.sol";
import { StakingRewardsHandler } from "./handler/StakingRewardsHandler.t.sol";

contract StakingRewardsInvariantTest is Base {
    // -------------------------------------------------------------------------
    // Constants

    uint256 constant DURATION = 7 days;

    // -------------------------------------------------------------------------
    // State

    StakingRewards staking;
    address stakingAddr;
    StakingRewardsHandler handler;

    // -------------------------------------------------------------------------
    // Setup

    function setUp() public {
        _initBase();

        staking = new StakingRewards(owner, stakingTokenAddr, rewardTokenAddr, DURATION);
        stakingAddr = address(staking);
        handler = new StakingRewardsHandler(owner, actors, stakingToken, rewardToken, staking);

        targetContract(address(handler));
    }

    // -------------------------------------------------------------------------
    // Test - Invariants

    function invariant_SumOfBalancesEqualsTotalSupply() public view {
        uint256 sum = handler.sumOfBalances();
        assertEq(sum, staking.totalSupply());
    }

    function invariant_StakingTokenSolvency() public view {
        assertGe(stakingToken.balanceOf(stakingAddr), staking.totalSupply());
    }

    function invariant_UserBalanceNotGreaterThanTotalSupply() public view {
        for (uint256 i; i < actors.length; i++) {
            uint256 balance = staking.balanceOf(actors[i]);
            assertLe(balance, staking.totalSupply());
        }
    }

    function invariant_DistributedRewardsNotGreaterThanDeposited() public view {
        uint256 totalClaimed = handler.ghost_totalRewardsClaimed();
        uint256 totalPending = handler.sumOfPendingRewards();
        uint256 totalDistributed = totalClaimed + totalPending;
        uint256 totalDeposited = handler.ghost_totalRewardsDeposited();

        assertLe(totalDistributed, totalDeposited);
    }

    function invariant_IndexMonotonicallyIncreasing() public view {
        assertGe(staking.index(), handler.ghost_prevIndex());
    }

    function invariant_CurrentIndexGreaterOrEqualStoredIndex() public view {
        assertGe(staking.currentIndex(), staking.index());
    }

    function invariant_UserIndexNotGreaterThanGlobalIndex() public view {
        uint256 index = staking.index();
        uint256 currentIndex = staking.currentIndex();

        for (uint256 i; i < actors.length; i++) {
            uint256 userIdx = staking.userIndex(actors[i]);
            assertLe(userIdx, index);
            assertLe(userIdx, currentIndex);
        }
    }

    function invariant_LastUpdatedNotInFuture() public view {
        assertLe(staking.lastUpdated(), block.timestamp);
    }

    function invariant_LastUpdatedNotAfterPeriodFinish() public view {
        assertLe(staking.lastUpdated(), staking.periodFinish());
    }

    function invariant_LastTimeRewardApplicableValid() public view {
        uint256 lastTime = staking.lastTimeRewardApplicable();
        assertLe(lastTime, block.timestamp);
        assertLe(lastTime, staking.periodFinish());
    }

    function invariant_NoAccrualAfterPeriodFinish() public view {
        uint256 periodFinish = staking.periodFinish();
        if (block.timestamp > periodFinish) {
            assertEq(staking.lastTimeRewardApplicable(), periodFinish);
        }
    }

    function invariant_PeriodRewardTotalEqualsRateTimesDuration() public view {
        uint256 expected = staking.rate() * staking.duration();
        assertEq(staking.periodRewardTotal(), expected);
    }

    function invariant_DurationAlwaysNonZero() public view {
        assertGt(staking.duration(), 0);
    }

    function invariant_EmittedPlusRemainingEqualsTotal() public view {
        uint256 emitted = staking.periodRewardEmitted();
        uint256 remaining = staking.periodRewardRemaining();
        uint256 total = staking.periodRewardTotal();

        assertEq(emitted + remaining, total);
    }

    function invariant_SufficientRewardTokensForClaims() public view {
        uint256 totalPending = handler.sumOfPendingRewards();
        uint256 rewardBalance = rewardToken.balanceOf(stakingAddr);

        assertGe(rewardBalance, totalPending);
    }
}
