pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";
import "contracts/interfaces/ITreasury.sol";

contract Auction is Initializable, PausableUpgradeable, OwnableUpgradeable {
    uint256 public constant FEE = 3;
    uint256 public constant DISTINCTION = 3;

    uint256 public tokensAmount;

    IAssets private _assets;
    ITreasury private _treasury;
    IBlacklist private _blacklist;

    struct Bid {
        uint32 time;
        uint128 price;
        address user;
    }

    uint256[] private allTokens;

    mapping(uint256 id => Bid) private lastBid;
    mapping(uint256 id => uint256 initialPrice) private initPrice;
    mapping(uint256 id => address owner) private assetOwner;
    mapping(uint256 id => uint256 allTokensIndex) private assetIndex;

    function initialize(
        address assetsAddress,
        address treasuryAddress,
        address blacklistAddress
    ) public initializer {
        _assets = IAssets(assetsAddress);
        _treasury = ITreasury(treasuryAddress);
        _blacklist = IBlacklist(blacklistAddress);

        __Pausable_init();
        __Ownable_init();
    }

    //--------------------
    // saller functions
    //--------------------

    function sellAsset(uint256 tokenId, uint256 price) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(tokenId),
            "Auction: you're not the owner"
        );
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted users can't sell"
        );
        require(lastBid[tokenId].time == 0, "Auction: token already placed");
        _assets.lockToken(tokenId);
        lastBid[tokenId] = Bid(
            uint32(block.timestamp),
            uint128(price),
            msg.sender
        );
        initPrice[tokenId] = price;
        assetOwner[tokenId] = msg.sender;
        allTokens.push(tokenId);
        assetIndex[tokenId] = allTokens.length - 1;
        tokensAmount++;
    }

    function cancelAsset(uint256 tokenId) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(tokenId),
            "Auction: you're not the owner"
        );
        require(
            lastBid[tokenId].time != 0,
            "Auction: token is not for sale on the auction"
        );
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 tokenIndex = assetIndex[tokenId];
            allTokens[tokenIndex] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }

        _assets.unlockToken(tokenId);
        _deleteAssetData(tokenId);
        tokensAmount--;
    }

    function acceptOffer(uint256 tokenId) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(tokenId),
            "Auction: you are not the owner of token"
        );
        require(
            msg.sender != lastBid[tokenId].user,
            "Auction: you tried to buy your token"
        );
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot sell"
        );
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 tokenIndex = assetIndex[tokenId];
            allTokens[tokenIndex] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }

        tokensAmount--;
        _assets.unlockToken(tokenId);
        _assets.transferFrom(msg.sender, address(_treasury), tokenId);
        _treasury.addNewPandingTrade(
            msg.sender,
            lastBid[tokenId].user,
            tokenId,
            lastBid[tokenId].time,
            lastBid[tokenId].price
        );
        _deleteAssetData(tokenId);
    }

    //--------------------
    // internal functions
    //--------------------

    function _isContract(address addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }

    function _deleteAssetData(uint256 tokenId) internal {
        delete lastBid[tokenId];
        delete initPrice[tokenId];
        delete assetOwner[tokenId];
        delete assetIndex[tokenId];
    }
}
