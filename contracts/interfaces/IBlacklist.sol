pragma solidity ^0.8.18;

interface IBlacklist {
    function addToBlacklist(address user) external;

    function removeFromBlacklist(address user) external;

    function isInBlacklist(address user) external view returns (bool);
}
