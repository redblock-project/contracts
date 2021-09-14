// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../RedblockSale.sol";

contract RedblockSaleMock is RedblockSale {
    constructor(uint256 _totalSupply) RedblockSale() {
        totalSupply = _totalSupply;
    }
}
