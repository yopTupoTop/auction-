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
    const BASE_PRICE = ethers.BigNumber.from("10000000000000000");
    const ADDITIONAL_PRICE = BASE_PRICE.div(2);

    let leafNodes;
    let merkleTree;

    beforeEach(async () => {
        Blacklist = await ethers.getContractFactory("Blacklist");
        blacklist = await Blacklist.deploy();

        Assets = await ethers.getContractFactory("Assets");
        assets = await Assets.deployProxy(Assets, ["Assets", "ASSETS", BASE_URI, BASE_PRICE, ADDITIONAL_PRICE, blacklist.address]);

        [owner, address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();
        const whitelist = [address2.address, address3.address, address4.address, address5.address, address6.address, address7.address]

        // =============== Creating whitelist ===============
        leafNodes = whitelist.map(addr => keccak256(addr));
        merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
        await assets.setMerkeleRoot(merkleTree.getRoot());
    });

    describe("mint for whitelisted user", async () => {
        if("successful mint", async () => {
            let content = "mint";
            let hashedAddress = keccak256(address2.address);
            let merkleProof = merkleTree.getHexProof(hashedAddress);

            await assets.connect(address2).mintForWhitelist(address2.address, merkleProof, content, {value: BASE_PRICE});
            expect(await assets.balanceOf(address2.address)).to.equal(ethers.BigNumber.from(1));

            let tokenId = await assets.tokenOfOwnerByIndex(adderss2.address, 0);
            expect(await assets.getContent(address2.address, tokenId)).to.equal(content);

            let tokenUri = await assets.tokenURI(tokenId);
            expect(tokenUri).to.equal(BASE_URI + 1 + ".json");
        });
    });
})