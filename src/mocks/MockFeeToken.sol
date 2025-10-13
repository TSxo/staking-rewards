// SPDX-License-Identifier: MIT

pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev A simple mock ERC20 fee-on-transfer token to be used only for testing.
contract MockFeeToken is ERC20 {
    uint256 constant BPS = 10_000;

    address public feeRecipient;
    uint256 public feeBps;

    constructor(address feeRecipient_, uint256 feeBps_) ERC20("MockFee", "FEE") {
        feeRecipient = feeRecipient_;
        feeBps = feeBps_;
    }

    function mint(address account, uint256 value) public {
        _mint(account, value);
    }

    function burn(address account, uint256 value) public {
        _burn(account, value);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        _handle(owner, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        address spender = _msgSender();

        _spendAllowance(from, spender, value);
        _handle(from, to, value);

        return true;
    }

    function transferFee(uint256 value) public view returns (uint256, uint256) {
        uint256 fee = (value * feeBps) / BPS;
        uint256 remaining = value - fee;

        return (fee, remaining);
    }

    function _handle(address from, address to, uint256 value) private {
        (uint256 fee, uint256 remaining) = transferFee(value);

        _transfer(from, feeRecipient, fee);
        _transfer(from, to, remaining);
    }
}
