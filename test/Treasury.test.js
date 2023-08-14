const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Treasuty tests", () => {
    let Assets;
    let Auction;

    let assets;
    let auction;
    let treasury;
    let factory;
    let blacklist;

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

        await auction.connect(address1).sellAsset(ethers.getBigInt("10"));
    });

    describe("check trade", async() => {
        it("successful check", async() => {
            await assets.connect(address1).approve(auctionAddress, 1);
            await auction.connect(address2).placeBid(ethers.getBigInt("11"));
            await auction.connect(address1).acceptOffer();
            await treasury.connect(address2).pay(1, {value: ethers.getBigInt("11")});
            let role = await auction.ADMIN_ROLE();
            let unpauseRole = await auction.UNPAUSER_ROLE();
            await auction.connect(address1).grantRole(role, treasuryAddress);
            await auction.connect(address1).grantRole(unpauseRole, treasuryAddress);
            await treasury.connect(address2).checkTrade(auctionAddress);
            expect(await assets.ownerOf(1)).to.equal(address2.address);
            expect(await auction.getOwnerOfAsset()).to.equal(address2.address);
        });
        it("check non-existent trade", async() => {
            await assets.connect(address1).approve(auctionAddress, 1);
            await auction.connect(address2).placeBid(ethers.getBigInt("11"));

            await expect(treasury.connect(address2).checkTrade(auctionAddress)).revertedWith("Treasury: this trade doesn't exist");

            await auction.connect(address1).acceptOffer();
            await treasury.connect(address2).pay(1, {value: ethers.getBigInt("11")});
            let role = await auction.ADMIN_ROLE();
            let unpauseRole = await auction.UNPAUSER_ROLE();
            await auction.connect(address1).grantRole(role, treasuryAddress);
            await auction.connect(address1).grantRole(unpauseRole, treasuryAddress);
            await treasury.connect(address2).checkTrade(auctionAddress);
        });
        it("check trade after time expired", async() => {
            await assets.connect(address1).approve(auctionAddress, 1);
            await auction.connect(address2).placeBid(ethers.getBigInt("11"));
            await auction.connect(address1).acceptOffer();

            await time.increase(3660);

            await expect(treasury.connect(address2).checkTrade(auctionAddress)).revertedWith("Treasury: trade time expired");
        });
        it("check unpaid trade", async() => {
            await assets.connect(address1).approve(auctionAddress, 1);
            await auction.connect(address2).placeBid(ethers.getBigInt("11"));
            await auction.connect(address1).acceptOffer();

            await expect(treasury.connect(address2).checkTrade(auctionAddress)).revertedWith( "Treasury: not paid yet");
        });
    });
});