// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CheapswapToken is ERC20, Ownable {

  address public cheapswapPair;

  constructor(address cheapswapFactory, address wfmt) ERC20("CheapswapToken", "CST") {
    cheapswapPair = ICheapswapFactory(cheapswapFactory).createPair(wfmt, address(this));
  }
}