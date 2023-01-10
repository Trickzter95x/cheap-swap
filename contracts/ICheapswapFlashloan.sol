// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICheapswapFlashloan {
  function flashloan(address to, uint amount0Out, uint amount1Out, bytes calldata data) external;
}