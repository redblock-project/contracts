// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RedblockSale is IERC721Receiver, ReentrancyGuard, Ownable, ERC721Enumerable {
    using Math for uint256;

    uint256 public constant MINT_PER_TRANSACTION = 5;
    uint256 public constant MINT_PER_ADDRESS = 5;
    uint256 public constant MINT_PER_OPTION = 100;

    address public constant NCT_ADDRESS = 0x8A9c4dfe8b9D8962B31e4e16F8321C44d48e246E;
    address public constant NFTBOXES_ADDRESS = 0x6d4530149e5B4483d2F7E60449C02570531A0751;
    address public constant ARTBLOCKS_ADDRESS = 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;

    string public baseTokenURI;

    uint256 public cappedSupply = 9917;
    uint256 public currentlyMinted;

    uint256 public pricePerTokenETH = 5 * 10**16; // 0.05 ether
    uint256 public pricePerTokenNCT = 5000 * 10**18; // 5000 NCT

    uint256 public multiplierNFTBoxes = 1;
    uint256 public multiplierArtblocks = 3;

    mapping(address => uint256) public mintedPerAddress;
    mapping(address => uint256) public mintedPerOption;

    bool public saleStopped;

    event MintedViaETH(uint256 tokenId);
    event MintedViaERC20(uint256 tokenId, address collateral);
    event MintedViaERC721(uint256 tokenId, address collateral);
    event WithdrawnETH(uint256 amount);
    event WithdrawnERC20(uint256 amount, address collateral);
    event WithdrawnERC721(uint256 tokenId, address collateral);

    modifier notStopped() {
        require(!saleStopped, "RedblockSale: sale is stopped");
        _;
    }

    constructor() ReentrancyGuard() Ownable() ERC721("Redblock", "RB") {}

    function triggerSale(bool option) external onlyOwner {
        saleStopped = option;
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

    function setPricePerTokenNCT(uint256 newPriceNCT) external onlyOwner {
        pricePerTokenNCT = newPriceNCT;
    }

    function setPricePerTokenETH(uint256 newPriceETH) external onlyOwner {
        pricePerTokenETH = newPriceETH;
    }

    function withdrawArtblocks(uint256 batch) external onlyOwner {
        _withdrawERC721(ARTBLOCKS_ADDRESS, batch);
    }

    function withdrawNFTBoxes(uint256 batch) external onlyOwner {
        _withdrawERC721(NFTBOXES_ADDRESS, batch);
    }

    function _withdrawERC721(address collateralAddress, uint256 batch) internal {
        IERC721Enumerable collateral = IERC721Enumerable(collateralAddress);
        int256 balance = int256(collateral.balanceOf(address(this)));

        /// @dev loop is reversed due to "swap and pop" thing
        for (int256 i = balance - 1; i >= balance - int256(batch); i--) {
            uint256 tokenId = collateral.tokenOfOwnerByIndex(address(this), uint256(i));
            collateral.safeTransferFrom(address(this), owner(), tokenId);

            emit WithdrawnERC721(tokenId, collateralAddress);
        }
    }

    function withdrawNCT() external onlyOwner {
        _withdrawERC20(NCT_ADDRESS);
    }

    function _withdrawERC20(address collateralAddress) internal {
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

    function mintForArtblocks(uint256 tokenId) external notStopped nonReentrant {
        _mintForERC721(tokenId, ARTBLOCKS_ADDRESS, multiplierArtblocks);
    }

    function mintForNFTBoxes(uint256 tokenId) external notStopped nonReentrant {
        _mintForERC721(tokenId, NFTBOXES_ADDRESS, multiplierNFTBoxes);
    }

    function _mintForERC721(
        uint256 tokenId,
        address collateralAddress,
        uint256 multiplier
    ) internal {
        uint256 mintForSender = Math.min(
            multiplier,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        uint256 mintForOption = Math.min(
            mintForSender,
            MINT_PER_OPTION - mintedPerOption[collateralAddress]
        );

        uint256 howManyToMint = Math.min(mintForOption, cappedSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockSale: can't mint that amount");

        IERC721(collateralAddress).safeTransferFrom(_msgSender(), address(this), tokenId);

        mintedPerAddress[_msgSender()] += multiplier;
        mintedPerOption[collateralAddress] += multiplier;

        for (uint256 i = 0; i < multiplier; i++) {
            _safeMint(_msgSender(), ++currentlyMinted);

            emit MintedViaERC721(currentlyMinted, collateralAddress);
        }
    }

    function mintForNCT(uint256 amount) external notStopped nonReentrant {
        _mintForERC20(amount, NCT_ADDRESS, pricePerTokenNCT);
    }

    function _mintForERC20(
        uint256 amount,
        address collateralAddress,
        uint256 pricePerToken
    ) internal {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        uint256 mintForSender = Math.min(
            amount,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        uint256 mintForOption = Math.min(
            mintForSender,
            MINT_PER_OPTION - mintedPerOption[collateralAddress]
        );

        uint256 howManyToMint = Math.min(mintForOption, cappedSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockSale: can't mint that amount");

        uint256 mintPrice = pricePerToken * howManyToMint;

        IERC20(collateralAddress).transferFrom(_msgSender(), address(this), mintPrice);

        mintedPerAddress[_msgSender()] += howManyToMint;
        mintedPerOption[collateralAddress] += howManyToMint;

        for (uint256 i = 0; i < howManyToMint; i++) {
            _safeMint(_msgSender(), ++currentlyMinted);

            emit MintedViaERC20(currentlyMinted, collateralAddress);
        }
    }

    function mintForETH(uint256 amount) external payable notStopped nonReentrant {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        uint256 mintForSender = Math.min(
            amount,
            MINT_PER_ADDRESS - mintedPerAddress[_msgSender()]
        );

        uint256 howManyToMint = Math.min(mintForSender, cappedSupply - currentlyMinted);

        require(howManyToMint > 0, "RedblockSale: can't mint that amount");

        uint256 mintPrice = pricePerTokenETH * howManyToMint;

        require(msg.value >= mintPrice, "RedblockSale: not enough ether supplied");

        mintedPerAddress[_msgSender()] += howManyToMint;

        for (uint256 i = 0; i < howManyToMint; i++) {
            _safeMint(_msgSender(), ++currentlyMinted);

            emit MintedViaETH(currentlyMinted);
        }

        payable(msg.sender).transfer(msg.value - mintPrice);
    }

    /// @dev should be used to set allowance
    function getMintPriceNCT(uint256 amount) external view returns (uint256) {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        return pricePerTokenNCT * amount;
    }

    /// @dev should be used to set value
    function getMintPriceETH(uint256 amount) external view returns (uint256) {
        require(amount > 0, "RedblockSale: can't mint zero amount");
        require(amount <= MINT_PER_TRANSACTION, "RedblockSale: minting more than allowed");

        return pricePerTokenETH * amount;
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
