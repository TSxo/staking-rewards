// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { Assert } from "src/utils/Assert.sol";

contract AssertTest is Test {
    // -------------------------------------------------------------------------
    // Tests - General

    function test_That_PassesWhenTrue() public pure {
        Assert.that(true);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_That_RevertsWhenFalse() public {
        vm.expectRevert(Assert.ERR_FAILED);
        Assert.that(false);
    }

    // -------------------------------------------------------------------------
    // Tests - Address

    function test_Address_NotZero_PassesWhenNonZero() public pure {
        Assert.notZero(address(1));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Address_NotZero_RevertsWhenZero() public {
        vm.expectRevert(Assert.ERR_ZERO_ADDRESS);
        Assert.notZero(address(0));
    }

    function test_Address_Eq_PassesWhenEqual() public pure {
        address a = address(1);
        Assert.eq(a, a);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Address_Eq_RevertsWhenNotEqual() public {
        vm.expectRevert(Assert.ERR_EQ_FAILED);
        Assert.eq(address(1), address(2));
    }

    function test_Address_Ne_PassesWhenNotEqual() public pure {
        Assert.ne(address(1), address(2));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Address_Ne_RevertsWhenEqual() public {
        address a = address(1);
        vm.expectRevert(Assert.ERR_NE_FAILED);
        Assert.ne(a, a);
    }

    // -------------------------------------------------------------------------
    // Tests - Uint256

    function test_Uint_NotZero_PassesWhenNonZero() public pure {
        Assert.notZero(uint256(1));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_NotZero_RevertsWhenZero() public {
        vm.expectRevert(Assert.ERR_ZERO);
        Assert.notZero(uint256(0));
    }

    function test_Uint_Eq_PassesWhenEqual() public pure {
        uint256 a = 42;
        Assert.eq(a, a);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Eq_RevertsWhenNotEqual() public {
        vm.expectRevert(Assert.ERR_EQ_FAILED);
        Assert.eq(uint256(1), uint256(2));
    }

    function test_Uint_Ne_PassesWhenNotEqual() public pure {
        Assert.ne(uint256(1), uint256(2));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Ne_RevertsWhenEqual() public {
        uint256 a = 42;
        vm.expectRevert(Assert.ERR_NE_FAILED);
        Assert.ne(a, a);
    }

    function test_Uint_Lt_PassesWhenLessThan() public pure {
        Assert.lt(uint256(1), uint256(2));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Lt_RevertsWhenNotLessThan() public {
        vm.expectRevert(Assert.ERR_LT_FAILED);
        Assert.lt(uint256(2), uint256(1));

        vm.expectRevert(Assert.ERR_LT_FAILED);
        Assert.lt(uint256(1), uint256(1));
    }

    function test_Uint_Gt_PassesWhenGreaterThan() public pure {
        Assert.gt(uint256(2), uint256(1));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Gt_RevertsWhenNotGreaterThan() public {
        vm.expectRevert(Assert.ERR_GT_FAILED);
        Assert.gt(uint256(1), uint256(2));

        vm.expectRevert(Assert.ERR_GT_FAILED);
        Assert.gt(uint256(1), uint256(1));
    }

    function test_Uint_Lte_PassesWhenLessThanOrEqual() public pure {
        Assert.lte(uint256(1), uint256(2));
        Assert.lte(uint256(1), uint256(1));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Lte_RevertsWhenGreaterThan() public {
        vm.expectRevert(Assert.ERR_LTE_FAILED);
        Assert.lte(uint256(2), uint256(1));
    }

    function test_Uint_Gte_PassesWhenGreaterThanOrEqual() public pure {
        Assert.gte(uint256(2), uint256(1));
        Assert.gte(uint256(1), uint256(1));
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_Uint_Gte_RevertsWhenLessThan() public {
        vm.expectRevert(Assert.ERR_GTE_FAILED);
        Assert.gte(uint256(1), uint256(2));
    }
}
