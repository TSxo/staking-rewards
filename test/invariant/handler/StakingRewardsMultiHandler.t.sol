// SPDX-License-Identifier: MIT

pragma solidity 0.8.39;

import { HandlerBase } from "./HandlerBase.t.sol";
import { StakingRewardsMulti } from "src/staking-rewards-multi/StakingRewardsMulti.sol";
import { MockToken } from "test/mocks/MockToken.sol";

contract StakingRewardsMultiHandler is HandlerBase {
    // =========================================================================
    // State
    // =========================================================================

    StakingRewardsMulti private _staking;
    MockToken private _stakingToken;
    MockToken[] private _rewardTokens;

    mapping(address token => uint256) public ghost_prevIndex;
    mapping(address token => uint256) public ghost_prevCurrentIndex;
    mapping(address token => uint256) public ghost_totalRewardsDeposited;
    mapping(address token => uint256) public ghost_totalRewardsClaimed;

    // =========================================================================
    // Constructor
    // =========================================================================

    constructor(
        address owner,
        address[] memory actors,
        MockToken stakingToken,
        MockToken[] memory rewardTokens,
        StakingRewardsMulti staking
    ) {
        _initHandlerBase(owner, actors);

        _stakingToken = stakingToken;
        _rewardTokens = rewardTokens;
        _staking = staking;
    }

    // =========================================================================
    // Functions - Public
    // =========================================================================

    function stake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        amount = bound(amount, 1, MINT_AMOUNT);

        _stakingToken.mint(currentActor, amount);
        _stakingToken.approve(address(_staking), amount);

        _recordIndexes();
        _staking.stake(amount);
        _assertIndexMonotonicity();
    }

    function unstake(uint256 amount, uint256 actorSeed) public useActor(actorSeed) {
        uint256 balance = _staking.balanceOf(currentActor);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        _recordIndexes();
        _staking.unstake(amount);
        _assertIndexMonotonicity();
    }

    /// @dev Claims one reward token.
    function claimReward(uint256 tokenSeed, uint256 actorSeed) public useActor(actorSeed) {
        MockToken token = _token(tokenSeed);
        uint256 balBefore = token.balanceOf(currentActor);

        _recordIndexes();
        _staking.claimRewards(address(token));
        _assertIndexMonotonicity();

        ghost_totalRewardsClaimed[address(token)] += token.balanceOf(currentActor) - balBefore;
    }

    /// @dev Claims every reward token.
    function claimAllRewards(uint256 actorSeed) public useActor(actorSeed) {
        uint256[] memory balBefore = new uint256[](_rewardTokens.length);
        for (uint256 i; i < _rewardTokens.length; i++) {
            balBefore[i] = _rewardTokens[i].balanceOf(currentActor);
        }

        _recordIndexes();
        _staking.claimRewards();
        _assertIndexMonotonicity();

        for (uint256 i; i < _rewardTokens.length; i++) {
            MockToken token = _rewardTokens[i];
            ghost_totalRewardsClaimed[address(token)] += token.balanceOf(currentActor) - balBefore[i];
        }
    }

    function setDuration(uint256 tokenSeed, uint256 newDuration) public useOwner {
        MockToken token = _token(tokenSeed);
        if (vm.getBlockTimestamp() <= _staking.periodFinish(address(token))) return;

        newDuration = bound(newDuration, 1, 14 days);

        _recordIndexes();
        _staking.setDuration(address(token), newDuration);
        _assertIndexMonotonicity();
    }

    function depositRewards(uint256 tokenSeed, uint256 amount) public useOwner {
        MockToken token = _token(tokenSeed);
        amount = bound(amount, 10 * SCALE, MINT_AMOUNT);

        token.mint(_owner, amount);
        token.approve(address(_staking), amount);

        _recordIndexes();
        _staking.depositRewards(address(token), amount);
        _assertIndexMonotonicity();

        ghost_totalRewardsDeposited[address(token)] += amount;
    }

    // =========================================================================
    // Helper View Functions
    // =========================================================================

    function sumOfBalances() public view returns (uint256 sum) {
        for (uint256 i; i < _actors.length; i++) {
            sum += _staking.balanceOf(_actors[i]);
        }
    }

    function sumOfPendingRewards(address token) public view returns (uint256 sum) {
        for (uint256 i; i < _actors.length; i++) {
            sum += _staking.pendingRewards(_actors[i], token);
        }
    }

    // =========================================================================
    // Functions - Private
    // =========================================================================

    function _token(uint256 seed) private view returns (MockToken) {
        return _rewardTokens[bound(seed, 0, _rewardTokens.length - 1)];
    }

    function _recordIndexes() private {
        for (uint256 i; i < _rewardTokens.length; i++) {
            address token = address(_rewardTokens[i]);
            ghost_prevIndex[token] = _staking.index(token);
            ghost_prevCurrentIndex[token] = _staking.currentIndex(token);
        }
    }

    function _assertIndexMonotonicity() private view {
        for (uint256 i; i < _rewardTokens.length; i++) {
            address token = address(_rewardTokens[i]);
            assertGe(_staking.index(token), ghost_prevIndex[token]);
            assertGe(_staking.currentIndex(token), ghost_prevCurrentIndex[token]);
        }
    }
}
