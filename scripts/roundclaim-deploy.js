const bre = require("@nomiclabs/buidler");

async function main() {
  // Buidler always runs the compile task when running scripts through it. 
  // If this runs in a standalone fashion you may want to call compile manually 
  // to make sure everything is compiled
  // await bre.run('compile');

  // We get the contract to deploy
  const Roundclaim = await ethers.getContractFactory("Roundclaim");
  const roundclaim = await Roundclaim.deploy();

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
