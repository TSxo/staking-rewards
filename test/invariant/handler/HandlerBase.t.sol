// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";

contract HandlerBase is Test {
    // -------------------------------------------------------------------------
    // Constants

    uint256 constant SCALE = 1e18;
    uint256 constant MINT_AMOUNT = 1_000 * SCALE;

    // -------------------------------------------------------------------------
    // State

    address internal _owner;
    address[] internal _actors;
    address public currentActor;

    // -------------------------------------------------------------------------
    // Modifiers

    /// @dev Executes the function as an actor derived from `actorSeed`.
    modifier useActor(uint256 actorSeed) {
        actorSeed = bound(actorSeed, 0, _actors.length - 1);
        currentActor = _actors[actorSeed];

        vm.startPrank(currentActor);
        _;
        vm.stopPrank();

        currentActor = address(0);
    }

    /// @dev Executes the function as the contract owner.
    modifier useOwner() {
        vm.startPrank(_owner);
        _;
        vm.stopPrank();
    }

    // -------------------------------------------------------------------------
    // Initialize

    /// @dev Initializes this base handler contract.
    function _initHandlerBase(address owner, address[] memory actors) internal {
        _owner = owner;
        _actors = actors;
    }
}

