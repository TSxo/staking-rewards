// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

library Assert {
    // -------------------------------------------------------------------------
    // Errors

    error Assert__Failed();
    error Assert__Zero();
    error Assert__ZeroAddress();
    error Assert__EqFailed();
    error Assert__NeFailed();
    error Assert__LtFailed();
    error Assert__GtFailed();
    error Assert__LteFailed();
    error Assert__GteFailed();

    // -------------------------------------------------------------------------
    // Constants

    bytes4 constant ERR_FAILED = 0x84fb93e9;
    bytes4 constant ERR_ZERO = 0x614f98b6;
    bytes4 constant ERR_ZERO_ADDRESS = 0x41cb54b9;
    bytes4 constant ERR_EQ_FAILED = 0x39e21750;
    bytes4 constant ERR_NE_FAILED = 0x900dd048;
    bytes4 constant ERR_LT_FAILED = 0x4cdb1dac;
    bytes4 constant ERR_GT_FAILED = 0x3ea263e9;
    bytes4 constant ERR_LTE_FAILED = 0x5b6ed52d;
    bytes4 constant ERR_GTE_FAILED = 0xcd53daf4;

    // -------------------------------------------------------------------------
    // Functions - General

    /// @notice Reverts if `x` is false.
    ///
    /// @param x The condition to test.
    function that(bool x) internal pure {
        assembly ("memory-safe") {
            if iszero(x) {
                mstore(0x00, ERR_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Address

    /// @notice Reverts if `x` is the zero address.
    ///
    /// @param x The address to test.
    function notZero(address x) internal pure {
        assembly ("memory-safe") {
            if iszero(shr(96, shl(96, x))) {
                mstore(0x00, ERR_ZERO_ADDRESS)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not equal to `y`.
    ///
    /// @param x The first address.
    /// @param y The second address.
    function eq(address x, address y) internal pure {
        assembly ("memory-safe") {
            if iszero(eq(shr(96, shl(96, x)), shr(96, shl(96, y)))) {
                mstore(0x00, ERR_EQ_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is equal to `y`.
    ///
    /// @param x The first address.
    /// @param y The second address.
    function ne(address x, address y) internal pure {
        assembly ("memory-safe") {
            if eq(shr(96, shl(96, x)), shr(96, shl(96, y))) {
                mstore(0x00, ERR_NE_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    // -------------------------------------------------------------------------
    // Functions - Uint256

    /// @notice Reverts if `x` is equal to zero.
    ///
    /// @param x The uint256 to test.
    function notZero(uint256 x) internal pure {
        assembly ("memory-safe") {
            if iszero(x) {
                mstore(0x00, ERR_ZERO)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not equal to `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function eq(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if iszero(eq(x, y)) {
                mstore(0x00, ERR_EQ_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is equal to `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function ne(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if eq(x, y) {
                mstore(0x00, ERR_NE_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not less than `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function lt(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if iszero(lt(x, y)) {
                mstore(0x00, ERR_LT_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not greater than `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function gt(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if iszero(gt(x, y)) {
                mstore(0x00, ERR_GT_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not less than, or equal to, `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function lte(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if gt(x, y) {
                mstore(0x00, ERR_LTE_FAILED)
                revert(0x00, 0x04)
            }
        }
    }

    /// @notice Reverts if `x` is not greater than, or equal to, `y`.
    ///
    /// @param x The first uint256 to test.
    /// @param y The second uint256 to test.
    function gte(uint256 x, uint256 y) internal pure {
        assembly ("memory-safe") {
            if lt(x, y) {
                mstore(0x00, ERR_GTE_FAILED)
                revert(0x00, 0x04)
            }
        }
    }
}
