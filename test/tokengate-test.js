/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const ContractObj = {
  TokenGate: null,
  proxyAddress: null,
};
const initialize = async () => {
  ContractObj.TokenGate = await ethers.getContractFactory("TokenGate");
  const contracts = await upgrades.deployProxy(ContractObj.TokenGate);
  await contracts.deployed();
  ContractObj.proxyAddress = contracts.address;
};
beforeEach(async () => {
  await initialize();
});
describe("TokenGate", function () {
  it("Should return false if user is not subscribed", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be
      .false;
  });
  it("Deployer has admin role", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String(0x00),
        owner.address
      )
    ).to.be.true;
  });
  it("Deployer can grant admin role to account", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner, addr] = await ethers.getSigners();
    await expect(
      TokenGateContract.grantRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        addr.address
      )
    )
      .to.emit(TokenGateContract, "RoleGranted")
      .withArgs(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS").toString(),
        addr.address,
        owner.address
      );
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        addr.address
      )
    ).to.be.true;
  });

  /** Subscription **/
  it("Set Subscription Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.setFee(ethers.utils.parseEther("1.0"), "MONTHLY")
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(ethers.utils.parseEther("1.0").toString(), "MONTHLY");
    // expect(TokenGateContract.setFee);
  });
  it("Subscribe", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be
      .false;
    const options = { value: ethers.utils.parseEther("1.0") };

    await TokenGateContract.subscribe(options);
    expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.true;
  });
});
