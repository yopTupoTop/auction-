// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
require("dotenv").config();

async function main() {
    const blacklist = await ethers.deployContract("Blacklist");
    const blacklistAddress = await blacklist.getAddress();
    blacklist.waitForDeployment();
    
    const Assets = await ethers.getContractFactory("Assets");
    const assets = await upgrades.deployProxy(Assets, ["Assets", "asts", process.env.BASE_URI, ethers.getBigInt("5000000000000000000"), ethers.getBigInt("2000000000000000000"), blacklistAddress]);
    const assetsAddress = await assets.getAddress();
    assets.waitForDeployment();

    const treasury = await ethers.deployContract("Treasury", [assetsAddress]);
    const treasuryAddress = await treasury.getAddress();
    treasury.waitForDeployment();

    const factory = await ethers.deployContract("AuctionFactory", [treasuryAddress, blacklistAddress, assetsAddress]);
    const factoryAddress = await factory.getAddress();
    factory.waitForDeployment();

  console.log("blacklist address: ", blacklistAddress);
  console.log("assets address: ", assetsAddress);
  console.log("treasury address: ", treasuryAddress);
  console.log("factory address: ", factoryAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
