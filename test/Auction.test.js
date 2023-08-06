const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

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

        factory = await ethers.deployContract("AuctionFactory", [treasuryAddress, blacklistAddress, assetsAddress, 1]);
        factoryAddress = await factory.getAddress();

        auction = await factory.connect(address1).deployAuction();
        console.log(await auction.wait());
        //await expect(factory.deployAuction()).to.emit(facory, "ContractCreated").withArgs(0x00);
        //let result = await auction.wait();
        //console.log(result);
        //const event = result.events.find(event => event.event === 'ContractCreated');
        //[auctionAddress] = event.args;
        //auctionAddress = result.events.args.auction;

        //Auction = await ethers.getContractFactory("Auction");
        //auction = await upgrades.deployProxy(Auction, [assetsAddress, treasuryAddress, blacklistAddress]);
        //auctionAddress = await auction.getAddress();
        
        //await treasury.setAuctionAddress(auctionAddress);
       // await assets.setAuctionAddress(auctionAddress);
    });

    describe("sell token", async() => {
        it("successful placed token on auction", async() => {

        });
    });

    describe("cancel token", async() => {

    });
})