const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Auction tests", () => {
    let Assets;
    let Auction;

    let assets;
    let auction;
    let treasury;
    let blacklist;

    let blacklistAddress;
    let assetsAddress;
    let treasuryAddress;
    let auctionAddress;

    const BASE_URI = "ipfs://test/";
    const BASE_PRICE = ethers.getBigInt("10000000000000000");
    const ADDITIONAL_PRICE = BASE_PRICE / ethers.getBigInt("2");

    beforeEach(async() => {
        blacklist = await ethers.deployContract("Blacklist");
        blacklistAddress = await blacklist.getAddress();

        Assets = await ethers.getContractFactory("Assets");
        assets = await upgrades.deployProxy(Assets, ["Assets", "ASSETS", BASE_URI, BASE_PRICE, ADDITIONAL_PRICE, blacklistAddress]);
        assetsAddress = await assets.getAddress();

        treasury = await ethers.deployContract("Treasury", [assetsAddress]);
        treasuryAddress = await treasury.getAddress();

        Auction = await ethers.getContractFactory("Auction");
        auction = await upgrades.deployProxy(Auction, [assetsAddress, treasuryAddress, blacklistAddress]);
        auctionAddress = await auction.getAddress();
        
        [owner, address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();

        await treasury.setAuctionAddress(auctionAddress);
        await assets.setAuctionAddress(auctionAddress);
    });

    describe("sell token", async() => {
        it("successful placed token on auction", async() => {
            
        });
    });

    describe("cancel token", async() => {

    });
})