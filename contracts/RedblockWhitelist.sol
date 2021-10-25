// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RedblockWhitelist is Ownable {
    using Address for address;

    IERC721 internal _punks; // 0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB
    IERC721 internal _meebits; // 0x7Bd29408f11D2bFC23c34f18275bBf23bB716Bc7
    IERC721 internal _veeFriends; // 0xa3AEe8BcE55BEeA1951EF834b99f3Ac60d1ABeeB

    uint256 public whitelistStartBlock;
    uint256 public whitelistBlockDuration;

    uint256 public totalWhitelist;
    mapping(address => bool) internal _whitelist;

    event Whitelisted(address user);
    event Delisted(address user);

    constructor(
        address punks,
        address meebits,
        address veeFriends
    ) Ownable() {
        _punks = IERC721(punks);
        _meebits = IERC721(meebits);
        _veeFriends = IERC721(veeFriends);
    }

    function setWhitelistInfo(uint256 startBlockNum, uint256 blockDuration) external onlyOwner {
        whitelistStartBlock = startBlockNum;
        whitelistBlockDuration = blockDuration;
    }

    function forceDelist(address[] calldata users) external onlyOwner {
        uint256 delisted;

        for (uint256 i = 0; i < users.length; i++) {
            if (_whitelist[users[i]]) {
                delete _whitelist[users[i]];
                delisted++;

                emit Delisted(users[i]);
            }
        }

        totalWhitelist -= delisted;
    }

    function forceWhitelist(address[] calldata users) external onlyOwner {
        uint256 whitelisted;

        for (uint256 i = 0; i < users.length; i++) {
            if (!_whitelist[users[i]]) {
                _whitelist[users[i]] = true;
                whitelisted++;

                emit Whitelisted(users[i]);
            }
        }

        totalWhitelist += whitelisted;
    }

    function isWhitelisted(address user) external view returns (bool) {
        return _whitelist[user];
    }

    function whitelist() external {
        require(!_whitelist[msg.sender], "Whitelist: already whitelisted");
        require(!msg.sender.isContract(), "Whitelist: contract whitelist not allowed");
        require(
            whitelistStartBlock + whitelistBlockDuration >= block.number,
            "Whitelist: whitelist ended"
        );
        require(
            _punks.balanceOf(msg.sender) > 0 ||
                _meebits.balanceOf(msg.sender) > 0 ||
                _veeFriends.balanceOf(msg.sender) > 0,
            "Whitelist: not eligible for whitelisting"
        );

        _whitelist[msg.sender] = true;
        totalWhitelist++;

        emit Whitelisted(msg.sender);
    }
}
