pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Auction.sol";

import "hardhat/console.sol";

contract AuctionFactory {
    address private _treasury;
    address private _blacklist;
    address private _assets;

    uint256 private _tokenId;

    mapping(address auction => bool relevance) public auctionRelevance;

    event ContractCreated(address auction);

    constructor(
        address treasury,
        address blacklist,
        address assets,
        uint256 tokenId
    ) {
        _treasury = treasury;
        _blacklist = blacklist;
        _assets = assets;
        _tokenId = tokenId;
    }

    function deployAuction() external returns (address) {
        Auction newAuction = new Auction(_assets, _treasury, _blacklist, address(this), _tokenId);
        log(address(newAuction));
        auctionRelevance[address(newAuction)] = false;
        emit ContractCreated(address(newAuction));
        return (address(newAuction));
    }

    function updateRelevance(address auction, bool relevance) external {
        auctionRelevance[auction] = relevance;
    }
}
