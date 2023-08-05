pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Auction.sol";

contract AuctionFactory {
    address private _treasury;
    address private _blacklist;
    address private _assets;

    uint256 private _tokenId;

    mapping(address auction => bool sold) public auctionRelevance;

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
        Auction newAuction = new Auction();
        newAuction.initialize(_assets, _treasury, _blacklist, _tokenId);
        auctionRelevance[address(newAuction)] = false;
        return (address(newAuction));
    }
}
