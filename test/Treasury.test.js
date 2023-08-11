const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

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
            let tOwner = await assets.ownerOf(1); //treasury 
            let aOwner = await auction.getOwnerOfAsset(); //address1
            console.log(tOwner, aOwner, treasuryAddress);
            await treasury.connect(address2).pay(1, {value: ethers.getBigInt("11")});
            await treasury.checkTrade(1, auctionAddress);
        });
    });
});