pragma solidity ^0.8.18;

interface ITreasury {
    function checkTrade(uint256 tokenId) external;

    function addNewPandingTrade(
        address sender,
        address recipient,
        uint256 tokenId,
        uint256 timestamp,
        uint256 price
    ) external;
}
