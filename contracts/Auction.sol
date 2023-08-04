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

    uint256 private _tokenId;

    struct Bid {
        uint32 time;
        uint128 price;
        address user;
    }

    uint256[] private allTokens;

    //TODO: change to single token id
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
        address blacklistAddress,
        uint256 tokenId
    ) public initializer {
        _assets = IAssets(assetsAddress);
        _treasury = ITreasury(treasuryAddress);
        _blacklist = IBlacklist(blacklistAddress);
        _tokenId = tokenId;

        __Pausable_init();
        __Ownable_init();
    }

    //--------------------
    // seller functions
    //--------------------

    function sellAsset(uint256 price) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(_tokenId),
            "Auction: you're not the owner"
        );
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted users can't sell"
        );
        require(lastBid[_tokenId].time == 0, "Auction: token already placed");
        _assets.lockToken(_tokenId);
        lastBid[_tokenId] = Bid(
            uint32(block.timestamp),
            uint128(price),
            msg.sender
        );
        initPrice[_tokenId] = price;
        assetOwner[_tokenId] = msg.sender;
        allTokens.push(_tokenId);
        assetIndex[_tokenId] = allTokens.length - 1;
        tokensAmount++;
        emit PlaceAsset(msg.sender, _tokenId, price, block.timestamp);
    }

    function cancelAsset() external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(_tokenId),
            "Auction: you're not the owner"
        );
        require(
            lastBid[_tokenId].time != 0,
            "Auction: token is not for sale on the auction"
        );
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 tokenIndex = assetIndex[_tokenId];
            allTokens[tokenIndex] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }

        _assets.unlockToken(_tokenId);
        _deleteAssetData();
        tokensAmount--;
        emit CancelAsset(msg.sender, _tokenId, lastBid[_tokenId].price, block.timestamp);
    }

    function acceptOffer() external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(_tokenId),
            "Auction: you are not the owner of token"
        );
        require(
            msg.sender != lastBid[_tokenId].user,
            "Auction: you tried to buy your token"
        );
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot sell"
        );
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 tokenIndex = assetIndex[_tokenId];
            allTokens[tokenIndex] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }

        tokensAmount--;
        _assets.unlockToken(_tokenId);
        _assets.transferFrom(msg.sender, address(_treasury), _tokenId);
        _treasury.addNewPandingTrade(
            msg.sender,
            lastBid[_tokenId].user,
            _tokenId,
            lastBid[_tokenId].time,
            lastBid[_tokenId].price
        );
        _deleteAssetData();

        emit AcceptOffer(msg.sender, lastBid[_tokenId].user, _tokenId, lastBid[_tokenId].price, block.timestamp);
    }

    //--------------------
    // buyer functions
    //--------------------

    function buyAsset() external payable whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(msg.value == lastBid[_tokenId].price, "Assets: not enougth ETH");
        require(
            lastBid[_tokenId].price == initPrice[_tokenId],
            "Auction: can only be purchased if no bids have been placed"
        );
        require(
            lastBid[_tokenId].user != msg.sender,
            "Auction: you tried to buy your token"
        );
        (bool sent, ) = assetOwner[_tokenId].call{
            value: msg.value - (msg.value / 100) * FEE
        }("Your token has been purchased");
        require(sent, "Auction: failed to send Ether");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );

        _assets.unlockToken(_tokenId);
        _assets.transferFrom(assetOwner[_tokenId], msg.sender, _tokenId);
        if (allTokens.length < 2) {
            allTokens.pop();
        } else {
            uint256 index = assetIndex[_tokenId];
            allTokens[index] = allTokens[tokensAmount - 1];
            allTokens.pop();
        }
        _deleteAssetData();
        tokensAmount--;
        emit BuyAsset(msg.sender, _tokenId, lastBid[_tokenId].price, block.timestamp);
    }

    function placeBid(uint256 price) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );
        require(
            price >=
                lastBid[_tokenId].price +
                    (lastBid[_tokenId].price / 100) *
                    DISTINCTION,
            "Auction: the next bet must be greater than than the previous one + 3%"
        );
        Bid memory newBid = Bid(
            uint32(block.timestamp),
            uint128(price),
            msg.sender
        );
        lastBid[_tokenId] = newBid;
        emit PlaceBid(msg.sender, _tokenId, price, block.timestamp);
    }

    function getLastBid() external view returns (uint256, uint256, address) {
        Bid memory tmp = lastBid[_tokenId];
        return (tmp.time, tmp.price, tmp.user);
    }

    function getAllAssetIds() external view returns (uint256[] memory) {
        return allTokens;
    }

    function getOwnerOfAsset() external view returns (address) {
        return assetOwner[_tokenId];
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

    function _deleteAssetData() internal {
        delete lastBid[_tokenId];
        delete initPrice[_tokenId];
        delete assetOwner[_tokenId];
        delete assetIndex[_tokenId];
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
