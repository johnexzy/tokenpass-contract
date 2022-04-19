const { expect } = require("chai");
const { ethers } = require("hardhat");
// const { ethers } = require("hardhat");

describe("TokenGate", function () {
  it("Should return the new greeting once it's changed", async function () {
    const TokenGate = await ethers.getContractFactory("TokenGate");
    // const contracts = await upgrades.deployProxy(TokenGate);
    // await contracts.deployed();
    // console.log(contracts.address);
    const contract = await TokenGate.attach(
      "0x966AaB67ad3C09ACe0AEC67a647F2728f2741117"
    );
    // const tx = await contract.initializeAccessTokens([
    //   [
    //     "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
    //     "0x4552433732310000000000000000000000000000000000000000000000000000",
    //     -1,
    //     true,
    //     // ethers.utils.formatBytes32String("ERC721"),
    //   ],
    // ]);
    // await tx.wait();
    // await contract.deployed();
    // 0x966AaB67ad3C09ACe0AEC67a647F2728f2741117

    expect(await contract.isSubscribed()).to.equal(true);
  });
});
