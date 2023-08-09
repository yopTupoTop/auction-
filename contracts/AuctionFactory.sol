pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Auction.sol";
import "contracts/interfaces/IAssets.sol";

contract AuctionFactory {
    address private _treasury;
    address private _blacklist;
    address private _assets;

    mapping(uint256 tokenId => bool auctionExist) public auctionExistence;

    event ContractCreated(address auction, address owner);

    constructor(address treasury, address blacklist, address assets) {
        _treasury = treasury;
        _blacklist = blacklist;
        _assets = assets;
    }

    function deployAuction(uint256 tokenId) external {
        require(
            auctionExistence[tokenId] == false,
            "AuctionFactory: auction already exists"
        );
        require(
            IAssets(_assets).ownerOf(tokenId) == msg.sender,
            "AuctionFactory: you're not the owner"
        );
        Auction newAuction = new Auction(
            _assets,
            _treasury,
            _blacklist,
            address(this),
            tokenId
        );
        auctionExistence[tokenId] = true;
        emit ContractCreated(address(newAuction), msg.sender);
    }
}
