pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";
import "contracts/interfaces/ITreasury.sol";

contract Auction is Pausable, AccessControl {
    uint256 public constant FEE = 3;
    uint256 public constant DISTINCTION = 3;
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");

    IAssets private _assets;
    ITreasury private _treasury;
    IBlacklist private _blacklist;

    address private _factory;

    uint256 private _tokenId;

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

    constructor (
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
        assetOwner = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        grantRole(UNPAUSER_ROLE, treasuryAddress);
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
        _assets.lockToken(_tokenId);
        lastBid = Bid(uint32(block.timestamp), uint128(price), msg.sender);
        initPrice = price;
        (bool success, ) = _factory.delegatecall(
            abi.encodeWithSignature("updateRelevance(address, bool)", address(this), true));
            require(success, "Auction: update failed");
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
        _assets.unlockToken(_tokenId);
        stopAuction();
        emit CancelAsset(msg.sender, _tokenId, lastBid.price, block.timestamp);
    }

    //TODO: add bool flag from factory(may be add to treasury, when asset is sold)
    //TODO add new asset owner after buy
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
        _assets.unlockToken(_tokenId);
        _assets.transferFrom(msg.sender, address(_treasury), _tokenId);
        _treasury.addNewPandingTrade(
            msg.sender,
            lastBid.user,
            _tokenId,
            lastBid.time,
            lastBid.price
        );
        stopAuction();

        emit AcceptOffer(
            msg.sender,
            lastBid.user,
            _tokenId,
            lastBid.price,
            block.timestamp
        );
    }

    //--------------------
    // buyer functions
    //--------------------

    //TODO: add bool flag from factory 
    //TODO: add new assetOwner after buy
    function buyAsset() external payable whenNotPaused {
        require(!_isContract(msg.sender), "Auction: only EOA");
        require(
            msg.value == lastBid.price,
            "Assets: not enougth ETH"
        );
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

        _assets.unlockToken(_tokenId);
        _assets.transferFrom(assetOwner, msg.sender, _tokenId);
        stopAuction();
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

    function stopAuction() internal {
        assetOwner = lastBid.user;
        delete lastBid;
        delete initPrice;
        (bool success, ) = _factory.delegatecall(
            abi.encodeWithSignature("updateRelevance(address, bool)", address(this), false));
        require(success, "Auction: update auction relevance");
        pause();
    }

    //--------------------
    // admin functions
    //--------------------

    function getAllEth() external onlyRole(ADMIN_ROLE) {
        (bool sent, ) = msg.sender.call{value: address(this).balance}(
            "ETH withdrowal"
        );
        require(sent, "Auction: failed to send Ether");
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(UNPAUSER_ROLE){
        _unpause();
    }

    receive() external payable {}
}
