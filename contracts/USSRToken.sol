// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract USSRToken is IERC721Receiver, Ownable, ERC20 {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant PRECISION = 10**25;
    uint256 public constant POOL_MINT = 1_000_000 * 10**18;
    uint256 public constant EMISSION_DURATION = 6450 * 365 * 5; // ~5 years

    IERC721Enumerable public redblockComrades;

    uint256 public emissionStartBlock;

    uint256 public rewardPerBlock;
    uint256 public lastUpdateBlock;

    uint256 public cumulativeSum; // with precision
    uint256 public rewardRatio; // with precision

    EnumerableSet.UintSet internal _kolhozNFTs;
    mapping(address => EnumerableSet.UintSet) internal _kolhozUserNFTs;

    mapping(uint256 => uint256) public kolhozInfos; // NFT id => cumulative sum

    constructor(address redblockComradesAddress) Ownable() ERC20("Redblock Token", "U$$R") {
        redblockComrades = IERC721Enumerable(redblockComradesAddress);

        _mint(owner(), POOL_MINT);
    }

    function setEmissionStartBlock(uint256 startBlock) external onlyOwner {
        emissionStartBlock = startBlock;
    }

    function setRewardPerBlock(uint256 reward) external onlyOwner {
        _updateCumulativeSum();

        rewardPerBlock = reward;

        rewardRatio = (reward * PRECISION) / _kolhozNFTs.length();
    }

    function sendToKolhoz(uint256[] calldata tokenIds) external {
        _updateCumulativeSum();

        IERC721Enumerable _redblockComrades = redblockComrades;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(
                _redblockComrades.ownerOf(tokenId) == _msgSender(),
                "USSRToken: not an NFT owner"
            );

            _redblockComrades.safeTransferFrom(_msgSender(), address(this), tokenId);

            _kolhozUserNFTs[_msgSender()].add(tokenId);
            _kolhozNFTs.add(tokenId);

            kolhozInfos[tokenId] = cumulativeSum;
        }

        _updateRewardRatio();
    }

    function harvest() external {
        _updateCumulativeSum();

        EnumerableSet.UintSet storage userNFTs = _kolhozUserNFTs[_msgSender()];

        uint256 length = userNFTs.length();
        uint256 tokensToHarvest;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = userNFTs.at(i);

            tokensToHarvest += (cumulativeSum - kolhozInfos[tokenId]) / PRECISION;

            kolhozInfos[tokenId] = cumulativeSum;
        }

        require(tokensToHarvest > 0, "USSRToken: nothing to harvest");

        _mint(_msgSender(), tokensToHarvest);
    }

    function returnFromKolhoz(uint256[] calldata tokenIds) external {
        _updateCumulativeSum();

        IERC721Enumerable _redblockComrades = redblockComrades;
        EnumerableSet.UintSet storage userNFTs = _kolhozUserNFTs[_msgSender()];

        uint256 tokensToHarvest;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(userNFTs.contains(tokenId), "USSRToken: NFT doesn't belong to msg.sender");

            _redblockComrades.safeTransferFrom(address(this), _msgSender(), tokenId);

            tokensToHarvest += (cumulativeSum - kolhozInfos[tokenId]) / PRECISION;

            delete kolhozInfos[tokenId];
            userNFTs.remove(tokenId);
            _kolhozNFTs.remove(tokenId);
        }

        require(tokensToHarvest > 0, "USSRToken: nothing to harvest");

        _mint(_msgSender(), tokensToHarvest);

        _updateRewardRatio();
    }

    function getKolhozTokensCount(address user) external view returns (uint256) {
        return _kolhozUserNFTs[user].length();
    }

    function getKolhozTokens(address user) external view returns (uint256[] memory tokens) {
        tokens = _kolhozUserNFTs[user].values();
    }

    function getYield(address user) external view returns (uint256) {
        (uint256 newCumulativeSum, ) = _getNewCumulativeSum();

        EnumerableSet.UintSet storage userNFTs = _kolhozUserNFTs[user];

        uint256 length = userNFTs.length();
        uint256 tokensToHarvest;

        for (uint256 i = 0; i < length; i++) {
            tokensToHarvest += (newCumulativeSum - kolhozInfos[userNFTs.at(i)]) / PRECISION;
        }

        return tokensToHarvest;
    }

    function _updateCumulativeSum() internal {
        (cumulativeSum, lastUpdateBlock) = _getNewCumulativeSum();
    }

    function _getNewCumulativeSum()
        internal
        view
        returns (uint256 newCumulativeSum, uint256 newUpdate)
    {
        uint256 emissionStart = emissionStartBlock;

        newCumulativeSum = cumulativeSum;
        newUpdate = lastUpdateBlock;

        if (block.number >= emissionStart) {
            uint256 lastUpdate = emissionStart.max(lastUpdateBlock);
            newUpdate = block.number.min(emissionStart + EMISSION_DURATION);

            newCumulativeSum += rewardRatio * (newUpdate - lastUpdate);
        }
    }

    function _updateRewardRatio() internal {
        rewardRatio = (rewardPerBlock * PRECISION) / _kolhozNFTs.length();
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
