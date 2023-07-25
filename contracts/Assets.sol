pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

import "contracts/interfaces/IAssets.sol";
import "contracts/interfaces/IBlacklist.sol";

contract Assets is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    IAssets
{
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    mapping(address user => mapping(uint256 tokenId => Asset)) ownedAssets;
    mapping(address => bool) tokenClaimed;
    mapping(uint256 => bool) tokenLocked;

    uint256 public constant MAX_SUPPLY = 1111;

    IBlacklist private _blacklist;

    CountersUpgradeable.Counter private _counter;

    string private _baseUri;
    string private _uriSuffix;
    uint256 _basePrice;
    uint256 _additionalPrice;
    bytes32 private _merkleRoot;
    address private _auction;

    function initialize(
        string memory name,
        string memory symbol,
        string memory baseUri,
        uint256 basePrice,
        uint256 additionalPrice,
        address blacklistAddress
    ) public initializer {
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

    function mint(
        address to,
        string memory content
    ) external payable whenNotPaused {
        require(_counter.current() < MAX_SUPPLY, "Assets: limit reached");
        require(!_blacklist.isInBlacklist(to), "Assets: user is in blacklist");
        require(!tokenClaimed[to], "Assets: user already claimed token");
        require(msg.value == _basePrice + _additionalPrice,"Assets: not enougth ETH");
        _counter.increment();
        _mint(to, _counter.current());
        ownedAssets[to][_counter.current()] = Asset(content);
        tokenClaimed[to] = true;
    }

    function mintForWhitlist(
        address to,
        bytes32[] memory merkleProof,
        string memory content
    ) external payable {
        require(_counter.current() < MAX_SUPPLY, "Assets: limit reached");
        require(!_blacklist.isInBlacklist(to), "Assets: user is in blacklist");
        require(!tokenClaimed[to], "Assets: user already claimed token");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(
            MerkleProofUpgradeable.verify(merkleProof, _merkleRoot, leaf),
            "Assets: Incorrect proof"
        );
        require(msg.value == _basePrice, "Assets: not enougth ETH");
        _counter.increment();
        _mint(to, _counter.current());
        ownedAssets[to][_counter.current()] = Asset(content);
        tokenClaimed[to] = true;
    }

    function getContent(
        address user,
        uint256 tokenId
    ) external view returns (string memory) {
        return string(ownedAssets[user][tokenId].content);
    }

    function lockToken(uint256 tokenId) external {
        require(msg.sender == _auction, "Assets: sender is not auction");
        tokenLocked[tokenId] = true;
    }

    function unlockToken(uint256 tokenId) external {
        require(msg.sender == _auction, "Assets: sender is not auction");
        tokenLocked[tokenId] = false;
    }

    function isLocked(uint256 tokenId) external view returns (bool) {
        return tokenLocked[tokenId];
    }

    function setAuctionAddress(address auctionAddress) external onlyOwner {
        _auction = auctionAddress;
    }

    function setMerkleRoot(bytes32 newRoot) external onlyOwner {
        _merkleRoot = newRoot;
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory baseUri = _baseURI();
        return
            bytes(baseUri).length > 0
                ? string.concat(baseUri, tokenId.toString(), _uriSuffix)
                : "";
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(
            !_blacklist.isInBlacklist(from),
            "Assets: cannot transfer token from blacklisted user"
        );
        require(
            !_blacklist.isInBlacklist(to),
            "Assets: cannot transfer token to blacklisted user"
        );
        require(!tokenLocked[tokenId], "Assets: token is at auction");
        ownedAssets[to][tokenId] = ownedAssets[from][tokenId];
        delete ownedAssets[from][tokenId];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            IERC165Upgradeable
        )
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
