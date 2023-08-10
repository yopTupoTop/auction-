const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Treasuty tests", () => {
    let Assets;
    let Auction;

    let assets;
    let auction;
    let treasury;
    let factory;

    let assetsAddress;
    let treasuryAddress;
    let auctionAddress;
    let factoryAddress;

    beforeEach(async() => {
        [owner, address1, address2, address3, address4, address5, address6, address7] = await ethers.getSigners();

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
    });
});