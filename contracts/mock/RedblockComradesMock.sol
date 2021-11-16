// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../RedblockComrades.sol";

contract RedblockComradesMock is RedblockComrades {
    constructor(
        address[] memory _whitelistCollections,
        address[] memory _tokenAddresses,
        address[] memory _nftAddresses,
        uint256 _cappedSupply
    ) RedblockComrades(_whitelistCollections, _tokenAddresses, _nftAddresses) {
        cappedSupply = _cappedSupply;
    }
}
