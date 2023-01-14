import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CheapswapFactory } from "../typechain-types";

describe("CheapswapFactory", function () {
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let csFactory: CheapswapFactory

  beforeEach(async() => {
    const csFactoryFactory = await ethers.getContractFactory("CheapswapFactory");
  
    [owner, alice, bob] = await ethers.getSigners();
    csFactory = await csFactoryFactory.deploy();
  })

  describe("Deployment", function () {
    it("Initial fee taker is owner", async function () {
      expect(await csFactory.feeTaker()).to.equal(owner.address);
    });
  });

  describe("Management", () => {
    it("Change fee taker as previous fee taker", async() => {
      const ownerConnect = await csFactory.connect(owner);
      await ownerConnect.setFeeTaker(alice.address);
      expect(await csFactory.feeTaker()).to.equal(alice.address);
    });
    it("Disallow change fee taker as wrong previous fee taker", async() => {
      const currentFeeTaker = await csFactory.feeTaker();
      const aliceConnect = await csFactory.connect(alice);
      expect(currentFeeTaker).to.not.equal(alice.address);
      expect(await csFactory.feeTaker()).to.equal(owner.address);
      await expect(aliceConnect.setFeeTaker(alice.address)).to.be.revertedWith("CheapswapFactory: INVLD_FT");
      expect(await csFactory.feeTaker()).to.equal(owner.address);
    });
  });

  describe("Pairs", function () {
    it("Create a pair", async function () {
      const firstToken = await (await ethers.getContractFactory("TokenForPairing")).deploy();
      const secondToken = await (await ethers.getContractFactory("TokenForPairingOther")).deploy();

      await csFactory.createPair(firstToken.address, secondToken.address, owner.address);
      expect(await csFactory.allPairsLength()).to.equal(1);
      const pairAddress = await csFactory.allPairs(0);
      expect(await csFactory.getPair(firstToken.address, secondToken.address)).to.equal(pairAddress);
      expect(await csFactory.getPair(secondToken.address, firstToken.address)).to.equal(pairAddress);
    });
  });

});
