const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

describe("Assets tests", () => {
    let Assets;
    let Blacklist;

    let assets;
    let blacklist;

    const BASE_URI = "ipfs://test/";
    const BASE_PRICE = ethers.getBigInt("10000000000000000");
    const ADDITIONAL_PRICE = BASE_PRICE / ethers.getBigInt("2");

    let leafNodes;
    let merkleTree;

    beforeEach(async () => {
        //Blacklist = await ethers.getContractFactory("Blacklist");
        blacklist = await ethers.deployContract("Blacklist");
        let blacklistAddress = await blacklist.getAddress();

        Assets = await ethers.getContractFactory("Assets");
        //assets = await Assets.deploy(Assets, ["Assets", "ASSETS", BASE_URI, BASE_PRICE, ADDITIONAL_PRICE, blacklist.address]);
        assets = await upgrades.deployProxy(Assets, ["Assets", "ASSETS", BASE_URI, BASE_PRICE, ADDITIONAL_PRICE, blacklistAddress]);

        [owner, address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();
        const whitelist = [address2.address, address3.address, address4.address, address5.address, address6.address, address7.address]

        // =============== Creating whitelist ===============
        leafNodes = whitelist.map(addr => keccak256(addr));
        merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
        await assets.setMerkleRoot(merkleTree.getRoot());
    });

    describe("mint for whitelist", async () => {
        it("successful mint", async () => {
            let content = "mint";
            let hashedAddress = keccak256(address2.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);

            await assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: BASE_PRICE});
            expect(await assets.balanceOf(address2.address)).to.equal(ethers.getBigInt("1"));

            let tokenId = await assets.tokenOfOwnerByIndex(address2.address, 0);
            expect(await assets.getContent(address2.address, tokenId)).to.equal(content);

            let tokenUri = await assets.tokenURI(tokenId);
            expect(tokenUri).to.equal(BASE_URI + 1 + ".json");
        });
        it("mint for not whitelisted user", async () => {
            let content = "mint";
            let hashedAddress = keccak256(address1.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);
            await expect(assets.connect(address1).mintForWhitelist(address1.address, merkleProof, content, {value: BASE_PRICE})).revertedWith("Assets: Incorrect proof");
        });
        it("mint with unsuficient balance", async() => {
            let content = "mint";
            let hashedAddress = keccak256(address2.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);

            await expect(assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: ADDITIONAL_PRICE})).revertedWith("Assets: not enougth ETH");
        });
        it("mint for already climed user", async() => {
            let content = "mint";
            let hashedAddress = keccak256(address2.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);

            await assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: BASE_PRICE});
            await expect(assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: BASE_PRICE})).revertedWith("Assets: user already claimed token");
        });
        it("mint for user from blacklist", async() => {
            let content = "mint";
            let hashedAddress = keccak256(address2.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);

            await blacklist.addToBlacklist(address2.address);

            await expect(assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: ADDITIONAL_PRICE})).revertedWith("Assets: user is in blacklist");
        });
    });
})