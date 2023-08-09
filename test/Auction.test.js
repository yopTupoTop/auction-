const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const {
    constants,
    expectRevert,
} = require('@openzeppelin/test-helpers');

describe("Auction tests", () => {
    let Assets;
    let Auction;

    let assets;
    let auction;
    let treasury;
    let blacklist;
    let factory;

    let blacklistAddress;
    let assetsAddress;
    let treasuryAddress;
    let auctionAddress;
    let factoryAddress;

    const BASE_URI = "ipfs://test/";
    const BASE_PRICE = ethers.getBigInt("10000000000000000");
    const ADDITIONAL_PRICE = BASE_PRICE / ethers.getBigInt("2");

    beforeEach(async() => {
        [owner, address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();

        blacklist = await ethers.deployContract("Blacklist");
        blacklistAddress = await blacklist.getAddress();

        Assets = await ethers.getContractFactory("Assets");
        assets = await upgrades.deployProxy(Assets, ["Assets", "ASSETS", BASE_URI, BASE_PRICE, ADDITIONAL_PRICE, blacklistAddress]);
        assetsAddress = await assets.getAddress();

        let content = "";
        assets.mint(address1.address, content, {value: BASE_PRICE + ADDITIONAL_PRICE});

        treasury = await ethers.deployContract("Treasury", [assetsAddress]);
        treasuryAddress = await treasury.getAddress();

        factory = await ethers.deployContract("AuctionFactory", [treasuryAddress, blacklistAddress, assetsAddress]);
        factoryAddress = await factory.getAddress();

        auctionTx = await factory.connect(address1).deployAuction(1);
        let result = await auctionTx.wait();
        console.log(result.logs);
        auctionAddress = result.logs[3].args[0]; //find in logs event log -> get args property 

        Auction = await ethers.getContractFactory("Auction");
        auction = Auction.attach(auctionAddress);
        
        await assets.setAuctionAddress(auctionAddress);
    });

    describe("seller functions test", async() => { 
        describe("sell token", async() => {
            it("successful placed token on auction", async() => {
                let blockNumBefore = await ethers.provider.getBlockNumber();
                let blockBefore = await ethers.provider.getBlock(blockNumBefore);
                let timestampBefore = blockBefore.timestamp;
                expect(await auction.connect(address1).sellAsset(ethers.getBigInt("10"))).to.emit(auction, "PlaceAsset").withArgs(address1.address, 1, ethers.getBigInt("10"), ethers.getBigInt(timestampBefore));
                expect(await auction.getRelevance()).to.equal(true);
                expect(await assets.isLocked(1)).to.equal(true);
                let bid = await auction.getLastBid();
                expect(bid[1]).to.equal(ethers.getBigInt("10"));
                expect(bid[2]).to.equal(address1.address);
        });
            it("place asset by not owner", async() => {
                await expect(auction.connect(address2).sellAsset(ethers.getBigInt("10"))).revertedWith("Auction: you're not the owner");
            });
            it("place asset by user from blacklist", async() => {
                blacklist.addToBlacklist(address1.address);
                await expect(auction.connect(address1).sellAsset(ethers.getBigInt("10"))).revertedWith("Auction: blacklisted users can't sell");
            });
            it("place already placed asset",async() => {
                await auction.connect(address1).sellAsset(ethers.getBigInt("10"));
                await expect(auction.connect(address1).sellAsset(ethers.getBigInt("4"))).revertedWith("Auction: token already placed");
            });
        });

        describe("cancel token", async() => {
            it("successfull cencel token auction", async() => {
                await auction.connect(address1).sellAsset(ethers.getBigInt("10"));
                let bid = await auction.getLastBid();
                let blockNumBefore = await ethers.provider.getBlockNumber();
                let blockBefore = await ethers.provider.getBlock(blockNumBefore);
                let timestampBefore = blockBefore.timestamp;
                expect(await auction.connect(address1).cancelAsset()).to.emit(auction, "CancelAsset").withArgs(address1.address, 1, bid[1], timestampBefore);
                expect(await auction.getRelevance()).to.equal(false);
                expect(await assets.isLocked(1)).to.equal(false);
                expect(await auction.getOwnerOfAsset()).to.equal(bid[2]);
                bid = await auction.getLastBid();
                expect(bid[0]).to.equal(0);
                expect(bid[1]).to.equal(0);
                expect(bid[2]).to.equal(constants.ZERO_ADDRESS);
            });
            it("cancel asset by not owner", async() => {
                await auction.connect(address1).sellAsset(ethers.getBigInt("10"));
                await expect(auction.connect(address2).cancelAsset()).revertedWith("Auction: you're not the owner")
            });
            it("cancel not placed asset", async() => {
                await expect(auction.connect(address1).cancelAsset()).revertedWith("Auction: token is not for sale on the auction");
            });
        });
    });
})