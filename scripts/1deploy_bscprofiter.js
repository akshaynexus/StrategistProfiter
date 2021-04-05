// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
// const { ethers } = require("ethers");
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  //Deploy profiter
  const StrategistProfiterBSCV2 = await ethers.getContractFactory(
    "StrategistProfiterBSCV2"
  );
  let profiter = await StrategistProfiterBSCV2.deploy();
  await profiter.deployed();
  console.log("StrategistProfiterBSCV2 deployed to:", profiter.address);
  await profiter.addStrat(
    "0x5F03BD60e6b5Acf744c4Bf48EdB1Cd4f1192dc6D",//Strategy
    "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",//Sell to WBNB
)
  await hre.run("verify:verify", {
    address: profiter.address,
    constructorArguments:[]
  })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
