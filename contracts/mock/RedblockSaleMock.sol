// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../RedblockSale.sol";

contract RedblockComradesMock is RedblockComrades {
    constructor(uint256 _cappedSupply) RedblockComrades() {
        cappedSupply = _cappedSupply;
    }
}
