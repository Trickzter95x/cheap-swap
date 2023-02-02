// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ICheapswapFlashloan.sol";
import "./ICheapswapPair.sol";

contract FlashloanTester is ICheapswapFlashloan {

  function loan(address pair, address token0, address token1, uint amount0ToTake, uint amount1ToTake, bool repayLess) external {
    ICheapswapPair(pair).flashloan(address(this), amount0ToTake, amount1ToTake, abi.encode(pair, token0, token1, repayLess));
  }

  function flashloan(address sender, uint amount0ToPayBack, uint amount1ToPayBack, bytes calldata data) external {
    (address pair, address token0, address token1, bool repayLess) = abi.decode(data, (address, address, address, bool));
    IERC20(token0).transfer(pair, repayLess && amount0ToPayBack > 0 ? amount0ToPayBack - 1: amount0ToPayBack);
    IERC20(token1).transfer(pair, repayLess && amount1ToPayBack > 0 ? amount1ToPayBack - 1: amount1ToPayBack);
  }

}