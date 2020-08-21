const bre = require("@nomiclabs/buidler");

const relayAddress = "0x78A389B693e0E3DE1849F34e70bf4Bcb57F0F2bb";

async function main() {
  //deploy mock oracle
  const ExchangeOracle = await ethers.getContractFactory("ExchangeOracle");
  const oracle = await ExchangeOracle.deploy();

  //create roundclaim
  const Roundclaim = await ethers.getContractFactory("Roundclaim");
  const roundclaim = await Roundclaim.deploy(relayAddress, oracle.address);

  await roundclaim.deployed();

  console.log("Roundclaim deployed to:", roundclaim.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
