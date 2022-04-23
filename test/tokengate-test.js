/* eslint-disable no-unused-expressions */
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const ContractObj = {
  TokenGate: null,
  proxyAddress: "0xF838415B7D3607682F2BeA1A479523A16e0cEd35",
  testToken: null,
};
const initialize = async () => {
  ContractObj.TokenGate = await ethers.getContractFactory("TokenGate");
  const contracts = await upgrades.deployProxy(ContractObj.TokenGate);
  await contracts.deployed();
  ContractObj.proxyAddress = contracts.address;
  const TestToken721 = await ethers.getContractFactory("TestToken721");
  const testToken = await TestToken721.deploy();

  await testToken.deployed();

  ContractObj.testToken = testToken.address;
};

describe("TokenGate", function () {
  before(async function () {
    await initialize();
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

  it("Should return false, user is not subscribed or owns access token 0x71C3...7fEf", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    const [owner] = await ethers.getSigners();
    expect(
      await TokenGateContract.checkAccess(ContractObj.testToken, owner.address)
    ).to.be.false;
  });
  it("Add ERC721 token as access.", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.initializeAccessToken([
        ContractObj.testToken, // contract address
        ethers.utils.formatBytes32String("ERC721").toString(), // typeOfcontract bytes32
        -1, // no specific id
        [ethers.utils.parseEther("0.1"), 2592000], // lifetime access
        1, // amount (owns >= 1)
      ])
    )
      .to.emit(TokenGateContract, "AddedAccessToken")
      .withArgs(
        ContractObj.testToken,
        ethers.utils.formatBytes32String("ERC721").toString(),
        "-1",
        "1",
        ethers.utils.parseEther("0.1").toString(),
        "2592000"
      );
    // expect(TokenGateContract.setFee);
  });
  it(
    "Checking Access Should return true, user owns this access token: " +
      ContractObj.testToken,
    async function () {
      const TokenGateContract = await ContractObj.TokenGate.attach(
        ContractObj.proxyAddress
      );

      const [owner] = await ethers.getSigners();
      expect(
        await TokenGateContract.checkAccess(
          ContractObj.testToken,
          owner.address
        )
      ).to.be.true;
    }
  );

  it("Disable 0x71C3...7fEf from access tokens", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    await expect(TokenGateContract.disableTokenAccess(ContractObj.testToken))
      .to.emit(TokenGateContract, "DisableTokenAccess")
      .withArgs(ContractObj.testToken);
  });
  it("Checking Access for 0x71C3...7fEf should return false, no access token initialized and user is not subscribed", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    // console.log(owner.address);
    expect(
      await TokenGateContract.checkAccess(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        owner.address
      )
    ).to.be.false;
    // expect(TokenGateContract.setFee);
  });
  /** Subscription **/
  it("Set Subscription Fee for  users without this 0x71C3...7fEf token", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );
    // ethers.Contract.
    // const addr = (await ethers.getSigners())[1];
    await expect(
      TokenGateContract.setFee(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        ethers.utils.parseEther("0.05"),
        7 // 7days
      )
    )
      .to.emit(TokenGateContract, "SetFee")
      .withArgs(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        ethers.utils.parseEther("0.05").toString(),
        "604800"
      );
  });
  it("User can Subscribe by paying Fee", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    // const [owner] = await ethers.getSigners();
    // expect(await TokenGateContract.checkIfSubscribed(owner.address)).to.be.false;
    let fee = await TokenGateContract.getFeeForTokenAccess(
      "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf"
    );
    fee = ethers.utils.formatEther(fee.price);
    const options = { value: ethers.utils.parseEther(fee) };
    await expect(
      TokenGateContract.subscribe(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        options
      )
    ).to.emit(TokenGateContract, "Subscribed");
  });
  it("Checking Access for 0x71C3...17fEf should return true, user paid for subscription,", async function () {
    const TokenGateContract = await ContractObj.TokenGate.attach(
      ContractObj.proxyAddress
    );

    const [owner] = await ethers.getSigners();
    // console.log(owner.address);
    expect(
      await TokenGateContract.checkAccess(
        "0x71C3022E585f138BABee7E3B8Eca15D058a17fEf",
        owner.address
      )
    ).to.be.true;
    // expect(TokenGateContract.setFee);
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
