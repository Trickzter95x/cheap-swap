import { ethers } from "hardhat";
import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { CheapswapFactory, CheapswapPair, TokenForPairing, TokenForPairingOther } from "../typechain-types";
import { int } from "hardhat/internal/core/params/argumentTypes";

describe("CheapswapPair", function () {
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;
  let csFactory: CheapswapFactory
  let csPair: CheapswapPair;
  let firstToken: TokenForPairing;
  let secondToken: TokenForPairingOther;

  beforeEach(async() => {
    const csFactoryFactory = await ethers.getContractFactory("CheapswapFactory");
  
    [owner, alice, bob] = await ethers.getSigners();
    csFactory = await csFactoryFactory.deploy();
    // Deploy tokens and create pair.
    firstToken = await (await ethers.getContractFactory("TokenForPairing")).deploy();
    secondToken = await (await ethers.getContractFactory("TokenForPairingOther")).deploy();
    await csFactory.createPair(firstToken.address, secondToken.address, owner.address);
    csPair = (await (await ethers.getContractFactory("CheapswapPair")).attach(await csFactory.allPairs(0))).connect(owner);
  })

  /* Functions to test
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, address) external;

    // Additional cheapswap functionality.
    function setUserTokenFees(uint16 tokenFees) external;
    function flashloan(address to, uint amount0Out, uint amount1Out, bytes calldata data) external;
    function userTokenFeeOwner() external returns(address);
    function feeTracker() external returns(IFeeTracker);
  */

  describe("Deployment", function () {
    it("Pair correctly initialized", async function () {
      const [token0, token1] = Number(firstToken.address) < Number(secondToken.address) ? [firstToken.address, secondToken.address] : [secondToken.address, firstToken.address];
      expect(await csPair.token0()).to.equal(token0);
      expect(await csPair.token1()).to.equal(token1);
    });
  });


});
