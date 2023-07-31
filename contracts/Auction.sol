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

    event PlaceAsset(
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 time
    );
    event CancelAsset(
        address seller,
        uint256 tokenId,
        uint256 price,
        uint256 time
    );
    event AcceptOffer(
        address seller,
        address buyer,
        uint256 tokenId,
        uint256 price,
        uint256 time
    );
    event BuyAsset(
        address bidder,
        uint256 tokenId,
        uint256 price,
        uint256 time
    );
    event PlaceBid(
        address bidder,
        uint256 tokenId,
        uint256 price,
        uint256 time
    );

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
    // seller functions
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
        emit PlaceAsset(msg.sender, tokenId, price, block.timestamp);
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
        emit CancelAsset(msg.sender, tokenId, lastBid[tokenId].price, block.timestamp);
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

        emit AcceptOffer(msg.sender, lastBid[tokenId].user, tokenId, lastBid[tokenId].price, block.timestamp);
    }

    //--------------------
    // buyer functions
    //--------------------

    function buAsset(uint256 tokenId) external payable whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(msg.value == lastBid[tokenId].price, "Assets: not enougth ETH");
        require(
            lastBid[tokenId].price == initPrice[tokenId],
            "Auction: can only be purchased if no bids have been placed"
        );
        require(
            lastBid[tokenId].user != msg.sender,
            "Auction: you tried to buy your token"
        );
        (bool sent, ) = assetOwner[tokenId].call{
            value: msg.value - (msg.value / 100) * FEE
        }("Your token has been purchased");
        require(sent, "Auction: failed to send Ether");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );

        _assets.unlockToken(tokenId);
        _assets.transferFrom(assetOwner[tokenId], msg.sender, tokenId);
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 index = assetIndex[tokenId];
            allTokens[index] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }
        _deleteAssetData(tokenId);
        tokensAmount--;
        emit BuyAsset(msg.sender, tokenId, lastBid[tokenId].price, block.timestamp);
    }

    function placeBid(uint256 tokenId, uint256 price) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );
        require(
            price >=
                lastBid[tokenId].price +
                    (lastBid[tokenId].price / 100) *
                    DISTINCTION,
            "Auction: the next bet must be greater than than the previous one + 3%"
        );
        Bid memory newBid = Bid(
            uint32(block.timestamp),
            uint128(price),
            msg.sender
        );
        lastBid[tokenId] = newBid;
        emit PlaceBid(msg.sender, tokenId, price, block.timestamp);
    }

    function getLastBid(
        uint256 tokenId
    ) external view returns (uint256, uint256, address) {
        Bid memory tmp = lastBid[tokenId];
        return (tmp.time, tmp.price, tmp.user);
    }

    function getAllAssetIds() external view returns (uint256[] memory) {
        return allTokens;
    }

    function getOwnerOfAsset(uint256 tokenId) external view returns (address) {
        return assetOwner[tokenId];
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

    //--------------------
    // admin functions
    //--------------------

     function getAllEth() external onlyOwner {
        (bool sent, ) = msg.sender.call{value: address(this).balance}(
            "ETH withdrowal"
        );
        require(sent, "Auction: failed to send Ether");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    receive() external payable {}

}
