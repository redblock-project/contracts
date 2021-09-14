// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RedblockSale is ReentrancyGuard, Ownable, ERC721Pausable {
    using Math for uint256;

    uint256 public constant MINT_PER_TRANSACTION = 5;
    uint256 public constant MINT_PER_ADDRESS = 5;

    string public baseTokenURI;

    uint256 public totalSupply;
    uint256 public currentlyMinted;

    uint256 public pricePerToken;

    mapping(address => uint256) public mintedPerAddress;

    event Minted(uint256 tokenId);
    event Withdrawn(uint256 amount);

    constructor() ReentrancyGuard() Ownable() ERC721("Redblock", "RB") {
        totalSupply = 9921;
        currentlyMinted = 0;

        pricePerToken = 5 * 10**16; // 0.05 ether
    }

    function setBaseTokenURI(string calldata URI) external onlyOwner {
        baseTokenURI = URI;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 toWithdraw = address(this).balance;

        payable(owner()).transfer(toWithdraw);

        emit Withdrawn(toWithdraw);
    }

    function mint(uint256 amount) external payable nonReentrant {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        uint256 mintForSender = Math.min(
            amount,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        require(mintForSender > 0, "RedblockSale: minter is too greedy");

        uint256 howManyToMint = Math.min(mintForSender, totalSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockSale: everything is minted");

        uint256 mintPrice = pricePerToken * howManyToMint;

        require(msg.value >= mintPrice, "RedblockSale: not enough ether supplied");

        for (uint256 i = 0; i < howManyToMint; i++) {
            currentlyMinted++;
            mintedPerAddress[_msgSender()]++;

            _safeMint(_msgSender(), currentlyMinted);

            emit Minted(currentlyMinted);
        }

        payable(msg.sender).transfer(msg.value - mintPrice);
    }

    function getMintPrice(uint256 amount) external view returns (uint256) {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        return pricePerToken * amount;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }
}
