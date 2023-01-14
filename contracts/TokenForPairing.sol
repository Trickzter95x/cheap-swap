// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenForPairing is ERC20Burnable, Ownable {

  address public cheapswapPair;

  constructor() ERC20("TokenForPairing", "TFP") {
    _mint(msg.sender, 1000000 ether);
  }


}