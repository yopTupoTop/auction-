pragma solidity 0.8.20;

import "node_modules/@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "node_modules/@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";

contract Assets is 
    Initializable, 
    ERC721EnumerableUpgradeable, 
    ERC721Upgradeable, 
    PausableUpgradeable, 
    OwnableUpgradeable, 
    IAssets 
{
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping(address owner => mapping(uint256 id => Asset)) ownedAssets;
    mapping(address user => bool flag) tokenClaimed;
    mapping(uint256 id => bool flag) tokenLocked;

    uint256 public constant MAX_SUPPLY = 1111;

    IBlacklist private _blacklist;

    CountersUpgradeable.Counter private _counter;

    string private _baseUri;
    string private _uriSuffix;
    uint256 _basePrice;
    uint256 _additionalPrice;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        uint256 basePrice,
        uint256 additionalPrice,
        address blacklistAddress) public initializer {
            _baseUri = baseUri;
            _uriSuffix = ".json";
            _basePrice = basePrice;
            _additionalPrice = additionalPrice;

            _blacklist = IBlacklist(blacklistAddress);

            __ERC721_init(name, symbol);
            __ERC721Enumerable_init();
            __Ownable_init();
            __Pausable_init();
    }

    function mint(address to, string memory content) external payable whenNotPaused {
        require(_counter.current() < MAX_SUPPLY, "Assets: limit reached");
        require(!_blacklist.isInBlacklist(to), "Assets: user is in blacklist");
        require(!tokenClaimed[to], "Assets: user already claimed token");
        require(msg.value = _basePrice + _additionalPrice, "Assets: not enougth ETH");
        _counter.increment();
        _mint(to, _counter.current());
        ownedAssets[to][_counter.current()] = Asset(content);
        tokenClaimed[to] = true;
    }
}