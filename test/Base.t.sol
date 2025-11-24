// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { MockToken } from "test/mocks/MockToken.sol";

contract Base is Test {
    // -------------------------------------------------------------------------
    // Constants

    uint256 constant SCALE = 1e18;
    uint256 constant MINT_AMOUNT = 100_000 * SCALE;

    // -------------------------------------------------------------------------
    // State

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    address[] actors;

    MockToken stakingToken;
    MockToken rewardToken;

    address stakingTokenAddr;
    address rewardTokenAddr;

    // -------------------------------------------------------------------------
    // Initialize

    /// @dev Initializes this base test contract.
    function _initBase() internal {
        // Populate actors array.
        actors.push(alice);
        actors.push(bob);
        actors.push(charlie);

        // Deploy test tokens.
        stakingToken = new MockToken();
        rewardToken = new MockToken();

        stakingTokenAddr = address(stakingToken);
        rewardTokenAddr = address(rewardToken);
    }

    // -------------------------------------------------------------------------
    // Helper Functions

    /// @dev Mints reward tokens to owner, mints staking tokens to each actor,
    /// and grants the `stakingAddr` a maximum allowance over all tokens minted.
    function _dealTokens(address stakingAddr) internal {
        rewardToken.mint(owner, MINT_AMOUNT);
        vm.prank(owner);
        rewardToken.approve(stakingAddr, UINT256_MAX);

        for (uint256 i; i < actors.length; i++) {
            stakingToken.mint(actors[i], MINT_AMOUNT);

            vm.prank(actors[i]);
            stakingToken.approve(stakingAddr, UINT256_MAX);
        }
    }

    /// @dev Given a `seed`, returns an actor.
    function _actor(uint256 seed) internal view returns (address) {
        seed = bound(seed, 0, actors.length - 1);
        return actors[seed];
    }
}
