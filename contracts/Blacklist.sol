pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/IBlacklist.sol";

contract Blacklist is IBlacklist, Ownable {
    mapping(address => bool) _blacklisted;

    function addToBlacklist(address user) external onlyOwner {
        require(!_blacklisted[user], "Blacklist: user already blacklisted");
        _blacklisted[user] = true;
    }

    function removeFromBlacklist(address user) external onlyOwner {
        require(_blacklisted[user], "Blacklist: user not in blacklist");
        _blacklisted[user] = false;
    }

    function isInBlacklist(address user) external view returns (bool) {
        return _blacklisted[user];
    }
}
