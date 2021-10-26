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

    uint256 public totalKolhozNFTs;
    mapping(address => EnumerableSet.UintSet) internal _kolhozUserNFTs;

    struct KolhozInfo {
        uint256 cumulativeReward;
        uint256 cumulativeSum;
    }

    mapping(address => KolhozInfo) public kolhozInfos; // user => kolhoz info

    constructor(address redblockComradesAddress) Ownable() ERC20("Redblock Token", "U$$R") {
        redblockComrades = IERC721Enumerable(redblockComradesAddress);

        _mint(owner(), POOL_MINT);
    }

    function setEmissionStartBlock(uint256 startBlock) external onlyOwner {
        emissionStartBlock = startBlock;
    }

    function setRewardPerBlock(uint256 reward) external onlyOwner {
        _updateCumulativeSum(address(0));

        rewardPerBlock = reward;

        _updateRewardRatio();
    }

    function sendToKolhoz(uint256[] calldata tokenIds) external {
        _updateCumulativeSum(_msgSender());

        IERC721Enumerable _redblockComrades = redblockComrades;
        EnumerableSet.UintSet storage userNFTs = _kolhozUserNFTs[_msgSender()];

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(
                _redblockComrades.ownerOf(tokenId) == _msgSender(),
                "USSRToken: not an NFT owner"
            );

            _redblockComrades.safeTransferFrom(_msgSender(), address(this), tokenId);

            userNFTs.add(tokenId);
        }

        totalKolhozNFTs += tokenIds.length;

        _updateRewardRatio();
    }

    function harvest() public {
        _updateCumulativeSum(_msgSender());

        uint256 tokensToHarvest = kolhozInfos[_msgSender()].cumulativeReward;

        require(tokensToHarvest > 0, "USSRToken: nothing to harvest");

        delete kolhozInfos[_msgSender()].cumulativeReward;

        _mint(_msgSender(), tokensToHarvest);
    }

    function returnFromKolhoz(uint256[] memory tokenIds) public {
        _updateCumulativeSum(_msgSender());

        IERC721Enumerable _redblockComrades = redblockComrades;
        EnumerableSet.UintSet storage userNFTs = _kolhozUserNFTs[_msgSender()];

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            require(userNFTs.contains(tokenId), "USSRToken: NFT doesn't belong to msg.sender");

            _redblockComrades.safeTransferFrom(address(this), _msgSender(), tokenId);

            userNFTs.remove(tokenId);
        }

        totalKolhozNFTs -= tokenIds.length;

        _updateRewardRatio();
    }

    function harvestAndReturnAll() external {
        harvest();
        returnFromKolhoz(_kolhozUserNFTs[_msgSender()].values());
    }

    function getKolhozTokensCount(address user) external view returns (uint256) {
        return _kolhozUserNFTs[user].length();
    }

    function getKolhozTokens(address user) external view returns (uint256[] memory tokens) {
        tokens = _kolhozUserNFTs[user].values();
    }

    function getYield(address user) external view returns (uint256) {
        (uint256 newCumulativeSum, ) = _getNewCumulativeSum();

        return
            _getNewTokensToHarvest(newCumulativeSum, user) +
            kolhozInfos[_msgSender()].cumulativeReward;
    }

    function _updateCumulativeSum(address user) internal {
        (cumulativeSum, lastUpdateBlock) = _getNewCumulativeSum();

        if (user != address(0)) {
            uint256 tokensToHarvest = _getNewTokensToHarvest(cumulativeSum, user);

            kolhozInfos[user].cumulativeReward += tokensToHarvest;
            kolhozInfos[user].cumulativeSum = cumulativeSum;
        }
    }

    function _getNewTokensToHarvest(uint256 newCumulativeSum, address user)
        internal
        view
        returns (uint256)
    {
        return
            ((newCumulativeSum - kolhozInfos[user].cumulativeSum) *
                _kolhozUserNFTs[user].length()) / PRECISION;
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
        uint256 total = totalKolhozNFTs;

        if (total > 0) {
            rewardRatio = (rewardPerBlock * PRECISION) / total;
        } else {
            rewardRatio = 0;
        }
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
