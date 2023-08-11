pragma solidity ^0.8.18;

interface ITreasury {
    function checkTrade(address auctionAddress) external;

    function addNewPandingTrade(
        address sender,
        address recipient,
        uint256 timestamp,
        uint256 price,
        address auctionAddress
    ) external;
}
