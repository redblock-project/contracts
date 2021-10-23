// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./RedblockWhitelist.sol";

contract RedblockComrades is IERC721Receiver, ReentrancyGuard, Ownable, ERC721Enumerable {
    using Math for uint256;

    uint256 public constant MINT_PER_TRANSACTION = 5;
    uint256 public constant MINT_PER_ADDRESS = 5;
    uint256 public constant MINT_PER_OPTION = 100;

    RedblockWhitelist public whitelist;

    address public nctAddress; // 0x8A9c4dfe8b9D8962B31e4e16F8321C44d48e246E;
    address public dustAddress; // 0xe2E109f1b4eaA8915655fE8fDEfC112a34ACc5F0;
    address public whaleAddress; // 0x9355372396e3F6daF13359B7b607a3374cc638e0;

    address public nftBoxesAddress; // 0x6d4530149e5B4483d2F7E60449C02570531A0751;
    address public artblocksAddress; // 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;

    string public baseTokenURI;

    uint256 public cappedSupply = 9917;
    uint256 public currentlyMinted;

    uint256 public pricePerTokenETH = 5 * 10**16; // 0.05 ether
    uint256 public pricePerTokenNCT = 5000 * 10**18; // 5000 NCT
    uint256 public pricePerTokenDUST = 550 * 10**18; // 550 DUST
    uint256 public pricePerTokenWHALE = 11 * 10**4; // 11 WHALE

    uint256 public multiplierNFTBoxes = 1;
    uint256 public multiplierArtblocks = 3;

    mapping(address => uint256) public mintedPerAddress;
    mapping(address => uint256) public mintedPerOption;

    uint256 public whitelistEndBlock;
    bool public saleStopped;

    event MintedViaETH(uint256 tokenId);
    event MintedViaERC20(uint256 tokenId, address collateral);
    event MintedViaERC721(uint256 tokenId, address collateral);
    event WithdrawnETH(uint256 amount);
    event WithdrawnERC20(uint256 amount, address collateral);
    event WithdrawnERC721(uint256 tokenId, address collateral);

    modifier notStopped() {
        require(!saleStopped, "RedblockComrades: sale is stopped");
        _;
    }

    modifier whitelisted(address who) {
        require(
            whitelistEndBlock != 0 &&
                (whitelistEndBlock <= block.number || whitelist.isWhitelisted(who)),
            "RedblockComrades: not whitelisted"
        );
        _;
    }

    constructor(
        address _whitelistAddress,
        address _nctAddress,
        address _dustAddress,
        address _whaleAddress,
        address _nftBoxesAddress,
        address _artblocksAddress
    ) ReentrancyGuard() Ownable() ERC721("Redblock Comrades", "\xe2\x98\xad") {
        whitelist = RedblockWhitelist(_whitelistAddress);

        nctAddress = _nctAddress;
        dustAddress = _dustAddress;
        whaleAddress = _whaleAddress;
        nftBoxesAddress = _nftBoxesAddress;
        artblocksAddress = _artblocksAddress;

        saleStopped = true;
    }

    function triggerSale(bool option) external onlyOwner {
        saleStopped = !option;
    }

    function setWhitelistEndBlock(uint256 blockNum) external onlyOwner {
        whitelistEndBlock = blockNum;
    }

    function setBaseTokenURI(string calldata URI) external onlyOwner {
        baseTokenURI = URI;
    }

    function setArtblocksMultiplier(uint256 multiplier) external onlyOwner {
        multiplierArtblocks = multiplier;
    }

    function setNFTBoxesMultiplier(uint256 multiplier) external onlyOwner {
        multiplierNFTBoxes = multiplier;
    }

    function setPricePerTokenNCT(uint256 newPrice) external onlyOwner {
        pricePerTokenNCT = newPrice;
    }

    function setPricePerTokenDUST(uint256 newPrice) external onlyOwner {
        pricePerTokenDUST = newPrice;
    }

    function setPricePerTokenWHALE(uint256 newPrice) external onlyOwner {
        pricePerTokenWHALE = newPrice;
    }

    function setPricePerTokenETH(uint256 newPrice) external onlyOwner {
        pricePerTokenETH = newPrice;
    }

    function withdrawERC721(address collateralAddress, uint256 batch) external onlyOwner {
        IERC721Enumerable collateral = IERC721Enumerable(collateralAddress);
        int256 balance = int256(collateral.balanceOf(address(this)));

        /// @dev loop is reversed due to "swap and pop" thing
        for (int256 i = balance - 1; i >= balance - int256(batch); i--) {
            uint256 tokenId = collateral.tokenOfOwnerByIndex(address(this), uint256(i));
            collateral.safeTransferFrom(address(this), owner(), tokenId);

            emit WithdrawnERC721(tokenId, collateralAddress);
        }
    }

    function withdrawERC20(address collateralAddress) external onlyOwner {
        IERC20 collateral = IERC20(collateralAddress);
        uint256 toWithdraw = collateral.balanceOf(address(this));

        collateral.transfer(owner(), toWithdraw);

        emit WithdrawnERC20(toWithdraw, collateralAddress);
    }

    function withdrawETH() external onlyOwner {
        uint256 toWithdraw = address(this).balance;

        payable(owner()).transfer(toWithdraw);

        emit WithdrawnETH(toWithdraw);
    }

    function mintForArtblocks(uint256[] calldata tokenIds) external {
        _mintForERC721(tokenIds, artblocksAddress, multiplierArtblocks);
    }

    function mintForNFTBoxes(uint256[] calldata tokenIds) external {
        _mintForERC721(tokenIds, nftBoxesAddress, multiplierNFTBoxes);
    }

    function _mintForERC721(
        uint256[] memory tokenIds,
        address collateralAddress,
        uint256 multiplier
    ) internal notStopped nonReentrant whitelisted(_msgSender()) {
        uint256 mintedOverall;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 mintForSender = Math.min(
                multiplier,
                MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
            );

            uint256 mintForOption = Math.min(
                mintForSender,
                MINT_PER_OPTION - mintedPerOption[collateralAddress]
            );

            uint256 howManyToMint = Math.min(mintForOption, cappedSupply - currentlyMinted);

            if (howManyToMint == 0) {
                break;
            }

            mintedOverall += howManyToMint;

            IERC721(collateralAddress).safeTransferFrom(_msgSender(), address(this), tokenIds[i]);

            mintedPerAddress[_msgSender()] += howManyToMint;
            mintedPerOption[collateralAddress] += howManyToMint;

            for (uint256 j = 0; j < howManyToMint; j++) {
                _safeMint(_msgSender(), ++currentlyMinted);

                emit MintedViaERC721(currentlyMinted, collateralAddress);
            }
        }

        require(mintedOverall > 0, "RedblockComrades: can't mint that amount");
    }

    function mintForNCT(uint256 amount) external {
        _mintForERC20(amount, nctAddress, pricePerTokenNCT);
    }

    function mintForDUST(uint256 amount) external {
        _mintForERC20(amount, dustAddress, pricePerTokenDUST);
    }

    function mintForWHALE(uint256 amount) external {
        _mintForERC20(amount, whaleAddress, pricePerTokenWHALE);
    }

    function _mintForERC20(
        uint256 amount,
        address collateralAddress,
        uint256 pricePerToken
    ) internal notStopped nonReentrant whitelisted(_msgSender()) {
        require(amount > 0, "RedblockComrades: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockComrades: minting more than allowed");

        uint256 mintForSender = Math.min(
            amount,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        uint256 mintForOption = Math.min(
            mintForSender,
            MINT_PER_OPTION - mintedPerOption[collateralAddress]
        );

        uint256 howManyToMint = Math.min(mintForOption, cappedSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockComrades: can't mint that amount");

        uint256 mintPrice = pricePerToken * howManyToMint;

        IERC20(collateralAddress).transferFrom(_msgSender(), address(this), mintPrice);

        mintedPerAddress[_msgSender()] += howManyToMint;
        mintedPerOption[collateralAddress] += howManyToMint;

        for (uint256 i = 0; i < howManyToMint; i++) {
            _safeMint(_msgSender(), ++currentlyMinted);

            emit MintedViaERC20(currentlyMinted, collateralAddress);
        }
    }

    function mintForETH(uint256 amount)
        external
        payable
        notStopped
        nonReentrant
        whitelisted(_msgSender())
    {
        require(amount > 0, "RedblockComrades: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockComrades: minting more than allowed");

        uint256 mintForSender = Math.min(
            amount,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        uint256 howManyToMint = Math.min(mintForSender, cappedSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockComrades: can't mint that amount");

        uint256 mintPrice = pricePerTokenETH * howManyToMint;

        require(msg.value >= mintPrice, "RedblockComrades: not enough ether supplied");

        mintedPerAddress[_msgSender()] += howManyToMint;

        for (uint256 i = 0; i < howManyToMint; i++) {
            _safeMint(_msgSender(), ++currentlyMinted);

            emit MintedViaETH(currentlyMinted);
        }

        payable(msg.sender).transfer(msg.value - mintPrice);
    }

    /// @dev should be used to set allowance
    function getMintPriceNCT(uint256 amount) external view returns (uint256) {
        return _getMintPrice(amount, pricePerTokenNCT);
    }

    /// @dev should be used to set allowance
    function getMintPriceDUST(uint256 amount) external view returns (uint256) {
        return _getMintPrice(amount, pricePerTokenDUST);
    }

    /// @dev should be used to set allowance
    function getMintPriceWHALE(uint256 amount) external view returns (uint256) {
        return _getMintPrice(amount, pricePerTokenWHALE);
    }

    /// @dev should be used to set value
    function getMintPriceETH(uint256 amount) external view returns (uint256) {
        return _getMintPrice(amount, pricePerTokenETH);
    }

    function _getMintPrice(uint256 amount, uint256 price) internal pure returns (uint256) {
        require(amount > 0, "RedblockComrades: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockComrades: minting more than allowed");

        return price * amount;
    }

    function howManyICanMint(address user) external view returns (uint256) {
        return MINT_PER_ADDRESS - mintedPerAddress[user];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
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
