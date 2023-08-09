pragma solidity ^0.8.18;

interface IAuction {
    function sellAsset(uint256 price) external;

    function cancelAsset() external;

    function acceptOffer() external;

    function buyAsset() external payable;

    function placeBid(uint256 price) external;

    function getLastBid() external returns (uint256, uint256, address);

    function getOwnerOfAsset() external returns (address);

    function updateOwner() external;

    function pause() external;

    function unpause() external;
}
