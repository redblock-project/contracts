// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "hardhat/console.sol";

contract RedblockComrades is IERC721Receiver, ReentrancyGuard, Ownable, ERC721Enumerable {
    using Math for uint256;

    uint256 public constant MINT_PER_TRANSACTION = 5;
    uint256 public constant MINT_PER_ADDRESS = 5;
    uint256 public constant MINT_PER_OPTION = 100;

    uint256 public constant OWNER_AMOUNT = 40;

    bytes32 public whitelistRoot;

    address[] public whitelistCollections; // 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB, 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7, 0xa3aee8bce55beea1951ef834b99f3ac60d1abeeb

    address public nctAddress; // 0x8A9c4dfe8b9D8962B31e4e16F8321C44d48e246E;
    address public dustAddress; // 0xe2E109f1b4eaA8915655fE8fDEfC112a34ACc5F0;
    address public whaleAddress; // 0x9355372396e3F6daF13359B7b607a3374cc638e0;

    address public nftBoxesAddress; // 0x6d4530149e5B4483d2F7E60449C02570531A0751;
    address public artblocksAddress; // 0xa7d8d9ef8D8Ce8992Df33D8b8CF4Aebabd5bD270;

    string public baseTokenURI;

    uint256 public cappedSupply = 9917;
    uint256 public currentlyMinted;

    uint256 public pricePerTokenETH = 711 * 10**14; // 0.05 ether
    uint256 public pricePerTokenNCT = 3000 * 10**18; // 5000 NCT
    uint256 public pricePerTokenDUST = 750 * 10**18; // 550 DUST
    uint256 public pricePerTokenWHALE = 18 * 10**4; // 11 WHALE

    uint256 public multiplierNFTBoxes = 1;
    uint256 public multiplierArtblocks = 3;

    mapping(address => uint256) public mintedPerAddress;
    mapping(address => uint256) public mintedPerOption;

    uint256 public whitelistEndBlock;
    bool public saleStopped;

    event Minted(uint256 tokenId);
    event WithdrawnETH(uint256 amount);
    event WithdrawnERC20(uint256 amount, address collateral);
    event WithdrawnERC721(uint256 tokenId, address collateral);

    modifier notStopped() {
        require(!saleStopped, "RedblockComrades: sale is stopped");
        _;
    }

    modifier whitelistEnded() {
        require(isWhitelistEnded(), "RedblockComrades: whitelist mint not ended");
        _;
    }

    modifier whitelisted(
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    ) {
        _checkWhitelist(whitelistAllocation, leaf, proof);
        _;
    }

    modifier correctAmount(uint256 amount, uint256 whitelistAllocation) {
        _checkWhitelistAmount(amount, whitelistAllocation);
        _;
    }

    constructor(
        address[] memory _whitelistCollections,
        address[] memory _tokenAddresses,
        address[] memory _nftAddresses
    ) ReentrancyGuard() Ownable() ERC721("Redblock Comrades", "\xe2\x98\xad") {
        whitelistCollections = _whitelistCollections;

        nctAddress = _tokenAddresses[0];
        dustAddress = _tokenAddresses[1];
        whaleAddress = _tokenAddresses[2];

        nftBoxesAddress = _nftAddresses[0];
        artblocksAddress = _nftAddresses[1];

        saleStopped = true;
    }

    function mintOwner() external onlyOwner {
        require(currentlyMinted == 0, "RedblockComrades: owner can't mint");

        _mintComrades(OWNER_AMOUNT);
    }

    function triggerSale(bool option) external onlyOwner {
        saleStopped = !option;
    }

    function setWhitelistEndBlock(uint256 blockNum) public onlyOwner {
        whitelistEndBlock = blockNum;
    }

    function setWhitelistRoot(bytes32 root) external onlyOwner {
        whitelistRoot = root;
    }

    function setBaseTokenURI(string calldata URI) external onlyOwner {
        baseTokenURI = URI;
    }

    function withdrawETH() external onlyOwner {
        uint256 toWithdraw = address(this).balance;

        (bool success, ) = owner().call{value: toWithdraw}("");
        require(success, "RedblockComrades: failed to withdraw ETH");

        emit WithdrawnETH(toWithdraw);
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

    /////////////////////////////////////////////////////////////////////////////////////////

    function mintForArtblocksWhitelist(
        uint256[] calldata tokenIds,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    ) external whitelisted(whitelistAllocation, leaf, proof) {
        _mintForERC721(tokenIds, artblocksAddress, multiplierArtblocks, whitelistAllocation);
    }

    function mintForArtblocks(uint256[] calldata tokenIds) external whitelistEnded {
        _mintForERC721(tokenIds, artblocksAddress, multiplierArtblocks, MINT_PER_ADDRESS);
    }

    function mintForNFTBoxesWhitelist(
        uint256[] calldata tokenIds,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    ) external whitelisted(whitelistAllocation, leaf, proof) {
        _mintForERC721(tokenIds, nftBoxesAddress, multiplierNFTBoxes, whitelistAllocation);
    }

    function mintForNFTBoxes(uint256[] calldata tokenIds) external whitelistEnded {
        _mintForERC721(tokenIds, nftBoxesAddress, multiplierNFTBoxes, MINT_PER_ADDRESS);
    }

    function mintForNCTWhitelist(
        uint256 amount,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        whitelisted(whitelistAllocation, leaf, proof)
        correctAmount(amount, whitelistAllocation)
    {
        _mintForERC20(amount, nctAddress, pricePerTokenNCT);
    }

    function mintForNCT(uint256 amount) external whitelistEnded {
        _mintForERC20(amount, nctAddress, pricePerTokenNCT);
    }

    function mintForDUSTWhitelist(
        uint256 amount,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        whitelisted(whitelistAllocation, leaf, proof)
        correctAmount(amount, whitelistAllocation)
    {
        _mintForERC20(amount, dustAddress, pricePerTokenDUST);
    }

    function mintForDUST(uint256 amount) external whitelistEnded {
        _mintForERC20(amount, dustAddress, pricePerTokenDUST);
    }

    function mintForWHALEWhitelist(
        uint256 amount,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        whitelisted(whitelistAllocation, leaf, proof)
        correctAmount(amount, whitelistAllocation)
    {
        _mintForERC20(amount, whaleAddress, pricePerTokenWHALE);
    }

    function mintForWHALE(uint256 amount) external whitelistEnded {
        _mintForERC20(amount, whaleAddress, pricePerTokenWHALE);
    }

    function mintForETHWhitelist(
        uint256 amount,
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        payable
        whitelisted(whitelistAllocation, leaf, proof)
        correctAmount(amount, whitelistAllocation)
    {
        _mintForETH(amount);
    }

    function mintForETH(uint256 amount) external payable whitelistEnded {
        _mintForETH(amount);
    }

    /////////////////////////////////////////////////////////////////////////////////////////

    function _checkWhitelist(
        uint256 whitelistAllocation,
        bytes32 leaf,
        bytes32[] calldata proof
    ) internal view {
        require(
            isInDefaultWhitelist(_msgSender()) ||
                ((keccak256(abi.encodePacked(_msgSender(), whitelistAllocation)) == leaf) &&
                    MerkleProof.verify(proof, whitelistRoot, leaf)),
            "RedblockComrades: not whitelisted"
        );
    }

    function _checkWhitelistAmount(uint256 amount, uint256 whitelistAllocation) internal view {
        require(
            mintedPerAddress[_msgSender()] + amount <= whitelistAllocation,
            "RedblockComrades: minting more than allowed"
        );
    }

    function _getMaxMintAvailable(uint256 amount, address user) internal view returns (uint256) {
        require(amount <= MINT_PER_TRANSACTION, "RedblockComrades: minting more than allowed");

        uint256 mintForSender = Math.min(amount, MINT_PER_ADDRESS - mintedPerAddress[user]);

        return Math.min(mintForSender, cappedSupply - currentlyMinted);
    }

    function _getMaxMintPerOptionForUser(uint256 amount, address collateralAddress)
        internal
        view
        returns (uint256)
    {
        return
            Math.min(
                _getMaxMintAvailable(amount, _msgSender()),
                MINT_PER_OPTION - mintedPerOption[collateralAddress]
            );
    }

    function _mintForERC721(
        uint256[] calldata tokenIds,
        address collateralAddress,
        uint256 multiplier,
        uint256 whitelistCap
    ) internal notStopped nonReentrant {
        uint256 howManyToMint = _getMaxMintPerOptionForUser(
            (tokenIds.length * multiplier).min(whitelistCap - mintedPerAddress[_msgSender()]),
            collateralAddress
        );
        uint256 tokensAmount = (howManyToMint + multiplier - 1) / multiplier;

        for (uint256 i = 0; i < tokensAmount; i++) {
            IERC721(collateralAddress).safeTransferFrom(_msgSender(), owner(), tokenIds[i]);
        }

        require(howManyToMint > 0, "RedblockComrades: can't mint that amount");

        mintedPerOption[collateralAddress] += howManyToMint;
        mintedPerAddress[_msgSender()] += howManyToMint;

        _mintComrades(howManyToMint);
    }

    function _mintForERC20(
        uint256 amount,
        address collateralAddress,
        uint256 pricePerToken
    ) internal notStopped nonReentrant {
        uint256 howManyToMint = _getMaxMintPerOptionForUser(amount, collateralAddress);

        require(howManyToMint > 0, "RedblockComrades: can't mint that amount");

        uint256 mintPrice = pricePerToken * howManyToMint;

        IERC20(collateralAddress).transferFrom(_msgSender(), owner(), mintPrice);

        mintedPerOption[collateralAddress] += howManyToMint;
        mintedPerAddress[_msgSender()] += howManyToMint;

        _mintComrades(howManyToMint);
    }

    function _mintForETH(uint256 amount) internal notStopped nonReentrant {
        uint256 howManyToMint = _getMaxMintAvailable(amount, _msgSender());

        require(howManyToMint > 0, "RedblockComrades: can't mint that amount");

        uint256 mintPrice = pricePerTokenETH * howManyToMint;

        require(msg.value >= mintPrice, "RedblockComrades: not enough ether supplied");

        mintedPerAddress[_msgSender()] += howManyToMint;

        _mintComrades(howManyToMint);

        payable(msg.sender).transfer(msg.value - mintPrice);
    }

    function _mintComrades(uint256 howManyToMint) internal {
        uint256 minted = currentlyMinted;

        for (uint256 i = 0; i < howManyToMint; i++) {
            _safeMint(_msgSender(), ++minted);

            emit Minted(minted);
        }

        currentlyMinted = minted;
    }

    /////////////////////////////////////////////////////////////////////////////////////////

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

    function isInDefaultWhitelist(address user) public view returns (bool) {
        return
            IERC721(whitelistCollections[0]).balanceOf(user) > 0 ||
            IERC721(whitelistCollections[1]).balanceOf(user) > 0 ||
            IERC721(whitelistCollections[2]).balanceOf(user) > 0;
    }

    function isWhitelistEnded() public view returns (bool) {
        uint256 endBlock = whitelistEndBlock;

        return endBlock != 0 && endBlock <= block.number;
    }

    function howManyICanMint(address user) external view returns (uint256) {
        return _getMaxMintAvailable(MINT_PER_ADDRESS, user);
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
