// scripts/deploy_upgradeable_subscription.js
const { ethers, upgrades, run } = require("hardhat");

async function main() {
  const TokenGate = await ethers.getContractFactory("TokenGate");
  console.log("Deploying TokenGate...");
  const contract = await upgrades.deployProxy(TokenGate);
  await contract.deployed();
  console.log("TokenGate deployed to:", contract.address);
  await run("verify:verify", {
    address: contract.address,
    constructorArguments: [],
  });
}

main();
