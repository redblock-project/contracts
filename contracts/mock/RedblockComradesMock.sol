// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../RedblockComrades.sol";

contract RedblockComradesMock is RedblockComrades {
    constructor(
        address _whitelist,
        address _nctAddress,
        address _dustAddress,
        address _whaleAddress,
        address _nftBoxesAddress,
        address _artblocksAddress,
        uint256 _cappedSupply
    )
        RedblockComrades(
            _whitelist,
            _nctAddress,
            _dustAddress,
            _whaleAddress,
            _nftBoxesAddress,
            _artblocksAddress
        )
    {
        cappedSupply = _cappedSupply;
    }
}
