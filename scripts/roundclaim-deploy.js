const bre = require("@nomiclabs/buidler");

const relayAddress = "0x78A389B693e0E3DE1849F34e70bf4Bcb57F0F2bb";

async function main() {
  //deploy mock oracle
  const ExchangeOracle = await ethers.getContractFactory("ExchangeOracle");
  const oracle = await ExchangeOracle.deploy();

  //create XCC contract (including auxilliary contracts)
  const Validator = await ethers.getContractFactory("Validator");
  const validator = await Validator.deploy();
  const XclaimCommit = await ethers.getContractFactory("XclaimCommit");
  const xclaimCommit = await XclaimCommit.deploy(relayAddress, oracle.address, validator.address);

  await xclaimCommit.deployed();

  console.log("XclaimCommit deployed to:", xclaimCommit.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
