pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Auction.sol";
import "contracts/interfaces/IAssets.sol";

//import "hardhat/console.sol";

contract AuctionFactory {
    address private _treasury;
    address private _blacklist;
    address private _assets;

    //uint256 private _tokenId;

    mapping(address auction => bool relevance) public auctionRelevance;

    event ContractCreated(address auction, address owner);

    constructor(
        address treasury,
        address blacklist,
        address assets
    ) {
        _treasury = treasury;
        _blacklist = blacklist;
        _assets = assets;
    }

    function deployAuction(uint256 tokenId) external returns (address) {
        require(IAssets(_assets).ownerOf(tokenId) == msg.sender, "AuctionFactory: you're not the owner");
        Auction newAuction = new Auction(_assets, _treasury, _blacklist, address(this), tokenId);
        //log(address(newAuction));
        auctionRelevance[address(newAuction)] = false;
        emit ContractCreated(address(newAuction), msg.sender);
        return address(newAuction);
    }

    function updateRelevance(address auction, bool relevance) external {
        require(msg.sender == auction, "AuctionFactory: you can't change relevance");
        auctionRelevance[auction] = relevance;
    }
}
