pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/ITreasury.sol";
import "contracts/interfaces/IAssets.sol";

contract Treasury is ITreasury, Ownable {
    uint256 public constant FEE = 2;
    uint256 public constant DURATION = 1 hours;

    IAssets private _assets;

    address private _auction;

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

    event MoneyReceived(address indexed from, uint256 indexed amount, bytes msgData);

    constructor(address assetsAddress) {
        _assets = IAssets(assetsAddress);
    }

    function checkTrade(uint256 tokenId) external {
        PendingTrade memory tradeInformation = pendingTrades[tokenId];
        require(
            tradeInformation.oldOwner != address(0) || tradeInformation.newOwner != address(0), 
            "Treasury: this trade doesn't exist"
        );
        if (block.timestamp >= tradeInformation.time + DURATION) {
            if (msg.sender == tradeInformation.oldOwner) {
                _assets.transferFrom(address(this), msg.sender, tokenId);
                return;
            }

            if(msg.sender == tradeInformation.newOwner) {
                require(tradeInformation.paid, "Treasury: trade time expired");
            }
        }

        require(tradeInformation.paid, "Treasury: not paid yet");
        if (msg.sender == tradeInformation.oldOwner) {
            (bool success, ) = msg.sender.call{
                value: tradeInformation.price - (tradeInformation.price / 100 - FEE)
                }("Your token has beed purchased");
            require(success, "Treasury: faild to send ETH");
        }

        if (msg.sender == tradeInformation.newOwner) {
            _assets.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function addNewPandingTrade(
        address sender, 
        address recipient, 
        uint256 tokenId, 
        uint256 timestamp, 
        uint256 price
    ) external {

    }
}
