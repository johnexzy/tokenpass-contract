// scripts/deploy_upgradeable_subscription.js
const { ethers, upgrades, run } = require("hardhat");

async function main() {
  const TokenGate = await ethers.getContractFactory("TokenGateway");
  console.log("Deploying TokenGate...");
  const contract = await upgrades.deployProxy(TokenGate, [], {
    initializer: "intialize",
  });
  await contract.deployed();
  console.log("TokenGate deployed to:", contract.address);
  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [],
  });
}

main();
