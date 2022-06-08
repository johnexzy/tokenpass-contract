/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const ContractObj = {
  TokenGate: null,
  proxyAddress: "0xF838415B7D3607682F2BeA1A479523A16e0cEd35",
  testToken721: "",
  testToken1155: "",
  testToken20: "",
};
const AccessTokens = {
  A: [],
  B: [],
  C: [],
};
const initialize = async () => {
  const [owner] = await ethers.getSigners();
  ContractObj.TokenGate = await ethers.getContractFactory("TokenGate");
  const contracts = await upgrades.deployProxy(ContractObj.TokenGate);
  await contracts.deployed();
  ContractObj.proxyAddress = contracts.address;

  // ERC721 Test Token
  const TestToken721 = await ethers.getContractFactory("TestToken721");
  const testToken721 = await TestToken721.deploy();
  await testToken721.deployed();
  ContractObj.testToken721 = testToken721.address;

  // ERC1155 Test Token
  const TestToken1155 = await ethers.getContractFactory("TestToken1155");
  const testToken1155 = await TestToken1155.deploy();
  await testToken1155.deployed();
  ContractObj.testToken1155 = testToken1155.address;

  // ERC20 Test Token
  const TestToken20 = await ethers.getContractFactory("TestToken20");
  const testToken20 = await TestToken20.deploy();
  await testToken20.deployed();
  ContractObj.testToken20 = testToken20.address;

  AccessTokens.A = [
    ContractObj.testToken1155, // contract address
    owner.address,
    ethers.utils.formatBytes32String("ERC1155").toString(), // typeOfcontract bytes32
    0, // no specific id
    [true, ethers.utils.parseEther("0.1"), 2592000], // pay 0.1ETH monthly as an alternative to token
    20, // amount (owns >= 20)
  ];
  AccessTokens.B = [
    ContractObj.testToken20, // contract address
    owner.address,
    ethers.utils.formatBytes32String("ERC20").toString(), // typeOfcontract bytes32
    -1, // no specific id
    [true, ethers.utils.parseEther("0.1"), 2592000], // pay 0.1ETH monthly as an alternative to token
    20, // amount (owns >= 20)
  ];

  AccessTokens.C = [
    ContractObj.testToken721, // contract address
    owner.address,
    ethers.utils.formatBytes32String("ERC721").toString(), // typeOfcontract bytes32
    -1, // no specific id
    [true, ethers.utils.parseEther("0.1"), 2592000], // lifetime access
    1, // amount (owns >= 1)
  ];
};
before(async function () {
  await initialize();
});
describe("TokenGate", function () {
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
  it("Deployer can grant admin role to accounts", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    await expect(
      TokenGateContract.grantRole(
        ethers.utils.formatBytes32String(0x00),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133"
      )
    )
      .to.emit(TokenGateContract, "RoleGranted")
      .withArgs(
        ethers.utils.formatBytes32String(0x00),
        "0xf7F8DCf8962872421373FF5cf2C4bB06357b7133",
        owner.address
      );
  });

  it("Should return true, user owns access tokens (ERC721, ERC20 and ERC1155)  ", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(await TokenGateContract.checkAccess(AccessTokens.C, owner.address))
      .to.be.true;
    expect(await TokenGateContract.checkAccess(AccessTokens.B, owner.address))
      .to.be.true;
    expect(await TokenGateContract.checkAccess(AccessTokens.A, owner.address))
      .to.be.true;
  });

  it("Instead of acquiring TestTokens (ERC721), User can Subscribe periodically by paying the Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    const subscriptionDetails = AccessTokens.C[4];
    const fee = ethers.utils.formatEther(subscriptionDetails[1]);
    const options = { value: ethers.utils.parseEther(fee) };
    await expect(TokenGateContract.subscribe(AccessTokens.C, options)).to.emit(
      TokenGateContract,
      "Subscribed"
    );
  });
  it("Instead of acquiring TestTokens (ERC1155), User can Subscribe periodically by paying the Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    const subscriptionDetails = AccessTokens.A[4];
    const fee = ethers.utils.formatEther(subscriptionDetails[1]);
    const options = { value: ethers.utils.parseEther(fee) };
    await expect(TokenGateContract.subscribe(AccessTokens.A, options)).to.emit(
      TokenGateContract,
      "Subscribed"
    );
  });

  it("Checking Access for TestToken (ERC721) should return true, user paid for subscription,", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    // console.log(owner.address);
    expect(await TokenGateContract.checkAccess(AccessTokens.B, owner.address))
      .to.be.true;
    // expect(TokenGateContract.setFee);
  });

  it("Withdraw ETH paid for Test-Token721", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    const balance = await TokenGateContract.ethBalancePaidForTokenAccess(
      ContractObj.testToken721
    );
    await expect(
      TokenGateContract.withdrawBalancePaidForToken(ContractObj.testToken721)
    )
      .to.emit(TokenGateContract, "WithdrawBalancePaidForToken")
      .withArgs(ContractObj.testToken721, balance.toString(), owner.address);
  });
  it("Withdraw ETH paid for Test-Token1155", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    const balance = await TokenGateContract.ethBalancePaidForTokenAccess(
      ContractObj.testToken1155
    );
    await expect(
      TokenGateContract.withdrawBalancePaidForToken(ContractObj.testToken1155)
    )
      .to.emit(TokenGateContract, "WithdrawBalancePaidForToken")
      .withArgs(ContractObj.testToken1155, balance.toString(), owner.address);
  });
});
