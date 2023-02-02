/*import { ethers } from "hardhat";
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
  

  describe("Deployment", function () {
    it("Pair correctly initialized", async function () {
      const [token0, token1] = Number(firstToken.address) < Number(secondToken.address) ? [firstToken.address, secondToken.address] : [secondToken.address, firstToken.address];
      expect(await csPair.token0()).to.equal(token0);
      expect(await csPair.token1()).to.equal(token1);
    });
  });

  describe("Basic functionality", async() => {
    it("Mint", async() => {
      const lpTokensToGain = (100 * 200) ** 0.5 - 1000;
      const tokenForPairingOwner = await firstToken.connect(owner);
      const tokenForPairingOtherOwner = await secondToken.connect(owner);
      firstToken.transfer(csPair.address, ethers.utils.to)
    });
  });

});
*/
import chai, { expect } from 'chai'
import { ethers } from "hardhat";
import { BigNumber, Contract } from 'ethers'

import { CheapswapFactory, CheapswapPair, TokenForPairing, TokenForPairingOther } from '../typechain-types';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';

const MINIMUM_LIQUIDITY = BigNumber.from(10**3)

const overrides = {
  gasLimit: 9999999
}

const expandTo18Decimals = (val: any) => {
  return BigNumber.from(val).mul(BigNumber.from(10).pow(18));
}

describe('UniswapV2Pair', () => {
  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  let factory: CheapswapFactory
  let token0: TokenForPairing
  let token1: TokenForPairingOther
  let pair: CheapswapPair
  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners()
    factory = await (await ethers.getContractFactory("CheapswapFactory")).deploy();
    token0 = await (await ethers.getContractFactory("TokenForPairing")).deploy();
    token1 = await (await ethers.getContractFactory("TokenForPairingOther")).deploy();
    if(BigNumber.from(token0.address).gt(BigNumber.from(token1.address))){
      const tmp = token0;
      token0 = token1;
      token1 = tmp;
    }
    (await factory.createPair(token0.address, token1.address, owner.address));
    pair = (await (await ethers.getContractFactory("CheapswapPair")).attach(await factory.allPairs(0))).connect(owner);
    await pair.setUserTokenFees(20, 20);
  })

  it('mint', async () => {
    const token0Amount = expandTo18Decimals(1)
    const token1Amount = expandTo18Decimals(4)
    await token0.transfer(pair.address, token0Amount)
    await token1.transfer(pair.address, token1Amount)

    const expectedLiquidity = expandTo18Decimals(2)
    await expect(pair.mint(owner.address, overrides))
      .to.emit(pair, 'Transfer')
      .withArgs(ethers.constants.AddressZero, ethers.constants.AddressZero, MINIMUM_LIQUIDITY)
      .to.emit(pair, 'Transfer')
      .withArgs(ethers.constants.AddressZero, owner.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount, token1Amount)
      .to.emit(pair, 'Mint')
      .withArgs(owner.address, token0Amount, token1Amount)
    expect(await pair.totalSupply()).to.eq(expectedLiquidity)
    expect(await pair.balanceOf(owner.address)).to.eq(expectedLiquidity.sub(MINIMUM_LIQUIDITY))
    expect(await token0.balanceOf(pair.address)).to.eq(token0Amount)
    expect(await token1.balanceOf(pair.address)).to.eq(token1Amount)
    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount)
    expect(reserves[1]).to.eq(token1Amount)
  })

  async function addLiquidity(token0Amount: BigNumber, token1Amount: BigNumber) {
    await token0.transfer(pair.address, token0Amount)
    await token1.transfer(pair.address, token1Amount)
    await pair.mint(owner.address, overrides)
  }
  const swapTestCases: BigNumber[][] = [
    [1, 5, 10, '1662497915624478906'],
    [1, 10, 5, '453305446940074565'],

    [2, 5, 10, '2851015155847869602'],
    [2, 10, 5, '831248957812239453'],

    [1, 10, 10, '906610893880149131'],
    [1, 100, 100, '987158034397061298'],
    [1, 1000, 1000, '996006981039903216']
  ].map(a => a.map(n => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
  swapTestCases.forEach((swapTestCase, i) => {
    it(`getInputPrice:${i}`, async () => {
      const [swapAmount, token0Amount, token1Amount, expectedOutputAmount] = swapTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, swapAmount)
      await expect(pair.swap(0, expectedOutputAmount.add(1), owner.address, '0x', overrides)).to.be.revertedWithCustomError(pair, 'K')
      await pair.swap(0, expectedOutputAmount, owner.address, '0x', overrides)
    })
  })

  const optimisticTestCases: BigNumber[][] = [
    ['997000000000000000', 5, 10, 1], // given amountIn, amountOut = floor(amountIn * .997)
    ['997000000000000000', 10, 5, 1],
    ['997000000000000000', 5, 5, 1],
    [1, 5, 5, '1003009027081243729'] // given amountOut, amountIn = ceiling(amountOut / .997)
  ].map(a => a.map(n => (typeof n === 'string' ? BigNumber.from(n) : expandTo18Decimals(n))))
  optimisticTestCases.forEach((optimisticTestCase, i) => {
    it(`optimistic:${i}`, async () => {
      const [outputAmount, token0Amount, token1Amount, inputAmount] = optimisticTestCase
      await addLiquidity(token0Amount, token1Amount)
      await token0.transfer(pair.address, inputAmount)
      await expect(pair.swap(outputAmount.add(1), 0, owner.address, '0x', overrides)).to.be.revertedWithCustomError(pair, 'K')
      await pair.swap(outputAmount, 0, owner.address, '0x', overrides)
    })
  })

  it('swap:token0', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('1662497915624478906')
    await token0.transfer(pair.address, swapAmount)
    await expect(pair.swap(0, expectedOutputAmount, owner.address, '0x', overrides))
      .to.emit(token1, 'Transfer')
      .withArgs(pair.address, owner.address, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount.add(swapAmount), token1Amount.sub(expectedOutputAmount))
      .to.emit(pair, 'Swap')
      .withArgs(owner.address, swapAmount, 0, 0, expectedOutputAmount, owner.address)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount.add(swapAmount))
    expect(reserves[1]).to.eq(token1Amount.sub(expectedOutputAmount))
    expect(await token0.balanceOf(pair.address)).to.eq(token0Amount.add(swapAmount))
    expect(await token1.balanceOf(pair.address)).to.eq(token1Amount.sub(expectedOutputAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(owner.address)).to.eq(totalSupplyToken0.sub(token0Amount).sub(swapAmount))
    expect(await token1.balanceOf(owner.address)).to.eq(totalSupplyToken1.sub(token1Amount).add(expectedOutputAmount))
  })

  it('swap:token1', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('453305446940074565')
    await token1.transfer(pair.address, swapAmount)
    await expect(pair.swap(expectedOutputAmount, 0, owner.address, '0x', overrides))
      .to.emit(token0, 'Transfer')
      .withArgs(pair.address, owner.address, expectedOutputAmount)
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount.sub(expectedOutputAmount), token1Amount.add(swapAmount))
      .to.emit(pair, 'Swap')
      .withArgs(owner.address, 0, swapAmount, expectedOutputAmount, 0, owner.address)

    const reserves = await pair.getReserves()
    expect(reserves[0]).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(reserves[1]).to.eq(token1Amount.add(swapAmount))
    expect(await token0.balanceOf(pair.address)).to.eq(token0Amount.sub(expectedOutputAmount))
    expect(await token1.balanceOf(pair.address)).to.eq(token1Amount.add(swapAmount))
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(owner.address)).to.eq(totalSupplyToken0.sub(token0Amount).add(expectedOutputAmount))
    expect(await token1.balanceOf(owner.address)).to.eq(totalSupplyToken1.sub(token1Amount).sub(swapAmount))
  })

  it('swap:gas', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)

    // ensure that setting price{0,1}CumulativeLast for the first time doesn't affect our gas math
    await pair.sync(overrides)

    const swapAmount = expandTo18Decimals(1)
    const expectedOutputAmount = BigNumber.from('453305446940074565')
    await token1.transfer(pair.address, swapAmount)
    const tx = await pair.swap(expectedOutputAmount, 0, owner.address, '0x', overrides)
    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(68641)
  })

  it('flashloan:token0', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));

    const loanAmount = expandTo18Decimals(5)
    const repayAmount = loanAmount.mul(1001).div(1000);
    const depth = repayAmount.sub(loanAmount);
    
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount, 0, false);
    const receipt = await tx.wait()
    expect(await pair.factoryToken0Fees()).to.eq(depth.div(2));
  })

  it('flashloan:token0:IL', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));

    const loanAmount = expandTo18Decimals(5)
    const repayAmount = loanAmount.mul(1001).div(1000);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, loanAmount.add(1), 0, false)).to.be.revertedWithCustomError(pair, 'IL')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount, 0, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:token0:IIA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));

    const loanAmount = expandTo18Decimals(5)
    const repayAmount = loanAmount.mul(1001).div(1000);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, loanAmount, 0, true)).to.be.revertedWithCustomError(pair, 'IIA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount, 0, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:token0:IOA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));

    const loanAmount = expandTo18Decimals(5)
    const repayAmount = loanAmount.mul(1001).div(1000);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 1, 0, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 500, 0, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 999, 0, false)).to.be.revertedWithCustomError(pair, 'IOA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount, 0, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:token1', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount = expandTo18Decimals(10)
    const repayAmount = loanAmount.mul(1001).div(1000);
    const depth = repayAmount.sub(loanAmount);
    
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, 0, loanAmount, false);
    const receipt = await tx.wait()
    expect(await pair.factoryToken1Fees()).to.eq(depth.div(2));
  })

  it('flashloan:token1:IL', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount = expandTo18Decimals(10)
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, loanAmount.add(1), 0, false)).to.be.revertedWithCustomError(pair, 'IL')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, 0, loanAmount, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:token1:IIA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount = expandTo18Decimals(10)
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 0, loanAmount, true)).to.be.revertedWithCustomError(pair, 'IIA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, 0, loanAmount, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:token1:IOA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount = expandTo18Decimals(10)
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 0, 1, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 0, 500, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 0, 999, false)).to.be.revertedWithCustomError(pair, 'IOA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, 0, loanAmount, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:both', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount0 = expandTo18Decimals(5)
    const loanAmount1 = expandTo18Decimals(10)
    const repayAmount0 = loanAmount0.mul(1001).div(1000);
    const repayAmount1 = loanAmount1.mul(1001).div(1000);
    const depth0 = repayAmount0.sub(loanAmount0);
    const depth1 = repayAmount1.sub(loanAmount1);
    
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount0, loanAmount1, false);
    const receipt = await tx.wait()
    expect(await pair.factoryToken0Fees()).to.eq(depth0.div(2));
    expect(await pair.factoryToken1Fees()).to.eq(depth1.div(2));
  })

  it('flashloan:both:IL', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount0 = expandTo18Decimals(5)
    const loanAmount1 = expandTo18Decimals(10)
    const repayAmount0 = loanAmount0.mul(1001).div(1000);
    const repayAmount1 = loanAmount1.mul(1001).div(1000);
    const depth0 = repayAmount0.sub(loanAmount0);
    const depth1 = repayAmount1.sub(loanAmount1);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, loanAmount0.add(1), loanAmount1.add(1), false)).to.be.revertedWithCustomError(pair, 'IL')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount0, loanAmount1, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:both:IIA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount0 = expandTo18Decimals(5)
    const loanAmount1 = expandTo18Decimals(10)
    const repayAmount0 = loanAmount0.mul(1001).div(1000);
    const repayAmount1 = loanAmount1.mul(1001).div(1000);
    const depth0 = repayAmount0.sub(loanAmount0);
    const depth1 = repayAmount1.sub(loanAmount1);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, loanAmount0, loanAmount1, true)).to.be.revertedWithCustomError(pair, 'IIA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount0, loanAmount1, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('flashloan:both:IOA', async () => {
    const token0Amount = expandTo18Decimals(5)
    const token1Amount = expandTo18Decimals(10)
    await addLiquidity(token0Amount, token1Amount)
    const loanContract = await (await ethers.getContractFactory("FlashloanTester")).deploy() as FloashloanTester;
    await token0.transfer(loanContract.address, expandTo18Decimals(6));
    await token1.transfer(loanContract.address, expandTo18Decimals(11));

    const loanAmount0 = expandTo18Decimals(5)
    const loanAmount1 = expandTo18Decimals(10)
    const repayAmount0 = loanAmount0.mul(1001).div(1000);
    const repayAmount1 = loanAmount1.mul(1001).div(1000);
    const depth0 = repayAmount0.sub(loanAmount0);
    const depth1 = repayAmount1.sub(loanAmount1);
    
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 1, 1, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 500, 500, false)).to.be.revertedWithCustomError(pair, 'IOA')
    await expect(loanContract.loan(pair.address, token0.address, token1.address, 999, 999, false)).to.be.revertedWithCustomError(pair, 'IOA')
    const tx = await loanContract.loan(pair.address, token0.address, token1.address, loanAmount0, loanAmount1, false);
    const receipt = await tx.wait()
    console.log(receipt.gasUsed)
  })

  it('burn', async () => {
    const token0Amount = expandTo18Decimals(3)
    const token1Amount = expandTo18Decimals(3)
    await addLiquidity(token0Amount, token1Amount)

    const expectedLiquidity = expandTo18Decimals(3)
    await pair.transfer(pair.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
    await expect(pair.burn(owner.address, overrides))
      .to.emit(pair, 'Transfer')
      .withArgs(pair.address, ethers.constants.AddressZero, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
      .to.emit(token0, 'Transfer')
      .withArgs(pair.address, owner.address, token0Amount.sub(1000))
      .to.emit(token1, 'Transfer')
      .withArgs(pair.address, owner.address, token1Amount.sub(1000))
      .to.emit(pair, 'Sync')
      .withArgs(1000, 1000)
      .to.emit(pair, 'Burn')
      .withArgs(owner.address, token0Amount.sub(1000), token1Amount.sub(1000), owner.address)

    expect(await pair.balanceOf(owner.address)).to.eq(0)
    expect(await pair.totalSupply()).to.eq(MINIMUM_LIQUIDITY)
    expect(await token0.balanceOf(pair.address)).to.eq(1000)
    expect(await token1.balanceOf(pair.address)).to.eq(1000)
    const totalSupplyToken0 = await token0.totalSupply()
    const totalSupplyToken1 = await token1.totalSupply()
    expect(await token0.balanceOf(owner.address)).to.eq(totalSupplyToken0.sub(1000))
    expect(await token1.balanceOf(owner.address)).to.eq(totalSupplyToken1.sub(1000))
  })

})