pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";
import "contracts/interfaces/ITreasury.sol";

contract Auction is Initializable, PausableUpgradeable, OwnableUpgradeable {
    uint256 public constant FEE = 3;
    uint256 public constant DISTINCTION = 3;

    uint256 public tokenAmount;

    IAssets private _assets;
    ITreasury private _tresury;
    IBlacklist private _blacklist;

    struct Bid {
        uint32 time;
        uint128 price;
        address user;
    }

    uint256[] private allTokens;

    mapping(uint256 id => Bid) private lastBid;
    mapping(uint256 id => uint256 initialPrice) private initPrice;
    mapping(uint256 id => address owner) private assetOwner;
    mapping(uint256 id => uint256 allTokensIndex) private assetIndex;

    function initialize(
        address assetsAddress,
        address treasuryAddress,
        address blacklistAddress
    ) public initializer {
        _assets = IAssets(assetsAddress);
        _tresury = ITreasury(treasuryAddress);
        _blacklist = IBlacklist(blacklistAddress);

        __Pausable_init();
        __Ownable_init();
    }
}