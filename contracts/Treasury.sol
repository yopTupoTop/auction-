pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/ITreasury.sol";
import "contracts/interfaces/IAssets.sol";

contract Treasury is ITreasury, Ownable {
    uint256 public constant FEE = 2;
    uint256 public constant DURATION = 1 hours;

    IAssets private _assets;

    address private _auctionAddress;

    mapping(uint256 tokenId => PendingTrade tradeDetails) private pendingTrades;
    mapping(uint256 tokenId => uint256 allTIPIndex) private tokenIndexes;

    struct PendingTrade {
        address oldOwner;
        address newOwner;
        uint64 price;
        uint32 time;
        bool paid;
    }

    uint256[] private allTokensInPending;

    constructor(address assetsAddress) {
        _assets = IAssets(assetsAddress);
    }

    function checkTrade(uint256 tokenId) external {
        PendingTrade memory tradeInformation = pendingTrades[tokenId];
        require(
            tradeInformation.oldOwner != address(0) ||
                tradeInformation.newOwner != address(0),
            "Treasury: this trade doesn't exist"
        );
        if (block.timestamp >= tradeInformation.time + DURATION) {
            if (msg.sender == tradeInformation.oldOwner) {
                _assets.transferFrom(address(this), msg.sender, tokenId);
                (bool success, ) = _auctionAddress.delegatecall(abi.encodeWithSignature("unpause()"));
                require(success, "Treasury: unpause faild");
                return;
            }

            if (msg.sender == tradeInformation.newOwner) {
                require(tradeInformation.paid, "Treasury: trade time expired");
            }
        }

        require(tradeInformation.paid, "Treasury: not paid yet");
        if (msg.sender == tradeInformation.oldOwner) {
            (bool success, ) = msg.sender.call{
                value: tradeInformation.price -
                    (tradeInformation.price / 100 - FEE)
            }("Your token has beed purchased");
            require(success, "Treasury: faild to send ETH");
        }

        if (msg.sender == tradeInformation.newOwner) {
            _assets.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function pay(uint256 tokenId) external payable {
        PendingTrade memory tradeInformation = pendingTrades[tokenId];
        require(
            tradeInformation.oldOwner != address(0) ||
                tradeInformation.newOwner != address(0),
            "Treasury: this trade doesn't exist"
        );
        require(!tradeInformation.paid, "Treasury: trade already paid");
        require(
            msg.sender == tradeInformation.newOwner,
            "Treasury: you are not a new owner"
        );
        require(
            msg.value == tradeInformation.price,
            "Treasury: not enougth ETH"
        );
        pendingTrades[tokenId].paid = true;
    }

    function addNewPandingTrade(
        address sender,
        address recipient,
        uint256 tokenId,
        uint256 timestamp,
        uint256 price
    ) external {
        require(msg.sender == _auctionAddress, "Treasury: only auction has access");
        if (pendingTrades[tokenId].paid) {
            delete pendingTrades[tokenId];
        }

        pendingTrades[tokenId] = PendingTrade(
            sender,
            recipient,
            uint64(price),
            uint32(timestamp),
            false
        );
        allTokensInPending.push(tokenId);
        tokenIndexes[tokenId] = allTokensInPending.length - 1;
    }

    function setAuctionAddress(address auctionAddress) external onlyOwner {
        _auctionAddress = auctionAddress;
    }
}
