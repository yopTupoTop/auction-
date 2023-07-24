pragma solidity 0.8.20;

import "node_modules/@openzeppelin/contracts/access/Ownable.sol";

import "contracts/interfaces/IBlacklist.sol";

contract Blacklist is IBlacklist, Ownable {
    mapping(address user => bool flag) _blacklisted;

    function addToBlacklist(address user) external {
        require(!_blacklisted[user], "Blacklist: user already blacklisted");
        _blacklisted[user] = true;
    }

    function removeFromBlacklist(address user) external {
        require(_blacklisted[user], "Blacklist: user not in blacklist");
        _blacklisted[user] = false;
    }

    function isInBlacklist(address user) external view returns (bool) {
        return _blacklisted[user];
    }
}
