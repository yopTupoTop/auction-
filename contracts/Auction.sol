pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "contracts/interfaces/IAuction.sol";
import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";
import "contracts/interfaces/ITreasury.sol";

contract Auction is Pausable, AccessControl {
    uint256 public constant FEE = 3;
    uint256 public constant DISTINCTION = 3;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    IAssets private _assets;
    ITreasury private _treasury;
    IBlacklist private _blacklist;

    address private _factory;

    uint256 private _tokenId;

    bool private _relevance;

    struct Bid {
        uint32 time;
        uint128 price;
        address user;
    }

    Bid private lastBid;
    uint256 private initPrice;
    address private assetOwner;

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

    constructor(
        address assetsAddress,
        address treasuryAddress,
        address blacklistAddress,
        address factoryAddress,
        uint256 tokenId
    ) {
        _assets = IAssets(assetsAddress);
        _treasury = ITreasury(treasuryAddress);
        _blacklist = IBlacklist(blacklistAddress);
        _factory = factoryAddress;
        _tokenId = tokenId;
        assetOwner = tx.origin;
        _setupRole(DEFAULT_ADMIN_ROLE, tx.origin);
        _setupRole(ADMIN_ROLE, tx.origin);
        _setupRole(UNPAUSER_ROLE, tx.origin);
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
        require(lastBid.time == 0, "Auction: token already placed");
        _setRelevance(true);
        _assets.lockToken(_tokenId, address(this));
        lastBid = Bid(uint32(block.timestamp), uint128(price), msg.sender);
        initPrice = price;
        emit PlaceAsset(msg.sender, _tokenId, price, block.timestamp);
    }

    function cancelAsset() external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(_tokenId),
            "Auction: you're not the owner"
        );
        require(
            lastBid.time != 0,
            "Auction: token is not for sale on the auction"
        );
        _assets.unlockToken(_tokenId, address(this));
        _stopAuction();
        emit CancelAsset(msg.sender, _tokenId, lastBid.price, block.timestamp);
    }

    function acceptOffer() external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.sender == _assets.ownerOf(_tokenId),
            "Auction: you are not the owner of token"
        );
        require(
            msg.sender != lastBid.user,
            "Auction: you tried to buy your token"
        );
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot sell"
        );
        _assets.unlockToken(_tokenId, address(this));
        _assets.transferFrom(msg.sender, address(_treasury), _tokenId);
        _treasury.addNewPandingTrade(
            msg.sender,
            lastBid.user,
            _tokenId,
            lastBid.time,
            lastBid.price,
            address(this)
        );
        _stopAuction();

        emit AcceptOffer(
            msg.sender,
            lastBid.user,
            _tokenId,
            lastBid.price,
            block.timestamp
        );
    }

    function updateRelevance() external onlyRole(ADMIN_ROLE) {
        _setRelevance(true);
        unpause();
    }

    //--------------------
    // buyer functions
    //--------------------

    function buyAsset() external payable whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(msg.value == lastBid.price, "Assets: not enougth ETH");
        require(
            lastBid.price == initPrice,
            "Auction: can only be purchased if no bids have been placed"
        );
        require(
            lastBid.user != msg.sender,
            "Auction: you tried to buy your token"
        );
        (bool sent, ) = assetOwner.call{
            value: msg.value - (msg.value / 100) * FEE
        }("Your token has been purchased");
        require(sent, "Auction: failed to send Ether");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );

        _assets.unlockToken(_tokenId, address(this));
        _assets.transferFrom(assetOwner, msg.sender, _tokenId);
        _stopAuction();
        assetOwner = lastBid.user;
        emit BuyAsset(msg.sender, _tokenId, lastBid.price, block.timestamp);
    }

    function placeBid(uint256 price) external whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            !_blacklist.isInBlacklist(msg.sender),
            "Auction: blacklisted user cannot buy"
        );
        require(
            price >= lastBid.price + (lastBid.price / 100) * DISTINCTION,
            "Auction: the next bet must be greater than than the previous one + 3%"
        );
        Bid memory newBid = Bid(
            uint32(block.timestamp),
            uint128(price),
            msg.sender
        );
        lastBid = newBid;
        emit PlaceBid(msg.sender, _tokenId, price, block.timestamp);
    }

    function getLastBid() external view returns (uint256, uint256, address) {
        Bid memory tmp = lastBid;
        return (tmp.time, tmp.price, tmp.user);
    }

    function getOwnerOfAsset() external view returns (address) {
        return assetOwner;
    }

    function getRelevance() external view returns (bool) {
        return _relevance;
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

    function _stopAuction() internal {
        delete lastBid;
        delete initPrice;
        _setRelevance(false);
        pause();
    }

    function _setRelevance(bool relevance) internal {
        _relevance = relevance;
    }

    //--------------------
    // admin functions
    //--------------------

    function getAllEth() external onlyRole(DEFAULT_ADMIN_ROLE) {
        (bool sent, ) = _assets.ownerOf(1).call{value: address(this).balance}(
            "ETH withdrowal"
        );
        require(sent, "Auction: failed to send Ether");
    }

    function updateOwner() external onlyRole(UNPAUSER_ROLE) {
        assetOwner = lastBid.user;
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    receive() external payable {}
}
