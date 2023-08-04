pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/Auction.sol";

contract AuctionFactory {
    address private _treasury;
    address private _blacklist;
    address private _assets;

    uint256 private _tokenId;

    constructor(address treasury, address blacklist, address assets, uint256 tokenId) {
        _treasury = treasury;
        _blacklist = blacklist;
        _assets = assets;
        _tokenId = tokenId;
    }

    function deployAuction() external returns (address) {

    }
}

