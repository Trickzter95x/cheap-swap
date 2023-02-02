// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ICheapswapFactory.sol";
import "./ICheapswapPair.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CheapswapToken is ERC20Burnable, Ownable {

  ICheapswapPair public cheapswapPair;
  // Taxes.
  uint16 wfmtTax = 500;
  uint16 cstTax = 200;

  constructor(address cheapswapFactory, address wfmt) ERC20("CheapswapToken", "CST") {
    cheapswapPair = ICheapswapPair(ICheapswapFactory(cheapswapFactory).createPair(wfmt, address(this), address(this)));
    if(wfmt < address(this))
      cheapswapPair.setUserTokenFees(wfmtTax, cstTax);
    else
      cheapswapPair.setUserTokenFees(cstTax, wfmtTax);

    _mint(msg.sender, 100000000 ether);
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