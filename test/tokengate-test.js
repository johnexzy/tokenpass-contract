/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const ContractObj = {
  TokenGate: null,
  proxyAddress: "0xF838415B7D3607682F2BeA1A479523A16e0cEd35",
};
const initialize = async () => {
  ContractObj.TokenGate = await ethers.getContractFactory("TokenGate");
  const contracts = await upgrades.deployProxy(ContractObj.TokenGate);
  await contracts.deployed();
  ContractObj.proxyAddress = contracts.address;
};

describe("TokenGate", function () {
  before(async function () {
    await initialize();
  });
  it("Should return false if user is not subscribed", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    console.log(owner.address);
    expect(await TokenGateContract.checkAccess(owner.address)).to.be.false;
  });
  it("Initialize Access Token", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.initializeAccessToken([
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf", // contract address
        ethers.utils.formatBytes32String("ERC721").toString(), // typeOfcontract bytes32
        -1, // no specific id
        true, // lifetime access
        1, // amount (owns >= 1)
      ])
    )
      .to.emit(TokenGateContract, "AddedAccessToken")
      .withArgs(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        ethers.utils.formatBytes32String("ERC721").toString(),
        "-1",
        "1"
      );
    // expect(TokenGateContract.setFee);
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
  it("Deployer can grant sub-roles to accounts", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    await expect(
      TokenGateContract.grantRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133"
      )
    )
      .to.emit(TokenGateContract, "RoleGranted")
      .withArgs(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS").toString(),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133",
        owner.address
      );
    expect(
      await TokenGateContract.hasRole(
        ethers.utils.formatBytes32String("TOKEN_MODERATORS"),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133"
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
      TokenGateContract.setFee(ethers.utils.parseEther("0.1"), "MONTHLY")
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(ethers.utils.parseEther("0.1").toString(), "MONTHLY");
  });
  it("User can Subscribe", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    const options = { value: ethers.utils.parseEther("0.1") };
    await expect(TokenGateContract.subscribe(options)).to.emit(
      TokenGateContract,
      "Subscribed"
    );
  });
  it("Withdraw ETH from contract", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    const balance = await ethers.provider.getBalance(TokenGateContract.address);
    await expect(TokenGateContract.withrawETH())
      .to.emit(TokenGateContract, "WithdrawBalance")
      .withArgs(balance.toString(), owner.address.toString());
  });
});
