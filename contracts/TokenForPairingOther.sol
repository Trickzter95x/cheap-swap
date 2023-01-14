// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenForPairingOther is ERC20Burnable, Ownable {

  address public cheapswapPair;

  constructor() ERC20("TokenForPairingOther", "TFPO") {
    _mint(msg.sender, 1000000 ether);
  }


}