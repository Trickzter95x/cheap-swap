// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CheapswapToken is ERC20Burnable, Ownable {

  address public cheapswapPair;

  constructor(address cheapswapFactory, address wfmt) ERC20("CheapswapToken", "CST") {
    cheapswapPair = ICheapswapFactory(cheapswapFactory).createPair(wfmt, address(this), msg.sender);
    _mint(msg.sender, 1000000 ether);
  }

  // Mint will be disabled in the future.
  bool public disableMintForever;
  function disableMinting() external onlyOwner {
    disableMintForever = true;
  }
  
  function mint(address to, uint amount) external onlyOwner {
    require(!disableMintForever, "CST: NEVER_MINT_AGAIN");
    _mint(to, amount);
  }

}