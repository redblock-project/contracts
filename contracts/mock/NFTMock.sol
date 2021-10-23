// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFTMock is ERC721Enumerable {
    uint256 public minted;

    constructor() ERC721("Mock", "Mock") {}

    function mint(address to, uint256 amount) external {
        for (uint256 i = 0; i < amount; i++) {
            _mint(to, minted + i + 1);
        }

        minted += amount;
    }
}
