// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICheapswapFlashloan {
  function flashloan(address to, uint amount0ToPayBack, uint amount1ToPayBack, bytes calldata data) external;
}